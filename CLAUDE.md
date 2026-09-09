# CLAUDE.md — ERAMS Build Guide for Claude Code

## What This Project Is

ERAMS (Emergency Response and Ambulance Management System) is a **Flutter single-codebase application** for ambulance dispatch management in Uganda, built as a final-year project at Kyambogo University. It targets web (primary demo), Android (driver app), and optionally desktop.

**Backend:** Supabase (Postgres + PostGIS, Auth, Realtime, Edge Functions)  
**Web hosting:** Firebase Hosting (static Flutter web build only)  
**State management:** Riverpod  
**Maps:** `flutter_map` + OpenStreetMap (zero cost, no API key)  
**Routing:** `go_router`

---

## Essential Documents — Read These First

Before writing any code, read these two files in `docs/`:

| File | Purpose |
|------|---------|
| [`docs/ERAMS_TECHNICAL_BUILD_PLAN.md`](docs/ERAMS_TECHNICAL_BUILD_PLAN.md) | **Canonical build reference.** Full tech stack rationale, data model (ERD), dispatch flow (sequence diagram), repo structure, and all 9 build phases with exact tasks, deliverables, and target dates. This document supersedes all previous tech stack references. |
| [`docs/COMPLETED_WORK.md`](docs/COMPLETED_WORK.md) | **Progress tracker.** Shows what has been built, what is in progress, and what still needs team testing. Update this file whenever a task is completed — mark it `[x]` (done, needs testing) or `[✓]` (done and tested). |

**Always check `COMPLETED_WORK.md` before starting a phase** so you don't duplicate work or break something already delivered.

---

## Project Structure

```
ERAMS_01/
├── docs/
│   ├── ERAMS_TECHNICAL_BUILD_PLAN.md   ← canonical build reference
│   └── COMPLETED_WORK.md               ← progress tracker (update as you build)
├── .github/workflows/                   ← CI/CD (GitHub Actions)
├── lib/                                 ← Flutter source code
│   ├── main.dart
│   ├── app.dart                         ← root widget, theme, go_router setup
│   ├── core/
│   │   ├── config/                      ← Supabase keys, constants (via --dart-define)
│   │   ├── theme/                       ← colour palette, text styles
│   │   └── utils/                       ← shared helpers
│   ├── models/                          ← Dart data classes (Incident, Ambulance, Profile, Hospital)
│   ├── services/                        ← Supabase client calls, Realtime, auth helpers
│   ├── state/                           ← Riverpod providers
│   ├── features/
│   │   ├── auth/                        ← login screen, role-based routing
│   │   ├── dispatcher/                  ← dashboard, incident form, map, fleet panel
│   │   ├── driver/                      ← status toggle, location sharing, alerts
│   │   ├── hospital/                    ← incoming patient view
│   │   └── admin/                       ← user mgmt, analytics
│   └── widgets/                         ← shared widgets (map widget, status badge, etc.)
├── supabase/
│   ├── config.toml
│   ├── migrations/                      ← SQL migration files (schema, RLS, PostGIS)
│   ├── functions/                       ← Edge Functions (Deno/TypeScript)
│   │   ├── log_incident/
│   │   ├── assign_nearest_ambulance/
│   │   └── update_incident_status/
│   └── seed.sql                         ← demo hospitals, ambulances, users
├── web/                                 ← Flutter web platform files
├── test/                                ← unit & widget tests
├── pubspec.yaml
├── analysis_options.yaml
├── firebase.json
└── .firebaserc
```

---

## Environment Variables

The app reads Supabase credentials at build time via `--dart-define`. Copy `.env.example` to `.env` (git-ignored) and use these values when running:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=your_project_url \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key
```

Access them in Dart via:

```dart
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
```

---

## How to Run

```bash
# Web (primary dev target)
flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# Android (driver app)
flutter run -d <device_id> --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# Build for web deploy
flutter build web --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
firebase deploy --only hosting
```

---

## After Every Coding Session — Required Checklist

Before finishing any coding session or reporting a task complete, **always run:**

```bash
flutter analyze
```

- Zero issues = done. Commit.
- Any `info` or `warning` = fix before committing. Common fixes:
  - `prefer_const_constructors` → add `const` to the constructor
  - `prefer_const_literals_to_create_immutables` → move `const` to the constructor, remove from children
  - `deprecated_member_use` → apply the suggested replacement (e.g. `value` → `initialValue` on form fields; `withOpacity` → `withValues(alpha:)`)
  - Unused imports → delete them
- Do **not** suppress warnings with `// ignore:` unless there is a documented reason.

---

## Tech Conventions

- **State:** Use Riverpod providers. No `setState` in screens — lift state to a `StateNotifier` or `AsyncNotifier`.
- **Supabase calls:** All table reads/writes go through service classes in `lib/services/`. Screens only call providers; providers call services.
- **Realtime:** Subscribe in a service method; expose a `Stream` to Riverpod. Clean up subscriptions on dispose.
- **Routing:** All navigation via `go_router`. Role-based redirect logic lives in `app.dart` reading `profiles.role` from the Supabase session.
- **Maps:** Use `flutter_map` with OpenStreetMap tiles. Do not add Google Maps unless the team explicitly approves an API key setup.
- **Offline:** Use `Hive` or `sqflite` for local queuing. Do not swallow errors silently — queue failed writes and retry on reconnect.
- **No secrets in code:** Never hardcode Supabase URL, anon key, or any other credentials. Always use `--dart-define` or `.env` (git-ignored).

---

## Supabase Conventions

- **Migrations:** All schema changes go in `supabase/migrations/` as numbered SQL files (`001_initial_schema.sql`, `002_rls_policies.sql`, etc.). Never edit the DB manually without a corresponding migration file.
- **RLS:** Every table must have RLS enabled and at least one policy. See the build plan Section 4 for the policy matrix.
- **RPCs:** Server-side logic (dispatch, status transitions) lives in Postgres functions, not in Flutter. Call them via `supabase.rpc('function_name', params)`.
- **Edge Functions:** Deno/TypeScript, live in `supabase/functions/`. Deploy with `supabase functions deploy`.

---

## Build Phases Quick Reference

| Phase | Target Dates | Goal |
|-------|-------------|------|
| 0 | 17–18 Jun | Flutter project init, Supabase + Firebase setup, CI stubs |
| 1 | 18–20 Jun | DB schema, Auth, RLS, seed data, login + role routing |
| 2 | 20–22 Jun | Dispatcher dashboard, incident form, live map |
| 3 | 22–24 Jun | Auto-dispatch RPC (PostGIS nearest ambulance) |
| 4 | 24–25 Jun | Driver mobile: alerts, GPS updates, status transitions |
| 5 | 25–26 Jun | Hospital view: incoming patient, ETA, acknowledge |
| 6 | 26–27 Jun | Admin: fleet management, analytics dashboard |
| 7 | 27–29 Jun | Responsive polish, offline hardening, Firebase + APK deploy |
| 8 | 29–30 Jun | Validation, docs, demo prep, tag v1.0-demo |

For full task lists and deliverables, see `docs/ERAMS_TECHNICAL_BUILD_PLAN.md` Section 7.

---

## After Each Phase

1. Mark completed tasks `[x]` in `docs/COMPLETED_WORK.md`.
2. Add a note under "Needs Team Testing" for anything the team should validate manually.
3. Commit with a message like `feat(phase-N): <what was built>`.
4. If the deliverable is deployed (Phase 7+), update the Firebase Hosting URL in the README.
