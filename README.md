# ERAMS — Emergency Response and Ambulance Management System

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=flat-square&logo=supabase&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Hosting-FFCA28?style=flat-square&logo=firebase&logoColor=black)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)
![Status](https://img.shields.io/badge/Status-v2.0--complete-brightgreen?style=flat-square)

> **Final Year Project — Bachelor of Information Technology and Computing**  
> Kyambogo University | Uganda | Academic Year 2025–2026

---

## Live Demo

| Target | URL / File |
|--------|-----------|
| **Web app (Dispatcher, Hospital, Admin)** | Deployed via Firebase Hosting — see GitHub Actions for the live URL after CI passes |
| **Android APK (Driver)** | Built locally: `flutter build apk --release --dart-define-from-file=.env.json` |

**Demo credentials** (Supabase Auth):

| Role | Email | Password |
|------|-------|----------|
| Dispatcher | `katusiime66+dispatcher@gmail.com` | `Erams2026!` |
| Driver | `katusiime66+driver@gmail.com` | `Erams2026!` |
| Hospital Staff | `katusiime66+hospital@gmail.com` | `Erams2026!` |
| Administrator | `katusiime66+admin@gmail.com` | `Erams2026!` |

Patients self-register in-app at `/patient/register` — no pre-seeded demo account required.

---

## What ERAMS Does

ERAMS digitises emergency ambulance dispatch across two Kampala hospitals — **Mulago National Referral Hospital** and **Healthstone Hospital, Banda**. It replaces manual telephone dispatch and paper logbooks, and adds a patient-facing, ride-hailing-style booking flow (like SafeBoda/Faras) on top of the original dispatcher-run system:

- **Patient self-service booking** — patients see nearby ambulances on a live map (price, rating, service type: BLS/ALS/ICU), submit a request, and a driver **accepts or declines** the job (30-second countdown), instead of being silently assigned
- **Automated nearest-ambulance dispatch** — PostGIS `ST_Distance` picks the closest available unit for both patient- and dispatcher-initiated incidents; dispatcher can always override manually
- **Live GPS tracking** — driver location uploads every 15 s; appears in real time on the dispatcher's, patient's, and hospital's maps
- **Live trip tracking (patient side)** — full-screen map with moving ambulance marker, live ETA, and a completion summary (duration, fare) at the end of the trip
- **In-app chat** — real-time text messaging between patient, driver, and dispatcher on any active incident
- **Voice & video calls** — Agora-powered calling between patient and driver (native/Android only; web shows a graceful "use the mobile app" message)
- **Post-trip ratings** — patients rate the ambulance 1–5 stars after completion; the ambulance's running average updates via a Postgres trigger
- **SMS notifications** — Africa's Talking sends SMS at every key milestone (job offer, driver accepted, driver arrived, hospital incoming-patient) as a fallback for anyone not watching the app
- **Role-based access control** — five roles (Patient, Dispatcher, Driver, Hospital Staff, Administrator) each see only their own module
- **Advance hospital notifications** — hospital staff see the incoming patient, ambulance status, and live ETA before arrival
- **Live Map views** — admin, driver, and hospital screens each have a real-time map of ambulances/incidents/hospitals relevant to that role
- **Incident history & analytics** — completed/cancelled incidents searchable by role; admin dashboard shows KPIs, fleet utilisation, response-time and emergency-type charts, and a CSV / DHIS2 export
- **Offline resilience** — failed GPS pushes queue and retry automatically on the next 15 s tick

**Known gap:** in-app mobile money payment (Flutterwave — MTN MoMo, Airtel Money, card) is **deferred** — see [Known Limitations](#known-limitations-mvp) below. The planned design is documented in [`docs/diagrams/DIAGRAMS.md`](docs/diagrams/DIAGRAMS.md#5-sequence-diagram--payment-flow-planned-phase-14).

---

## Architecture

```
┌───────────────────────────────────────────────────────────────────────┐
│                             Flutter Client                             │
│  ┌─────────┐ ┌────────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐    │
│  │ Patient │ │ Dispatcher │ │  Driver  │ │ Hospital │ │ Admin  │    │
│  │(web/And)│ │   (web)    │ │(Android) │ │  (web)   │ │ (web)  │    │
│  └────┬────┘ └─────┬──────┘ └────┬─────┘ └────┬─────┘ └───┬────┘    │
│       │        go_router + Riverpod            │            │         │
└───────┼─────────────┼──────────────┼───────────┼────────────┼─────────┘
        │             │              │           │            │
        ▼             ▼              ▼           ▼            ▼
┌───────────────────────────────────────────────────────────────────────┐
│                                Supabase                                 │
│                                                                         │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────┐            │
│  │  Postgres   │  │   Realtime   │  │  Auth (email/pw)   │            │
│  │  + PostGIS  │  │  (websocket) │  │  + RLS policies    │            │
│  └──────┬──────┘  └──────┬───────┘  └────────────────────┘            │
│         │                │                                             │
│  ┌──────▼───────────────────────────────────────────────────────┐     │
│  │  Tables: profiles · hospitals · ambulances · incidents ·      │     │
│  │          incident_events · trips · messages                    │     │
│  │  RPCs:   dispatch_incident · update_incident_status ·          │     │
│  │          accept_trip · decline_trip · nearby_ambulances        │     │
│  └─────────────────────────────────────────────────────────────┘     │
│                                                                         │
│  ┌─────────────────────────── Edge Functions ─────────────────────┐   │
│  │  admin_create_user · admin_reset_password · send_sms ·         │   │
│  │  generate_agora_token · export_to_dhis2                        │   │
│  └─────────────────────────────────────────────────────────────┘     │
└───────────────────────────────────────────────────────────────────────┘
        │                    │                    │
        ▼                    ▼                    ▼
┌───────────────┐  ┌──────────────────┐  ┌──────────────────────┐
│ Africa's      │  │ Agora            │  │ DHIS2 (optional)      │
│ Talking (SMS) │  │ (voice/video)    │  │ health data export     │
└───────────────┘  └──────────────────┘  └──────────────────────┘
        │
        ▼
┌───────────────────────────────────────────────────────────────────────┐
│                      Firebase Hosting (web only)                        │
│                Static Flutter web build → `build/web`                   │
└───────────────────────────────────────────────────────────────────────┘
```

| Layer | Technology |
|-------|-----------|
| Client | Flutter 3.x (single codebase — web + Android) |
| State management | Riverpod (`AsyncNotifier`, `FutureProvider`, `StateProvider`) |
| Navigation | `go_router` with role-based redirect (5 roles) |
| Maps | `flutter_map` + OpenStreetMap (zero cost, no API key) |
| Backend | Supabase (Postgres + PostGIS, Auth, Realtime, Edge Functions) |
| SMS | Africa's Talking (server-side Edge Function; graceful no-op if unconfigured) |
| Voice/video calls | Agora RTC (native/Android only; web degrades gracefully) |
| Analytics export | DHIS2 Data Value Sets API + CSV download |
| Web hosting | Firebase Hosting |
| CI/CD | GitHub Actions |
| **Not yet integrated** | Flutterwave (mobile money) — Phase 14 deferred |

---

## Data Model (ERD — simplified)

Full diagrams (DFDs, use case, sequence flows) are in
[`docs/diagrams/DIAGRAMS.md`](docs/diagrams/DIAGRAMS.md).

```
profiles ──────────────────────────────────────┐
  id (uuid, FK → auth.users)                   │
  full_name, phone, role (patient/dispatcher/   │
    driver/hospital/admin), hospital_id, email  │
                                                │
hospitals ─────────────────────────────────────┤
  id, name, address, contact_phone,             │
  location (geography)                          │
                                                │
ambulances ────────────────────────────────────┤
  id, plate_number, status, current_location    │
  driver_id (FK → profiles), hospital_id        │
  service_type (BLS/ALS/ICU), base_fare,        │
  price_per_km, rating, rating_count,           │
  equipment_notes                               │
                                                │
incidents ─────────────────────────────────────┤
  id, reporter_name, reporter_phone             │
  location (geography), location_description   │
  nature_of_emergency, patient_condition_notes  │
  photo_url                                     │
  status (logged/pending_acceptance/dispatched/ │
          en_route/arrived/completed/cancelled) │
  assigned_ambulance_id (FK → ambulances)       │
  hospital_id (FK → hospitals)                  │
  patient_id (FK → profiles, nullable)          │
  created_at, arrived_at, completed_at          │
                                                │
trips ─────────────────────────────────────────┤
  id, incident_id (FK), ambulance_id, driver_id │
  patient_id, status, fare_amount,               │
  payment_method, payment_status, payment_ref   │
  patient_rating, patient_comment                │
  offered_at, accepted_at, declined_at           │
                                                │
messages ──────────────────────────────────────┤
  id, incident_id (FK), sender_id, sender_role, │
  sender_name, body, created_at                 │
                                                │
incident_events ────────────────────────────── ┘
  id, incident_id (FK), actor_id (FK → profiles)
  event_type, payload (jsonb), created_at
```

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Flutter SDK | 3.x stable | https://docs.flutter.dev/get-started/install |
| Android Studio or VS Code | latest | + Flutter/Dart extensions |
| Supabase CLI | latest | `npm install -g supabase` |
| Firebase CLI | latest | `npm install -g firebase-tools` |

---

## Local Setup

### 1. Clone & install

```bash
git clone https://github.com/Eugikats/ERAMS_01.git
cd ERAMS_01
flutter pub get
```

### 2. Configure credentials

Create `.env.json` from the example (git-ignored):

```bash
cp .env.example .env.json
```

Edit `.env.json` to match this format:

```json
{
  "SUPABASE_URL": "https://walbcsfwwgyerhfgbjdp.supabase.co",
  "SUPABASE_ANON_KEY": "your-anon-key-here"
}
```

> The `.vscode/launch.json` is pre-configured — press **F5** in VS Code to run on Chrome with credentials injected automatically.

### 3. Run on web (Chrome)

```bash
flutter run -d chrome --dart-define-from-file=.env.json
```

### 4. Run on Android

```bash
flutter devices                            # find your device ID
flutter run -d <device_id> --dart-define-from-file=.env.json
```

---

## Supabase Setup (first time only)

```bash
# Link to the remote project
supabase link --project-ref walbcsfwwgyerhfgbjdp

# Apply all migrations (schema, RLS, dispatch RPCs, marketplace, trips, messages)
supabase db push

# Seed demo hospitals, ambulances, and user profiles
# (Run seed.sql via Supabase Dashboard → SQL Editor)

# Deploy Edge Functions
supabase functions deploy admin_create_user
supabase functions deploy admin_reset_password
supabase functions deploy send_sms
supabase functions deploy generate_agora_token
supabase functions deploy export_to_dhis2
```

Enable the **PostGIS** extension in the Supabase dashboard:  
**Database → Extensions → postgis → Enable**

Demo accounts (Dispatcher/Driver/Hospital/Admin) must be created manually in **Authentication → Users → Add User** using the emails in the table above, then `seed.sql` sets correct roles. Patients self-register in-app — no manual account creation needed.

### Optional third-party integrations

These are independent of the core dispatch flow — the app works without them, they just add SMS, calling, and export capability:

```bash
# SMS notifications (Africa's Talking) — use AT_USERNAME=sandbox for free testing
supabase secrets set AT_API_KEY=your_api_key AT_USERNAME=your_username

# Voice/video calls (Agora) — leave AGORA_APP_CERTIFICATE unset for demo/test-mode tokens
supabase secrets set AGORA_APP_ID=your_app_id AGORA_APP_CERTIFICATE=your_app_certificate
```

Then pass the Agora App ID to the Flutter build:

```bash
flutter run -d chrome --dart-define-from-file=.env.json --dart-define=AGORA_APP_ID=your_app_id
```

If `AT_API_KEY`/`AT_USERNAME` are unset, SMS calls fail silently and log an `incident_events` row (`sms_not_configured`) instead of blocking the app. DHIS2 export takes credentials interactively from the Admin Analytics tab — no secret needed to deploy the function itself.

**Not implemented:** Flutterwave (mobile money payment) — Phase 14 is deferred; see [Known Limitations](#known-limitations-mvp).

---

## Deployment

### Web — Firebase Hosting (CI/CD)

Pushing to `main` triggers the GitHub Actions workflow automatically:

```
.github/workflows/firebase-hosting-merge.yml
```

It runs `flutter analyze` → `flutter test` → `flutter build web --release` → `firebase deploy`.

**Required GitHub repository secrets:**

| Secret | Where to find it |
|--------|-----------------|
| `SUPABASE_URL` | Supabase project → Settings → API |
| `SUPABASE_ANON_KEY` | Supabase project → Settings → API |
| `FIREBASE_SERVICE_ACCOUNT_ERAMS_98EB2` | Firebase → Project Settings → Service Accounts |

### Android APK (manual)

```bash
flutter build apk --release --dart-define-from-file=.env.json
# Output: build/app/outputs/flutter-apk/app-release.apk
# Transfer to device: adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Project Structure

```
ERAMS_01/
├── docs/
│   ├── ERAMS_TECHNICAL_BUILD_PLAN.md   ← full architecture & phase specs
│   ├── COMPLETED_WORK.md               ← progress tracker
│   ├── EVALUATION_FORM.md              ← structured user evaluation form (7 sections, A-G)
│   └── diagrams/DIAGRAMS.md            ← DFDs, use case, sequence diagrams (Mermaid)
├── .github/workflows/                   ← CI/CD (Firebase + Supabase deploy)
├── lib/
│   ├── main.dart                        ← app entry point, Supabase init
│   ├── app.dart                         ← root widget, theme, go_router
│   ├── core/
│   │   ├── config/                      ← Supabase credentials (--dart-define)
│   │   ├── theme/                       ← AppColors, AppTheme
│   │   └── utils/                       ← geo_utils (EWKB → lat/lng)
│   ├── models/                          ← Profile, Hospital, Ambulance, Incident, Trip, ChatMessage
│   ├── services/                        ← Supabase client wrappers (one per domain),
│   │                                        agora_service (native/stub), sms_service
│   ├── state/                           ← Riverpod providers & notifiers
│   ├── features/
│   │   ├── auth/                        ← login screen, patient registration, role-based redirect
│   │   ├── dispatcher/                  ← dashboard, live map, incident form, dispatch
│   │   ├── driver/                      ← GPS tracking, live map, job offers, chat, calls
│   │   ├── hospital/                    ← incoming patients, ETA, acknowledge, live map
│   │   ├── admin/                       ← fleet/users/hospitals, analytics, live map, DHIS2 export
│   │   └── patient/                     ← home map, request form, ambulance picker,
│   │                                        trip tracking, rating
│   └── widgets/                         ← StatusBadge, AppLogo, ProfileEditSheet,
│                                           IncidentHistoryList, ChatSheet, CallScreen
├── supabase/
│   ├── migrations/                      ← schema, RLS, dispatch RPCs, patient role,
│   │                                        ambulance marketplace, trips, messages, ratings
│   ├── functions/                       ← admin_create_user, admin_reset_password, send_sms,
│   │                                        generate_agora_token, export_to_dhis2 (Deno/TypeScript)
│   └── seed.sql                         ← demo hospitals, ambulances, users
├── web/                                 ← Flutter web platform files
├── pubspec.yaml
├── firebase.json / .firebaserc
└── .env.example
```

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| `flutter_map` + OpenStreetMap instead of Google Maps | Zero cost, no API key required — important for a student project with limited budget |
| Supabase Realtime re-fetch pattern (not raw payload) | PostGIS geography columns arrive as hex WKB in Realtime payloads, which require custom parsing; re-fetching via REST returns clean GeoJSON |
| `SECURITY DEFINER` Postgres RPCs for dispatch | Ensures atomic dispatch (ambulance + incident updated in one transaction) with server-side role validation, not client-side |
| Straight-line Haversine ETA (÷ 40 km/h) | Routing APIs (OSRM, Google Directions) add cost and complexity; straight-line is sufficient for MVP demonstration |
| GPS queue-and-retry on driver | Addresses the connectivity reliability concern raised in both Mulago and Healthstone stakeholder interviews |

---

## Known Limitations (MVP)

- **Mobile money payment (Flutterwave) is not implemented.** Phase 14 was deprioritized by team decision (3 Jul 2026) — every other patient-portal phase (request, accept/decline, tracking, chat, calls, rating, SMS) is complete, so this is the one gap in the patient request → pay → dispatch loop. The planned design (MTN MoMo, Airtel Money, card, and cash) is documented in [`docs/diagrams/DIAGRAMS.md`](docs/diagrams/DIAGRAMS.md#5-sequence-diagram--payment-flow-planned-phase-14). Currently, `trips.payment_method`/`payment_status` exist in the schema but nothing sets them.
- **ETA** is a straight-line distance estimate divided by an average speed of 40 km/h — not a routing API result. Accuracy degrades for routes with significant road detours.
- **Voice/video calls (Agora) are native/Android only.** Flutter web shows a "use the mobile app" message instead of a live call — `agora_rtc_engine` doesn't support web in this build.
- **Desktop native build** (Windows/macOS) is not a target. The "desktop" experience is the responsive web app viewed in a browser.
- **Push notifications** (FCM) are not implemented. Drivers receive alerts only while the app is open; SMS (Africa's Talking) is the fallback channel for anyone not actively watching the app.
- **Multi-dispatch** (one incident, multiple ambulances) is not supported. Each incident has a single `assigned_ambulance_id`.
- **No live click-through smoke test was performed before tagging `v2.0-complete`.** The tag reflects static verification only (analyzer, tests, code-trace) — see the Phase 19 note above.

---

## Running Tests

```bash
flutter test
```

---

## Build Phases Summary

| Phase | Deliverable | Status |
|-------|-------------|--------|
| 0 | Flutter project init, Supabase + Firebase setup, CI stubs | ✓ Complete |
| 1 | DB schema, Auth, RLS, seed data, login + role routing | ✓ Complete |
| 2 | Dispatcher dashboard, incident form, live map, Realtime | ✓ Complete |
| 3 | Auto-dispatch RPC (PostGIS nearest), manual override | ✓ Complete |
| 4 | Driver module — GPS tracking, alerts, status transitions | ✓ Complete |
| 5 | Hospital module — incoming patients, live ETA, acknowledge | ✓ Complete |
| 6 | Admin module — fleet management, user roles, analytics | ✓ Complete |
| 7 | Profile sheet, history tabs (all roles), GPS web guard | ✓ Complete |
| 8 | Evaluation form, final docs, `v1.0-demo` tag | ✓ Complete |
| 9 | Schema extensions — patient role, ambulance marketplace, `trips`/`messages` tables | ✓ Complete |
| 10 | Patient registration, login, home screen (nearby ambulances map) | ✓ Complete |
| 11 | Ambulance request form, driver accept/decline (30s countdown) | ✓ Complete |
| 12 | Live trip tracking (patient side) | ✓ Complete |
| 13 | In-app text messaging (patient ↔ driver ↔ dispatcher) | ✓ Complete |
| 14 | Mobile money payment (Flutterwave) | **Deferred** |
| 15 | Ratings system (1–5 stars, ambulance average) | ✓ Complete |
| 16 | SMS notifications (Africa's Talking) | ✓ Complete |
| 17 | DHIS2 export & analytics enhancements | ✓ Complete |
| 18 | Voice & video calls (Agora) | ✓ Complete |
| — | Live Map views (admin, driver, hospital) | ✓ Complete |
| 19 | Final validation, diagrams, evaluation form Section G, `v2.0-complete` tag | ✓ Complete (static sign-off — see below) |

Full phase specifications and progress: [`docs/COMPLETED_WORK.md`](docs/COMPLETED_WORK.md)

**Note on Phase 19 sign-off:** the live, click-through smoke test was waived by team decision (10 Jul 2026) rather than left indefinitely blocking the tag — no environment in this project's toolchain had real credentials for the live Supabase project or a way to drive the web UI directly. Phase 19 closes on static verification instead: `flutter analyze` (0 issues), `flutter test` (passing), and a full code-trace of the patient request→accept→track→complete→rate loop. This is an accepted-risk decision — the driver-side realtime fixes from 7–8 Jul (job-offer modal, GPS-tick flicker fix, patient polling backstop, live-map route highlighting) were verified only by code-trace, never against production. See `docs/COMPLETED_WORK.md` Phase 19 for the full note.

---

## Team

| Name | Role |
|------|------|
| Ashaba Ritah | Team member |
| Ochiria Elias Onyait | Team member |
| Katusiime Eugene | Team member |
| Ashaka Joseph | Team member |

**Supervisor:** Ms. Shallon Ahimbisibwe, Department of Computer Science, Kyambogo University

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

© 2025–2026 Ashaba Ritah, Ochiria Elias Onyait, Katusiime Eugene, Ashaka Joseph — Kyambogo University
