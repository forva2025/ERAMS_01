# ERAMS — End-to-End Testing Guide

Emergency Response and Ambulance Management System · Kyambogo University Final Year Project

**Live app:** https://erams-98eb2.web.app/

This replaces `docs/TESTING_GUIDE.html`, which only covered the original 4-role, dispatcher-initiated flow. Since that guide was written, the system grew a fifth role (**Patient**) with a full ride-hailing-style booking flow, in-app chat and voice/video calls, SMS notifications, incident priority/triage, and a friendlier error-handling layer — none of which the old guide exercises. Use this one going forward.

---

## 1. Before You Start

You're testing the **live deployed app** — no local setup needed, just a browser (and, for a few checks, an Android phone with the APK installed).

Because dispatcher/driver/hospital/admin/patient actions need to happen **at the same time** to see real-time updates, and the app only holds one session per browser, open **several separate browser windows/profiles** signed into different accounts simultaneously — e.g. one normal window plus Incognito/Private windows, or different browsers (Chrome, Edge, Firefox, Brave). You'll need up to **5 concurrent sessions** for the fullest test (Dispatcher, Driver, Hospital, Admin, Patient); 3–4 is enough for most individual sections below.

Voice/video calling only works on the **Android app** (native), not on web — for that part of the checklist you need a real device with the APK installed (`flutter build apk --release --dart-define-from-file=.env.json`, or ask whoever last built one).

---

## 2. Test Accounts

The four seeded accounts share the password `Erams2026!`.

| Role | Email | Notes |
|---|---|---|
| Dispatcher | `katusiime66+dispatcher@gmail.com` | Logs incidents, dispatches ambulances |
| Driver | `katusiime66+driver@gmail.com` | Linked to ambulance `UBE 001A` |
| Hospital | `katusiime66+hospital@gmail.com` | Linked to Mulago National Referral Hospital |
| Admin | `katusiime66+admin@gmail.com` | Full access — fleet, users, hospitals, patients, analytics |

**Patient** has no seeded demo account — patients self-register in-app at `/patient/register` (email, phone, full name, password). Register a fresh test patient account as part of Part B below.

---

## 3. Part A — Dispatcher-Initiated Flow (original core flow)

This is the original telephone-in / dispatcher-logs-on-your-behalf flow — still the primary path for calls that come in by phone rather than through the app.

> **Tip:** only `UBE 001A` has a driver account linked to it. Drop your incident pin near **Nakasero** (central Kampala) so auto-dispatch picks `UBE 001A` — or use **Manual** assignment and pick it directly. See [Seeded Reference Data](#10-seeded-reference-data) below.

- [ ] **[Dispatcher]** Sign in, click **"New Incident"**, drop a pin near Nakasero, fill in nature of emergency / reporter details / patient condition notes, set hospital to Mulago, submit.
  - Expect: the incident appears instantly as a card + red map marker, status **LOGGED**, no refresh needed.
  - Expect: the card shows a **priority badge** (Critical/High/Medium/Low) automatically — pick a type like "Cardiac Arrest" and confirm it lands as **Critical** with no manual input.
- [ ] **[Dispatcher]** Tap the priority badge to override it up/down; confirm it updates on a second Dispatcher session in real time.
- [ ] **[Dispatcher]** Click **"Dispatch Nearest"** on the card (or **"Manual"** → assign `UBE 001A` directly if a different ambulance gets picked).
  - Expect: card updates to **DISPATCHED** with `UBE 001A` shown, no refresh.
- [ ] **[Driver]** Switch to the Driver session — confirm the active-incident alert appears automatically (real-time, no refresh).
  - Expect: both **Accept** and **Reject** are available (Reject requires picking a structured reason — see §11). A driver who does neither just lets the 30s countdown lapse, which auto-declines and re-offers to the next ambulance.
  - Tap **Accept**, try **"Navigate to Scene"** (opens Google Maps in a new tab, destination pre-loaded), then **"I'm En Route"**.
  - Expect: Dispatcher's card updates to **EN ROUTE** live, ambulance marker colour changes.
- [ ] **[Hospital]** Switch to the Hospital session — confirm the incident appears under **"Incoming"** with condition notes and a live ETA.
  - Click **"Acknowledge — Ready to Receive"**, then **refresh the page** — confirm it still shows "Acknowledged" (must survive a refresh).
- [ ] **[Driver]** Click **"I've Arrived"**, then **"Incident Complete"**.
  - Expect: incident disappears from the Dispatcher's active list, `UBE 001A` returns to **Available**.
- [ ] **[Dispatcher] + [Hospital] + [Driver]** Open the **History** tab in each — confirm the completed incident appears in all three.

---

## 4. Part B — Patient-Initiated Flow (ride-hailing-style booking)

This is the newer, patient-facing path — the system's main innovation over a plain dispatcher-run system, and the one the original testing guide never covered at all. The **patient initiates the incident**, not the dispatcher.

- [ ] **[Patient]** Go to `/patient/register`, create a fresh test account (name, phone, email, password) — confirm it lands you on the patient home screen (`/patient`).
- [ ] **[Patient]** Confirm the map shows nearby ambulances as numbered pins, colour-coded by service type (BLS/ALS/ICU), centred on your location (or Kampala if location permission is denied on web).
- [ ] **[Patient]** Tap a marker — confirm the info card shows plate number, service type, distance, fare estimate, and star rating.
- [ ] **[Patient]** Tap **"Request Ambulance"** → pick an emergency type, add notes, confirm/adjust the location pin → **"Find Nearby Ambulances"** → pick one from the ranked list → **"Select"**.
  - Expect: a "Waiting for driver to accept…" snackbar, the Request button disables, and you land directly on the **live tracking screen**.
- [ ] **[Driver]** On a second session signed in as the Driver account — confirm a **job-offer pop-up** appears immediately, regardless of which tab (Active/Chats/History) the driver is currently on, showing a 30-second countdown ring.
  - Expect: both **Accept** and **Reject** (with reason) are available — see §11 for the reject flow. If you let the countdown expire instead of acting, confirm the offer times out and (if another ambulance exists) gets re-offered rather than just vanishing.
  - Tap **Accept** — confirm the pop-up closes immediately and the active-incident card (with patient details) appears without needing a manual refresh.
- [ ] **[Patient]** Confirm the tracking screen updates to show the driver has accepted (status banner changes, driver name/phone appear on the bottom card), and the ambulance marker starts moving as the driver's GPS updates (~every 15s).
- [ ] **[Patient] + [Driver]** Tap the **chat FAB/button** on both sides — send a message from each, confirm it appears on the other side in real time with an unread badge.
- [ ] **[Patient] + [Driver], Android only** Tap the **voice call** and **video call** buttons — confirm both connect (mic/camera permission prompts, then a live call). On **web**, confirm both buttons instead show a "use the mobile app" message rather than crashing.
- [ ] **[Driver]** Advance the incident through **En Route → Arrived → Incident Complete**.
  - Expect: patient's tracking screen shows a completion dialog automatically (duration, fare, payment method) with **Skip** and **Rate Experience** options.
- [ ] **[Patient]** Tap **Rate Experience**, pick 1–5 stars, optionally add a comment, submit.
  - Expect: back on `/patient` with no active-trip banner; the ambulance's star rating updates (check the picker/home map card or Admin's Fleet tab).
- [ ] **[Dispatcher]** Confirm the patient-initiated incident showed up in the dispatcher's active list too (patient-initiated incidents are visible to dispatchers, not hidden from them).

---

## 5. Priority & Triage Checks

New since the original guide — every incident now gets an automatic severity rating.

- [ ] Log incidents of a few different emergency types (either flow) and confirm the auto-assigned priority makes sense: e.g. **Cardiac Arrest / Stroke / Unconscious Patient / Severe Bleeding → Critical**, **Breathing Difficulty / Trauma / Childbirth / Poisoning / Seizure → High**, **Road Traffic Accident / Fire-Burns → Medium**, **Other → Low**.
- [ ] Log a Critical incident *after* an existing Medium one — confirm it sorts **above** the older, lower-priority one on the Dispatcher dashboard, Hospital incoming list, and Admin Patients tab (priority-first, oldest-first within the same tier).
- [ ] Confirm the priority badge appears on: Dispatcher incident cards, the Driver's job-offer card and active-incident card, Hospital's incoming cards, and Admin's Patients tab rows.
- [ ] As Dispatcher or Admin, override a priority via the badge — confirm patients get **no** such override control (they shouldn't be able to self-triage).

---

## 6. Admin Module Checklist

Admin now has **6 tabs**: Live Map, Fleet, Hospitals, Users, Patients, Analytics.

- [ ] **Live Map** — confirm all ambulances/incidents/hospitals render with live positions and correct status colours; confirm the road-route line (not just a straight dashed line) appears for any `dispatched`/`en_route`/`arrived` incident.
- [ ] **Fleet** — confirm all 5 seeded ambulances show status, service type badge (BLS/ALS/ICU), and pricing. Add a test ambulance, assign a driver/hospital, save. Edit an existing one's assigned driver, confirm it persists after refresh. Try deleting an ambulance with incident history (should be blocked) and a fresh one with none (should succeed).
- [ ] **Hospitals** — confirm Healthstone and Mulago are listed. Add a hospital (name/address/phone/map pin), confirm it appears immediately and shows up in the Fleet tab's and Add-User dialog's hospital dropdowns without a refresh. Try deleting one with dependents (blocked) vs. one without (succeeds).
- [ ] **Users** — confirm all accounts show real names. Add User → confirm a one-time temp password shows, and the new account is forced to set its own password on first login. Edit Details / Reset Password on an existing user, confirm both persist / force a password change respectively. Change a role, confirm it updates immediately.
- [ ] **Patients** — confirm every incident (dispatcher- *and* patient-initiated) is listed with patient name/phone, emergency type, location, ambulance, hospital, status, priority, logged time, and response time. Confirm search/filter works across all fields.
- [ ] **Analytics** — confirm 4 KPI cards (total incidents, avg response time, calls today, completion rate), the fleet-status donut chart, response-time and emergency-type bar charts, and status breakdown all render without errors. Try **"Export to DHIS2"** (needs real or dummy DHIS2 credentials to see the flow) and **"Download Report"** (CSV, copy-to-clipboard — paste into a spreadsheet to confirm it's well-formed).

---

## 7. Communication Checks

- [ ] **Chat** — on any active incident, open chat from the Dispatcher's incident card, the Driver's active-incident card, the Hospital's incoming card, and the Patient's tracking screen. Confirm messages sync live across all open sessions and unread badges increment/reset correctly.
- [ ] **Driver's Chats tab** — with no active chats, confirm it shows a friendly "No conversations yet" empty state, not an error. With a network hiccup, confirm it shows a retry-able error state rather than a raw exception dump (see [Error-Handling Checks](#8-error-handling-checks) below).
- [ ] **Voice/video calls, Android only** — as above in Part B; confirm mute, camera-off, speaker-toggle, and camera-flip controls all work mid-call, and the end-call button cleanly leaves the channel.
- [ ] **SMS notifications** (only testable if `AT_API_KEY`/`AT_USERNAME` are set as Edge Function secrets, ideally `AT_USERNAME=sandbox`) — confirm SMS fires on: job offer to driver, driver-accepted to patient, driver-arrived to reporter, and incoming-patient to hospital. If SMS isn't configured, confirm the app flow still completes normally rather than blocking on the failure (check `incident_events` for an `sms_not_configured`/`sms_failed` row instead of a crash).

---

## 8. Error-Handling Checks

New since the original guide — a recent fix replaced raw exception text with friendly retry states across the app.

- [ ] Briefly disable your network (airplane mode, or disconnect Wi-Fi) and open a screen that loads data — e.g. the Driver's Chats tab, a chat sheet, or the Patient's trip tracking screen. Confirm you see a **friendly message with a Retry button**, not raw text like `ClientException with SocketException: Failed host lookup: ...`.
- [ ] Reconnect and tap **Retry** — confirm the screen recovers without needing to navigate away and back.

---

## 9. Other Checks

- [ ] **Profile sheet** — on every role, tap the profile icon in the app bar, edit name/phone, save, confirm it persists.
- [ ] **Sign out** — confirm it returns you to the Login screen from every role.
- [ ] **Responsive layout** — narrow the browser window (or open on a phone) and confirm Dispatcher/Admin stay usable, and Driver/Hospital/Patient look right at mobile width.
- [ ] **Android driver app** — install the APK on a physical device (`adb install -r build/app/outputs/flutter-apk/app-release.apk`) and repeat the relevant Part A/B steps from a real phone to confirm live GPS tracking, calls, and everything else work outside the browser sandbox.

---

## 10. Seeded Reference Data

Background info, not a test step — useful for planning pin locations.

| Hospital | Area |
|---|---|
| Healthstone Hospital | Banda, Nakawa Division |
| Mulago National Referral Hospital | Upper Mulago Hill Road |

| Ambulance | Area | Home Hospital | Driver |
|---|---|---|---|
| `UBE 001A` | Nakasero (central) | Mulago | Test driver account |
| `UBE 002A` | Ntinda (east) | Healthstone | — unassigned |
| `UBE 003A` | Mengo (southwest) | Mulago | — unassigned |
| `UBE 004A` | Bukoto (north) | Mulago | — unassigned |
| `UBE 005A` | Bweyogerere (far east) | Healthstone | — unassigned |

All 5 ambulances also carry a service type (BLS/ALS/ICU), base fare, per-km rate, and rating — visible in the patient's nearby-ambulance map and the Admin Fleet tab.

---

## 11. New Since 1 Sep 2026 — Excel Export, Reject-with-Reason, Call Ringing, Notifications

- [ ] **[Admin] Excel export** — Analytics tab (or wherever the export buttons live alongside "Download Report" CSV / "Export to DHIS2") — confirm a real `.xlsx` downloads with Summary, Patient Records, and Response Times sheets, and that it opens cleanly in Excel/Sheets (not just CSV renamed).
- [ ] **[Driver] Reject with reason** — on a job-offer card, tap Reject: confirm you must pick one of **Crew not qualified/lacking equipment**, **Outside operational area**, **Patient needs higher level of care**, or **Unsafe access conditions** (plus notes) before it submits — confirm it won't let you reject with no reason selected.
  - Confirm the patient and all dispatchers get notified of the rejection (check the in-app notification feed/banner on those sessions).
  - Confirm the incident still re-offers to the next-nearest ambulance afterward, same as the old timeout-based decline did.
- [ ] **In-app notifications** — trigger something that should notify you (e.g. a driver rejects, a call comes in) and confirm a Realtime banner/feed entry appears **without needing Firebase configured** (this is Supabase Realtime, not push — see §11 caveats). Don't expect an OS-level push notification if you background the app; that part needs manual Firebase setup first.
- [ ] **Call ringing** — from an active trip, tap Voice or Video Call (as in §7). Confirm the *other* party sees a **full-screen incoming-call screen** pop up (not just the existing call UI) with a vibration pattern, from anywhere in the app — not just if they happened to be on the trip-tracking/active-incident screen already. Expect **silence** where a ringtone should play (no audio file supplied yet — not a bug, see §11).

---

## 12. Known Caveats — Not Bugs

- **The driver's job-offer card has a Reject button again** (reinstated 1 Sep 2026, reversing the 29 Aug removal noted in earlier versions of this guide) — now requires picking a structured reason (see §12 below) rather than a bare reject.
- **Push notifications (FCM) don't work yet** — `firebase_options.dart` is still a placeholder (`flutterfire configure` hasn't been run), so `main.dart` skips Firebase entirely. The **in-app notification banner/feed is unaffected** — it's Supabase Realtime, not FCM — but nothing will arrive as an OS-level push when the app is backgrounded or killed.
- **Call ringing has no ringtone sound yet** — no `.mp3` has been supplied to `assets/sounds/` or `android/app/src/main/res/raw/` (both still empty or placeholder-only). The full-screen incoming-call UI and vibration should still work; only the audio will be silent.
- **Hospital ETA is a straight-line distance ÷ average-speed estimate**, not real routing — it will read optimistic compared to actual driving time. This is separate from the **route line drawn on the live maps** (Dispatcher, Admin, Driver, Patient tracking), which *does* use real road routing (OSRM) and shows the actual road path once an incident is dispatched.
- **Mobile money payment (Flutterwave) is not implemented** — deferred by team decision. Every trip currently completes with `payment_method: cash` regardless of what's shown; treat any payment-method selector as a placeholder for now.
- **The full patient-portal loop (request → accept → track → complete → rate) has not been click-through tested against the live production database by the team** — the last full pass was verified by static code-trace only (`flutter analyze`, migration sequence review), because no environment in the build pipeline had live credentials at the time. Treat this guide as the actual first real click-through and report anything that doesn't match what's described here.
- On Flutter **web**, a console warning/assertion near `window.dart` when GPS starts is a known Flutter web/geolocator quirk — harmless, doesn't affect functionality.

---

*See `docs/COMPLETED_WORK.md` for the full build history and phase-by-phase "Needs Team Testing" notes, and `docs/ERAMS_TECHNICAL_BUILD_PLAN.md` for technical detail. This file supersedes `docs/TESTING_GUIDE.html` for anything the two disagree on — the HTML predates the Patient role entirely.*
