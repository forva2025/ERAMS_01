# ERAMS — Manual Test Plan

Consolidated from the "Needs Team Testing" notes scattered across
`docs/COMPLETED_WORK.md` (phases 0–18 + Live Map). Run top to bottom for a full
smoke test, or jump to a section to re-verify one area after a change.

**Legend:** `[ ]` not yet tested · `[x]` tested, passed · `[!]` tested, failed (note the issue below the item)

**Demo accounts** (see root `README.md` for current credentials):
Dispatcher, Driver, Hospital Staff, Administrator are pre-seeded. Patients
self-register in-app — no pre-seeded account needed.

---

## 0. Environment Sanity

- [ ] `flutter analyze` runs clean (0 issues) before testing begins
- [ ] App loads in Chrome with no fatal console errors: `flutter run -d chrome --dart-define-from-file=.env.json`
- [ ] `supabase migration list --linked` shows no pending/unapplied migrations

---

## 1. Auth & Role Routing

- [ ] All 4 seeded accounts (Dispatcher, Driver, Hospital, Admin) log in and land on their correct role screen
- [ ] Register a brand-new patient account at `/patient/register` — confirm it redirects to `/patient` home
- [ ] Log out and log back in as that same patient — confirm same redirect
- [ ] Register a new patient with an invalid phone (e.g. `123456`) — confirm the form blocks submission with a clear error; valid formats (`0712345678`, `+256712345678`, `256712345678`) are all accepted
- [ ] Open the confirmation email for a new patient signup, click "Verify Account" — confirm it lands on the **live app** (not localhost) without crashing, and you're signed in afterward
- [ ] From Supabase Dashboard, send a password-recovery email to a test account, click the link — confirm it shows "Set a New Password" instead of a crash
- [ ] Refresh the browser on `/admin`, `/dispatcher`, `/patient`, etc. — confirm path-based routing survives a refresh (no 404)

---

## 2. Dispatcher Module

- [ ] Dispatcher dashboard loads with the map centred on Kampala
- [ ] "New Incident": pick a location on the map, fill all fields, submit — card appears in the list and a red marker appears on the map without refreshing
- [ ] Open a second browser tab as Dispatcher — confirm the new incident appears there in real time too
- [ ] Status badge colours are correct: logged=teal, dispatched=orange, en_route=blue, arrived=purple
- [ ] Tap an incident card → map flies to that incident's location and highlights the card
- [ ] Ambulance markers show correct status colours

### Auto-Dispatch RPC
- [ ] Log a new incident near Kampala, click "Dispatch Nearest" — confirms it auto-assigns the geographically nearest ambulance (check `incidents.assigned_ambulance_id` / `ambulances.status` in Supabase)
- [ ] Card updates to "DISPATCHED" without a page refresh
- [ ] Set all ambulances to `busy` in the DB, click "Dispatch Nearest" — red error banner + "Manual" button appear
- [ ] Click "Manual" → `ManualDispatchDialog` shows all ambulances with status/distance; picking one succeeds
- [ ] Check `incident_events` table — an audit row exists for each dispatch

### Live Map tab (Admin/Driver/Hospital)
- [ ] Admin Live Map tab — ambulances/incidents/hospitals render with correct live positions and status colors
- [ ] Driver map — shows patient, hospital, and own location correctly during an active incident
- [ ] Hospital map — incoming ambulances appear as they approach, matching the ETA in incident cards

---

## 3. Driver Module

- [ ] Driver screen shows the correct ambulance header and GPS auto-starts (green indicator)
- [ ] From a Dispatcher session, dispatch an incident to that ambulance — driver screen shows the incident card instantly (Realtime, no refresh)
- [ ] "I'm En Route" → Dispatcher's card updates to "EN ROUTE"; ambulance marker colour changes
- [ ] "I've Arrived" → "Incident Complete" → incident disappears from dispatcher list, ambulance returns to Available
- [ ] Ambulance GPS position updates on the Dispatcher map every ~15s while driving
- [ ] Toggle driver to "Offline" — GPS indicator turns grey and stops updating
- [ ] "Navigate to Scene" button opens Google Maps with the incident location pre-loaded, driving mode selected (only shows when incident has a pinned location)

---

## 4. Hospital Module

- [ ] Hospital screen shows correct hospital name header
- [ ] From Dispatcher, log + assign an incident to this hospital — card appears without refreshing
- [ ] Ambulance plate, status, and ETA update live as the driver pushes GPS
- [ ] "Acknowledge" button turns into green "Acknowledged"; entry appears in `incident_events` (event_type='message', payload contains 'hospital_acknowledged')
- [ ] Complete the incident from the driver side — card disappears from hospital view

---

## 5. Admin Module

### Fleet tab
- [ ] Seeded ambulances appear with status badges
- [ ] "Add Ambulance" — plate, driver, hospital, service type (BLS/ALS/ICU), pricing all save correctly
- [ ] Edit an ambulance's driver assignment — persists after refresh
- [ ] Delete an ambulance with incident history — blocked with a clear error; delete one with no history — succeeds

### Users tab
- [ ] All demo + newly registered accounts are listed
- [ ] Tap a role badge, change a user's role — updates in Supabase `profiles`
- [ ] "Add User" → fill in a new account → temp password dialog appears, user shows up immediately
- [ ] Sign in as that new user with the temp password — lands on "Set a New Password" before reaching their dashboard
- [ ] ⋮ menu → "Edit Details" — change name/phone, persists after refresh
- [ ] ⋮ menu → "Reset Password" → confirm → sign in with new temp password → forced password-change screen reappears

### Hospitals tab
- [ ] Healthstone and Mulago are listed
- [ ] "Add Hospital" — name/address/phone + map-pin location saves and appears immediately (and in Fleet tab / Add User hospital dropdowns without refresh)
- [ ] Edit an existing hospital, confirm changes persist after refresh
- [ ] Delete a hospital with dependents (ambulances/staff) — blocked with a clear message; delete one with none — succeeds

### Patients tab
- [ ] All logged incidents appear, newest first, with patient name/phone, emergency type, location, ambulance plate, hospital, status badge, logged time, response time
- [ ] Search box filters across all fields
- [ ] Run a full dispatch cycle — record updates on refresh

### Analytics tab
- [ ] Total incident count matches seeded data
- [ ] Run a full dispatch flow end-to-end — response time appears in Avg Response KPI
- [ ] 4 KPI cards, fleet utilisation donut, response-time bar chart, calls-by-emergency-type chart all render
- [ ] "Download Report" CSV — copies valid RFC-4180 data; paste into Excel/Sheets renders correctly
- [ ] "Export to DHIS2" — succeeds with valid credentials, shows a clear error with invalid ones

---

## 6. Patient Portal (Phases 9–13, 15)

### Home & request
- [ ] Ambulance markers appear on the map (numbered, coloured by service type), centred on device GPS (or Kampala if permission denied)
- [ ] Tap a marker — info card shows plate, service type badge, distance, fare estimate, star rating
- [ ] Count chip updates correctly
- [ ] "Request Ambulance" → emergency type dropdown, notes, GPS location with "Change Location" — all work
- [ ] "Find Nearby Ambulances" → ranked list shows distance/fare/rating/service type
- [ ] "Select" → snackbar "Waiting for driver to accept…"; Request button disables; amber banner appears on home screen

### Driver accept/decline
- [ ] Driver sees `_JobOfferCard` with a 30-second countdown ring
- [ ] Driver accepts → both sides advance to `dispatched`
- [ ] Driver declines (or countdown expires) → next available driver is offered; if none, incident resets to `logged`
- [ ] Dispatcher dashboard shows patient-initiated `pending_acceptance` incidents in the active list

### Live tracking
- [ ] Selecting an ambulance lands directly on the tracking screen (not home)
- [ ] Status banner shows correct colour/message for each status (pending, dispatched, en_route, arrived)
- [ ] Driver marker appears once ambulance has a GPS location; moves as driver pushes updates
- [ ] ETA and distance update as ambulance moves
- [ ] Once driver accepts, driver name + "Call" button appear; tapping "Call" opens the phone dialler
- [ ] Active-trip banner on home screen is tappable → opens tracking screen
- [ ] "Incident Complete" by driver → completion dialog appears automatically (duration, fare)

### Rating
- [ ] Completion dialog offers "Skip" (→ `/patient`) and "Rate Experience" (→ rating screen)
- [ ] Selecting 1–5 stars enables Submit; submitting navigates home
- [ ] Skipping navigates home without recording a rating
- [ ] Ambulance's star average updates in patient home + picker cards after refresh
- [ ] Admin Fleet tab shows updated rating count

---

## 7. In-App Messaging (Phase 13)

- [ ] Patient sends a message → driver sees it in real time (no refresh)
- [ ] Driver replies → patient sees it instantly on tracking screen (badge on chat FAB)
- [ ] Dispatcher opens chat on an incident → sees all messages from patient and driver
- [ ] Unread badge increments on all sides when messages arrive while chat is closed
- [ ] Opening chat resets badge to 0
- [ ] Messages persist after a page refresh

---

## 8. Voice & Video Calls (Phase 18 — native/Android only)

- [ ] On Android, driver accepts a dispatched incident → "Voice Call" and "Video Call" buttons appear on the active incident card
- [ ] "Voice Call" → mic permission → "Connecting…" → both sides can hear each other once joined
- [ ] "Video Call" → camera+mic permission → local PiP preview; remote video fills screen when the other party joins
- [ ] Patient's tracking screen shows green (voice) and blue (video) FABs once driver has accepted
- [ ] Mute, camera-off, flip-camera, and speaker toggle all work
- [ ] End button leaves the channel and returns to the previous screen
- [ ] On **web**, tapping either call button shows a "use the mobile app" message — no crash

---

## 9. SMS Notifications (Phase 16)

*Requires `AT_API_KEY`/`AT_USERNAME` set as Supabase secrets; use `AT_USERNAME=sandbox` for free testing.*

- [ ] Patient submits a request → driver's registered number receives the job-offer SMS
- [ ] Driver declines (or countdown expires) → next nearest driver receives a fresh job-offer SMS
- [ ] Driver accepts → patient receives "driver accepted" SMS with ETA
- [ ] Driver taps "I've Arrived" → reporter's number receives an arrival SMS
- [ ] Dispatcher dispatches an incident with a hospital assigned → hospital's `contact_phone` receives the incoming-patient SMS
- [ ] With `AT_API_KEY`/`AT_USERNAME` unset, confirm the app flow completes normally and `incident_events` logs `sms_failed`/`sms_not_configured` instead of crashing

---

## 10. Profile, History & Responsive Layout (Phase 7)

- [ ] Profile icon in any role's app bar opens the profile sheet with correct name, role badge, phone; editing name/phone saves and closes
- [ ] Dispatcher History tab — completed/cancelled incidents appear, searchable
- [ ] Hospital History tab — only that hospital's incidents appear
- [ ] Driver History tab — only trips for that driver's ambulance appear
- [ ] Deployed URL usable on both desktop and mobile browsers
- [ ] Android APK installs and the GPS toggle starts location updates (check `ambulances.current_location` updates every ~15s in Supabase)

---

## 11. Known Gap — Do Not Test (Not Yet Built)

- **Mobile money payment (Flutterwave)** — Phase 14 is deferred. Patients currently have no payment step; `trips.payment_method`/`payment_status` exist in the schema but nothing sets them yet. Skip this in the full smoke test below.

---

## 12. Full End-to-End Smoke Test (Phase 19)

Run once, start to finish, to confirm the whole system works together:

1. [ ] Patient registers a new account
2. [ ] Patient requests an ambulance (skip payment — not yet built)
3. [ ] Driver receives job offer (SMS + in-app) and accepts
4. [ ] Patient tracks the driver live on the map; ETA updates
5. [ ] Patient and driver exchange at least one chat message
6. [ ] (Android only) Patient/driver complete a short voice or video call
7. [ ] Driver marks En Route → Arrived → Complete
8. [ ] Patient sees completion summary and submits a rating
9. [ ] Admin Analytics reflects the new incident (count, response time, rating)
10. [ ] Admin Patients tab shows the full record with correct status/response time

If all 10 steps pass, the system is ready to tag `v2.0-complete` (see `docs/COMPLETED_WORK.md` Phase 19).
