# Prompt: Bring `FINAL_YEAR_REPORTS.md` in line with the actual ERAMS system

**Use this document as the instruction set for the next editing pass on the report.** It was written after auditing `docs/FINAL_YEAR_REPORTS.md` against the real codebase (`lib/`, `supabase/migrations/`, `README.md`, `docs/COMPLETED_WORK.md`) on 14 Aug 2026. Two problems were found and confirmed with the team:

1. **The report is missing an entire user role.** The system has five user roles — **Patient, Dispatcher, Ambulance Driver, Hospital Staff, Administrator** — but the report only documents four (no Patient anywhere). The Patient is not a minor addition: **the patient is who initiates the emergency incident** in the ride-hailing-style flow the system actually implements, so this affects the Introduction, Scope, Requirements, Design, and Implementation chapters, not just one section.
2. **Several factual/technical claims in the report are stale or wrong** relative to what was actually built, mostly because parts of the report describe the system as it was scoped in the original proposal rather than as it exists now.

Work through the tasks below in order. After each edit, re-read the surrounding paragraph so the chapter still reads as one coherent document, not a patchwork of insertions.

---

## Source of truth — check these before writing anything

| Document | What it tells you |
|---|---|
| `docs/COMPLETED_WORK.md` | The authoritative build log. Phases 9–13, 15, 16, 18 describe the entire Patient module (registration, nearby-ambulance map, request form, driver accept/decline, live tracking, chat, calls, SMS, ratings). Phase 14 (mobile money) is **explicitly deferred** — don't describe payment as working. |
| `README.md` | Current, accurate system description — architecture diagram, ERD, tech stack table, "Known Limitations" section. Use this to fact-check anything the report claims about technology or features. |
| `docs/diagrams/DIAGRAMS.md` | Already-correct **Mermaid** diagrams with all 5 roles: DFD Level 0/1, UML Use Case (5 roles), Patient Booking sequence, Payment sequence (marked planned/not built), Dispatcher-initiated sequence. **Use these as the basis for updated Chapter 4 diagrams** instead of redrawing from scratch — the report's current diagrams (`image2.jpeg`, `image3.jpeg`, `image4.jpeg`, referenced but not present as real files in this checkout) are 4-role and outdated. |
| `supabase/migrations/*.sql` | Ground truth for schema, RLS policies, enum values (e.g. `incidents.status` now includes `pending_acceptance`; `ambulances` has `service_type`, `base_fare`, `price_per_km`, `rating`, `rating_count`; `trips` and `messages` tables exist and aren't in the report at all). |
| `lib/models/profile.dart` | `UserRole` enum — confirms 5 roles: `dispatcher, driver, hospital, admin, patient`. |

Do not invent numbers, screenshots, or evaluation results that aren't in these sources — where something is missing (e.g. no live click-through test evidence, per Phase 19's note), say so plainly in the report rather than implying it happened.

---

## Task 1 — Add Patient as the 5th user role throughout

Go chapter by chapter. The Patient is the actor who **starts** the process (submits the request via the app), which is a structural change to how the whole workflow narrative reads, not just a bullet added to a list.

### Chapter 1 — Introduction
- **1.5 Scope of the Study**: currently says *"The system is intended for use by dispatchers, ambulance drivers, hospital staff, and administrators."* Add Patient, and rework the sentence so the patient-initiated flow is acknowledged as in-scope (self-registration, request submission, live tracking, in-app chat/calls, rating) — this is a major, fully-built part of the system per Phase 9–13/15/18, not a stretch goal.
- Consider whether 1.2 Problem Statement / 1.4 Specific Objectives need a line acknowledging that ERAMS now also supports patient/bystander self-service booking directly, alongside the original phone-in/dispatcher-logged model — both paths exist in the code (`dispatch_incident` RPC branches on whether `p_patient_id` is passed).

### Chapter 2 — System Analysis
- **2.3 Proposed System**: the bullet list of "ERAMS introduces a centralized, role-based system where..." lists Dispatcher/Driver/Hospital/Admin but not Patient. Add a Patient bullet describing: browsing nearby ambulances (map with price/rating/service type), submitting a request, tracking the assigned ambulance live, chatting/calling the driver, and rating the trip afterward.

### Chapter 3 — System Requirements
- **3.1 Functional Requirements**: add requirements for the patient path, e.g.:
  - Allow patients to self-register and log in
  - Allow patients to view nearby available ambulances on a map with distance, fare estimate, service type (BLS/ALS/ICU), and rating
  - Allow patients to submit an emergency request (emergency type, notes, location, optional photo field exists in schema — confirm if photo upload UI is wired before claiming it works; `COMPLETED_WORK.md` Phase 11 notes "photo upload not yet wired")
  - Allow the assigned driver to **accept or decline** a patient-submitted request (30-second countdown, automatic re-offer to next-nearest driver on decline/timeout)
  - Allow patients to track their assigned ambulance live on a map with ETA
  - Allow patients and drivers to communicate via in-app text chat and voice/video calls (Agora; native/Android only, web shows a fallback message)
  - Allow patients to rate the ambulance/trip after completion (1–5 stars + comment)
- **3.3 User Requirements**: add a **3.3.5 Patient** subsection (list: register/log in, view nearby ambulances and pricing, submit a request, track assigned ambulance, communicate with driver, rate trip) — patients would then become 3.3.1, existing roles renumber, or add Patient first since they initiate the process. Confirm the team's preferred ordering (report elsewhere lists Patient first: "Patient, Hospital, Ambulance driver, Admin, Dispatcher").

### Chapter 4 — System Design
- **4.1 System Architecture**: update to reflect the 5-client architecture (Patient added). Consider replacing the current generic "User → Frontend → Backend → Database" flow line with something closer to the README's actual architecture (Flutter client talks to Supabase directly via Postgres/Realtime/Auth, with Edge Functions only for privileged server-side operations) — see Task 2 below, this is also a factual-accuracy fix.
- **4.2 Use Case Diagram**: add **Patient** as an actor. Main interactions list currently starts with "Log incident → Dispatch ambulance..." which implicitly assumes a dispatcher always starts the flow — rewrite to show both entry points: **(a)** patient submits a request → driver accepts/declines → ... and **(b)** dispatcher logs on behalf of a caller → auto/manual dispatch → ... Pull the actor list and interactions directly from `docs/diagrams/DIAGRAMS.md` §3 and §4.
- **4.3 Data Model (ERD)**: this is the biggest gap. The report only documents `profiles`, `hospitals`, `ambulances`, `incidents`, `incident_events`. Add:
  - **`trips`** table (patient_id, ambulance_id, driver_id, status machine `requested→accepted→en_route→arrived→completed/cancelled`, fare fields, payment fields, `patient_rating`/`patient_comment`, timestamps) — see `supabase/migrations/20260621000008_trips.sql`
  - **`messages`** table (in-app chat) — see `supabase/migrations/20260621000009_messages.sql` and `20260624000013_messages.sql`
  - Update the **`ambulances`** attribute table to include the marketplace fields added in Phase 9: `service_type`, `base_fare`, `price_per_km`, `rating`, `rating_count`, `equipment_notes`
  - Update the **`incidents`** attribute table: `status` enum now includes `pending_acceptance` (not just logged/dispatched/en_route/arrived/completed/cancelled); add `photo_url` column
  - Update **Key Relationships** list to add: a patient (profile) has many trips/incidents; an incident has one trip (when patient-initiated); a trip belongs to one patient, one ambulance, one driver
  - Base the redrawn ERD on `docs/diagrams/DIAGRAMS.md` and/or `docs/diagrams/ERD.png` if that file is current — verify it includes `trips`/`messages` before citing it.
- **4.4 Activity Diagram / 4.5 Sequence Diagram**: both currently describe only the dispatcher-initiated flow ("User reports an emergency" → "Dispatcher receives the request..."). Either add a second diagram/flow for the patient-initiated path, or generalize the existing one to explicitly branch on who initiates. `docs/diagrams/DIAGRAMS.md` §4 (Patient Booking Flow) and §6 (Dispatcher-Initiated Flow) already have both as separate sequence diagrams — reuse them.

### Chapter 5 — System Implementation and Testing
This chapter is entirely missing the Patient role — fix all of the following:
- **5.2 RLS Policy Summary table**: add a **Patient** row/column showing: read/update own profile; read own trips and incidents (create incident+trip via `dispatch_incident` RPC with own patient_id); read/insert messages on own incident; update own completed trip's rating (per the RLS policy added in `20260624000012_rating_trigger.sql`). Also add columns/rows for the **`trips`** and **`messages`** tables, which aren't in the table at all right now.
- **5.3 Relationship Summary**: add a `Patient (Profile) └── Creates Trips/Incidents` branch alongside the existing `Dispatcher (Profile) └── Creates Incidents` branch.
- **5.4 System Implementation / 5.5 Features Implemented**: add a **Patient module** bullet (or its own subsection, matching the depth given to Dispatcher/Driver/Hospital/Admin) summarizing: self-registration & login, nearby-ambulance map with pricing/ratings, request submission, driver accept/decline with countdown + re-offer, live trip tracking, in-app chat, voice/video calls, post-trip rating. Also mention the supporting infrastructure that isn't tied to one role: SMS notifications (Africa's Talking, Phase 16), DHIS2 export (Phase 17), live map views (admin/driver/hospital, added post-Phase-8).
- **5.6/5.7 System Testing / Testing Approach**: the current text describes only the dispatcher→driver→hospital cross-role smoke test. Add the patient-initiated loop (request → driver accept → live tracking → chat/call → complete → rate) to the "cross-role, end-to-end smoke testing" description. Also see Task 2's note about Phase 19's testing caveats — don't overstate what was actually verified.

### Chapter 6 — Conclusion and Recommendations
- **6.1 Conclusion**: currently summarizes achievements only in terms of dispatcher/driver/hospital/admin coordination. Add a line noting the patient self-service (ride-hailing-style) booking flow as a core achievement, not just the dispatcher-run model.
- **6.2 Recommendations**: several "future work" items are now **already built** — see Task 2, item 5 below. Don't recommend something as future work that the Patient module already does.

---

## Task 2 — Fix factual/technical inaccuracies found during the audit

These are independent of the Patient-role gap — fix them regardless.

1. **3.5 Software Requirements table** lists Backend as *"PHP / Node.js (Supa base)"*. This is wrong — there is no PHP or Node.js layer. Server-side logic is **Postgres RPC functions** (`dispatch_incident`, `update_incident_status`, `accept_trip`, `decline_trip`, `nearby_ambulances`, etc.) plus **Supabase Edge Functions** written in **Deno/TypeScript** (`admin_create_user`, `admin_reset_password`, `send_sms`, `generate_agora_token`, `export_to_dhis2`). Also fix "Frontend: Flutter, CSS, JavaScript" — Flutter (Dart) is the single codebase for both Web and Android; CSS/JS are compiled output artifacts of Flutter Web, not something the team writes directly. Pull the corrected table straight from the README's tech stack table.

2. **4.1 System Architecture** description ("User → Frontend → Backend → Database → Backend → Frontend → User") is a generic 3-tier textbook description that doesn't match how the app actually talks to Supabase (client calls Postgres/Realtime/Auth directly via the Supabase SDK; there is no separate custom backend server — Edge Functions exist only for the handful of privileged operations that must never expose the service-role key to the client). Rewrite using the README's architecture diagram as the source of truth.

3. **Incident status enum** (Table 4.3.4 and anywhere status values are listed) is missing `pending_acceptance` — the status a patient-initiated incident sits in while awaiting a driver's accept/decline. Current report says `logged | dispatched | en_route | arrived | completed | cancelled`; actual constraint (see `20260624000011_patient_request.sql`) also includes `pending_acceptance`.

4. **Abstract** frames mobile apps, GPS live tracking, and SMS notifications as *"Future enhancements [that] may include..."* — all three are now **built and shipped**: the Android driver app exists, live GPS tracking is a core working feature (15-second push interval, real-time propagation), and SMS notifications via Africa's Talking are implemented (Phase 16). Rewrite the Abstract's last paragraph to describe these as delivered, and replace the "future enhancements" framing with what's actually still outstanding (see item 5).

5. **6.2 Recommendations** — audit each sub-section against what's built before keeping it as "future work":
   - **6.2.1 Mobile Application Development** — the Android driver app (and patient app on both Web/Android) already exists. This can't stay phrased as a recommendation; either remove it or reframe as "extend the existing Android app to iOS" (iOS was never built/targeted, so that part is still legitimately future work).
   - **6.2.2 Integration of SMS and USSD Services** — SMS is done (Africa's Talking, Phase 16, four notification types). Only the **USSD** half is still genuinely future work — reword accordingly.
   - **6.2.3 Advanced GPS Tracking and Navigation** — basic live GPS tracking and turn-by-turn Google Maps navigation are both built. Reframe the recommendation around what's genuinely still missing: traffic-aware routing, predictive ETA beyond the current Haversine-distance estimate, automatic rerouting.
   - 6.2.4 (AI dispatching), 6.2.5 (EHR integration), 6.2.6 (cloud scalability), 6.2.7 (MFA/audit/encryption) all still appear to be genuinely unbuilt — fine to leave as-is, but double check 6.2.7's "audit logging" claim, since `incident_events` already functions as an append-only audit log; narrow that recommendation to what's actually still missing (e.g., admin-side audit log viewer UI, MFA, encryption at rest for sensitive fields).
   - Consider adding a new recommendation for **mobile money payment (Flutterwave)** — this is the one patient-portal feature that was explicitly scoped, then deferred by team decision (Phase 14). It belongs in Recommendations/Known Limitations as the clearest, most concrete "what's left" item, since everything else in the patient portal is done.

6. **Cover page date** ("July 2026") — confirm with the team whether the actual submission date has moved; today's date in this audit is 14 Aug 2026 and `COMPLETED_WORK.md`'s last entry is 10 Jul 2026 (`v2.0-complete` tag), so check whether anything shipped since then needs folding in, and whether "July 2026" is still the correct submission month.

7. Spot-check the rest of the report for any other place a feature is described as aspirational/future when it's actually built (or vice versa) — the two passes above (Patient role + this list) cover everything found in this audit, but do one more read-through of Chapters 5 and 6 specifically, since those are where "built vs. planned" claims cluster.

---

## Task 3 — Add the Questionnaire as an appendix

The Acknowledgement references *"staff of Healthstone Hospital, Banda, and Mulago National Referral Hospital, who generously participated in our questionnaires."* The report's current Table of Contents has an `APPENDICES` entry (page 42) but no content was found for it in this checkout.

- Locate the **original data-gathering questionnaire** used during the requirements/needs-assessment phase at Healthstone and Mulago (the instrument referenced in the Acknowledgement) and add it as an appendix.
- **Do not confuse it with `docs/EVALUATION_FORM.md`** — that's a different, later instrument (the post-build system evaluation form used in Phase 8/19 demo walkthroughs, evaluator roles: Patient/Dispatcher/Driver/Hospital/Admin). If the team actually means to attach `EVALUATION_FORM.md` instead of (or in addition to) the original data-gathering questionnaire, confirm that explicitly before proceeding — attaching the wrong one would misrepresent what evidence backs Chapter 2's problem-statement claims.
- If the original questionnaire no longer exists as a separate file, ask the team where it lives (may only exist as a paper form, an old proposal document, or a Google Form) before fabricating one.

---

## Process notes for whoever does the edit

- Edit `docs/FINAL_YEAR_REPORTS.md` directly — it's the Markdown source; `docs/FINAL YEAR REPORTS.docx` appears to be a Word export of it (pandoc-style artifacts like `\...\...` dot leaders and `![](md_output/media/imageN.png)` placeholders are visible in the `.md`, which is typical of a docx→md conversion). Confirm with the team which direction the sync goes — edit the `.md` and re-export to `.docx`, or edit the `.docx` and reconvert — **before** editing, so work isn't done in the file that gets overwritten.
- Keep the existing formatting conventions in the file (bold section headers, `###` for numbered sub-sections, the existing table styles) so the diff stays clean and the eventual Word re-export doesn't break.
- After edits, do one full top-to-bottom read for internal consistency: role counts stated in the Abstract, Scope, and User Requirements chapters should all agree (5, not 4); the ERD narrative in 4.3 should match the RLS table in 5.2 and the relationship summary in 5.3.
