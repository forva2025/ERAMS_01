# Prompt: Build Incident Prioritization (the one missing core component)

**Use this as the instruction set for implementing incident/triage priority in ERAMS.** It follows up on a gap analysis done 29 Aug 2026 against a standard 15-component Emergency Response Management System checklist: 14 of 15 components are built, and the sole one that is **not** is Incident Prioritization — verified by grepping the entire codebase and every migration for `priority`/`severity`/`urgency`: zero matches. Right now every incident is handled purely by dispatch distance and arrival order (`created_at`), regardless of how serious it is. A cardiac arrest and a minor sprain logged one after another get identical treatment.

---

## Source of truth — read these first

| File | What it tells you |
|---|---|
| `supabase/migrations/20260617000001_initial_schema.sql` | Current `incidents` table — no priority column exists |
| `supabase/migrations/20260624000011_patient_request.sql` | Adds `pending_acceptance` status + `photo_url`; the most recent shape-changing migration on `incidents` — model your new migration's style on this one |
| `lib/features/dispatcher/new_incident_form.dart` (lines 12–23) | Dispatcher's emergency-type list (10 types) |
| `lib/features/patient/new_request_form.dart` (lines 10–21) | Patient's emergency-type list (10 types) — **not the same strings as the dispatcher's list**, see Decision 2 below |
| `lib/services/incident_service.dart` | Dispatcher's incident creation path — direct insert into `incidents` |
| `lib/services/patient_service.dart` (`createPatientIncident`) | Patient's incident creation path — inserts into `incidents`, then calls `dispatch_incident` RPC with `p_patient_id` |
| `lib/widgets/status_badge.dart` | Existing badge-widget pattern (color-coded by status) — reuse this pattern for a priority badge rather than inventing a new one |
| `lib/features/dispatcher/dispatcher_dashboard.dart`, `lib/features/admin/admin_screen.dart` (Patients tab), `lib/features/driver/driver_screen.dart` (`_JobOfferCard`), `lib/features/hospital/hospital_screen.dart` | Every screen that renders an incident card — all of these need the priority badge/sort treatment |

---

## Decisions to confirm before writing code

These materially change scope and risk. Don't silently pick one — confirm with the team, or at minimum flag your choice explicitly in the PR description.

### Decision 1 — How much should priority actually *change system behavior*?
Three possible scope levels, increasing in risk:

- **(a) Display + sort only** (recommended starting point): add the field, show a color-coded badge everywhere an incident renders, sort incident lists priority-first. No change to dispatch logic. Low risk, immediately useful — dispatchers and admins can *see* what's urgent and act on it themselves.
- **(b) Tie-breaking in dispatch**: when the same ambulance would otherwise be offered to two incidents nearly simultaneously, the higher-priority one wins. This needs a look at how `dispatch_incident`'s nearest-ambulance selection currently handles concurrent calls (Postgres row-locking currently makes it first-caller-wins) — worth doing, moderate complexity.
- **(c) Preemption** — pulling an ambulance off an already-assigned lower-priority job to serve a new critical one. **Do not build this without an explicit team decision.** It's operationally dangerous (an ambulance mid-transit gets redirected away from a patient who was already told help is coming) and is a much bigger state-machine change than the rest of this prompt. Flag it as a documented future-work item instead unless someone explicitly signs off on building it.

This prompt's task list below covers (a) fully and sets up the data model so (b) is a smaller follow-up. It deliberately does not include (c).

### Decision 2 — The two emergency-type dropdowns don't match
The dispatcher's list (`new_incident_form.dart`) and the patient's list (`new_request_form.dart`) use different label strings for overlapping concepts (e.g. dispatcher has "Trauma / Injury" and "Obstetric Emergency"; patient has "Severe Trauma / Accident" and "Childbirth Emergency"). Any severity mapping keyed on the free-text label has to cover **both** lists, and the two will silently drift out of sync over time. Two ways to handle it:
- **Recommended**: unify both dropdowns to pull from one shared canonical list (e.g. `lib/core/constants/emergency_types.dart`), each entry carrying its own default priority. This is a small refactor but removes the drift risk permanently.
- **Minimal**: keep both lists as-is and maintain two separate label→priority maps, one per source. Faster, but the two lists will need to be kept in sync by hand forever.

### Decision 3 — Auto-derived vs. manually entered priority
Recommended: **auto-derive a default priority from `nature_of_emergency`** (a cardiac arrest is always at least "high" regardless of who's typing), computed **server-side** in a trigger (so it can't be skipped or spoofed by either client), with the **dispatcher** able to override it via a dropdown on the incident card (upgrade or downgrade based on what the caller actually describes). **Patients should not get a manual override** — they're not equipped to self-triage, and the whole point of ERAMS's original scope was to keep triage decisions with trained dispatchers. Confirm this framing before building the override UI.

---

## Task 1 — Schema

New migration, e.g. `supabase/migrations/20260829000026_incident_priority.sql`:

- Add `priority` to `incidents`: `TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('critical', 'high', 'medium', 'low'))` (or an integer 1–4 if the team prefers numeric sort convenience — text enum matches the existing `status` column's style, e.g. `20260617000001_initial_schema.sql` line ~67, so text is more consistent with the rest of the schema).
- A `BEFORE INSERT` trigger function (`set_incident_priority()` or similar, following the naming style of `handle_new_user()` / `set_message_sender_info()`) that, when `priority` is left at its default and the row's `nature_of_emergency` matches a known high-severity type, upgrades it automatically. Keep the mapping data-driven (a small `CASE nature_of_emergency WHEN ... THEN ...` or a lookup table) rather than hardcoded string comparisons scattered across the app, so it's the single place severity logic lives.
- Decide the actual severity mapping with the team (a strawman, subject to review — cross-reference against **both** dropdown lists per Decision 2):
  - **Critical**: Cardiac Arrest, Unconscious Patient / Unconscious-Unresponsive, Stroke, Severe Bleeding
  - **High**: Breathing Difficulty / Difficulty Breathing, Trauma/Injury / Severe Trauma-Accident, Obstetric/Childbirth Emergency, Poisoning/Overdose, Seizure
  - **Medium**: Road Traffic Accident, Fire/Burns
  - **Low**: Other
  This is a first pass, not a medical judgment — flag it for the team (or a domain-knowledgeable reviewer) to sanity-check before treating it as final.
- Add a GIN/BTREE index if the dispatcher dashboard query will filter/sort on `priority` frequently (likely combined with `status` — check whether a composite index on `(status, priority, created_at)` makes sense given `dispatcher_dashboard.dart`'s existing query pattern).

## Task 2 — Model & services

- `lib/models/incident.dart`: add an `IncidentPriority` enum (`critical, high, medium, low`) mirroring the `IncidentStatus` enum's existing pattern (`fromString`/`dbValue`/`label` — see how `IncidentStatus` does it in the same file), plus a `priority` field on `Incident`.
- `lib/services/incident_service.dart` / `lib/services/patient_service.dart`: no changes needed for *reads* (the trigger handles default assignment), but if Decision 3's dispatcher override ships, `IncidentService` needs an `updateIncidentPriority(incidentId, priority)` call (a simple `UPDATE incidents SET priority = ...`, RLS already allows dispatcher/admin full read/write on `incidents` per the existing `5.2 RLS Policy Summary`).

## Task 3 — UI: badge + display

- New `lib/widgets/priority_badge.dart`, modeled directly on `lib/widgets/status_badge.dart`'s structure. Suggested color mapping (using `AppColors` conventions already in `lib/core/theme/app_colors.dart`): critical → `AppColors.error`, high → an orange/`statusPending`-adjacent tone, medium → neutral/amber, low → `AppColors.textSecondary`/grey. Keep it visually distinct from the existing status badges (different shape or icon, e.g. a small triangle/flag icon) so the two badge types don't get confused on a crowded card.
- Wire the badge into every incident-rendering location:
  - `lib/features/dispatcher/dispatcher_dashboard.dart` — incident cards (~line 580, 715, 1037 per current grep hits on `natureOfEmergency`)
  - `lib/features/admin/admin_screen.dart` — Patients tab rows (~line 2556) and Live Map incident markers
  - `lib/features/driver/driver_screen.dart` — `_JobOfferCard` (so a driver sees at a glance how urgent the offer is) and the active-incident card
  - `lib/features/hospital/hospital_screen.dart` — incoming-patient cards
  - `lib/features/patient/trip_tracking_screen.dart` — optional; a patient doesn't need to see their own priority necessarily, but it's harmless if included in the status banner area

## Task 4 — Sorting

- `dispatcher_dashboard.dart`'s active-incident list: change the default sort to priority-first (critical → high → medium → low), then oldest-first within the same priority tier, while keeping the existing status filter (All/Logged/Dispatched/etc.) working on top of it.
- `admin_screen.dart`'s Patients tab: same priority-first default sort, without breaking the existing search/filter behavior (`_PatientsTab`'s search per current implementation).

## Task 5 — Decision 1(b), if the team wants it (tie-breaking in dispatch)

Only build this after Task 1–4 ship and Decision 1 is confirmed. Look at `dispatch_incident` in `supabase/migrations/20260617000004_dispatch_rpcs.sql` (as later modified by `20260706000021_fix_dispatch_incident_overload.sql`) to understand the current nearest-ambulance selection query, and figure out where a priority-aware `ORDER BY` would slot in for the case where multiple incidents are racing for the same ambulance pool.

---

## Testing (match the project's existing approach — see `docs/COMPLETED_WORK.md`'s Testing Approach section)

- `flutter analyze`: 0 issues, as with every other change in this codebase.
- Manual QA checklist to add to `COMPLETED_WORK.md` once built, in the same style as other phases:
  - Log a "Cardiac Arrest" incident as dispatcher → confirm it lands with a "Critical" badge without manually setting anything.
  - Log an "Other" incident → confirm it defaults to "Low".
  - Submit a patient request via `new_request_form.dart` for a type on the patient list that isn't worded identically to the dispatcher list (e.g. "Childbirth Emergency") → confirm the trigger still maps it correctly (this directly tests whether Decision 2 was handled correctly).
  - As dispatcher, override an incident's priority up/down → confirm the badge updates in real time on a second dispatcher session (Realtime already propagates `incidents` changes, per the existing pattern).
  - Confirm the dispatcher dashboard and admin Patients tab both show critical incidents at the top of the list even if they were logged after lower-priority ones.
  - Confirm a driver's `_JobOfferCard` shows the priority badge for a patient-initiated request.

---

## Process notes

- Follow the numbered-migration convention exactly (`supabase/migrations/YYYYMMDDHHNNNN_description.sql`) — check the latest existing migration's timestamp before picking the new file's number so it sorts correctly.
- After building, update `docs/COMPLETED_WORK.md` with a new dated entry (matching the style of entries like "Live Map Views (Admin, Driver, Hospital) ✓ Added" near the end of that file) rather than editing an existing phase's checklist.
- If `docs/FINAL_YEAR_REPORTS.md` is updated after this ships (see `docs/REPORT_UPDATE_PROMPT.md`), Incident Prioritization should be added to the Functional Requirements (3.1) and Features Implemented (5.5) sections — it wasn't in either previously, matching the gap this prompt closes.
