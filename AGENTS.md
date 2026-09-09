# AGENTS.md — ERAMS Build Guide for AI Coding Assistants

This file is for AI coding assistants other than Claude Code (e.g. Gemini, Copilot, Cursor, GPT-based tools). It mirrors the intent of `CLAUDE.md` but is written for any capable AI agent.

---

## Project Summary

**ERAMS** (Emergency Response and Ambulance Management System) is a cross-platform application built with **Flutter** (single codebase targeting web, Android, and optionally desktop). It manages ambulance dispatch, live GPS tracking, and hospital arrival notifications for emergency medical services in Uganda.

**Backend:** Supabase (Postgres + PostGIS, Auth, Realtime, Edge Functions/RPC)  
**Web hosting:** Firebase Hosting (static Flutter web build — no server-side logic here)  
**State management:** Riverpod  
**Maps:** `flutter_map` + OpenStreetMap tiles  
**Routing:** `go_router`

This is a final-year project at Kyambogo University with a **two-week build window (17–30 June 2026)**, so scope decisions should aggressively favour the MVP path.

---

## Read These First

| File | What It Contains |
|------|-----------------|
| [`docs/ERAMS_TECHNICAL_BUILD_PLAN.md`](docs/ERAMS_TECHNICAL_BUILD_PLAN.md) | The **canonical technical reference**: full architecture, ERD, dispatch sequence diagram, repository structure, and 9 phased build modules with tasks and target dates. All coding decisions should be traceable to this document. |
| [`docs/COMPLETED_WORK.md`](docs/COMPLETED_WORK.md) | **Live progress tracker**: what is done, what is in progress, and what still needs team testing. Always consult this before starting a phase to avoid duplicating completed work. Update it when a task is finished. |

---

## Repository Structure

```
ERAMS_01/
├── docs/
│   ├── ERAMS_TECHNICAL_BUILD_PLAN.md
│   └── COMPLETED_WORK.md
├── .github/workflows/          ← CI/CD (GitHub Actions)
├── lib/                        ← Flutter Dart source
│   ├── main.dart
│   ├── app.dart
│   ├── core/                   ← config, theme, utils
│   ├── models/                 ← Incident, Ambulance, Profile, Hospital
│   ├── services/               ← Supabase CRUD + Realtime wrappers
│   ├── state/                  ← Riverpod providers
│   ├── features/               ← auth, dispatcher, driver, hospital, admin
│   └── widgets/                ← shared UI components
├── supabase/
│   ├── config.toml
│   ├── migrations/             ← numbered SQL files
│   ├── functions/              ← Deno/TypeScript Edge Functions
│   └── seed.sql
├── web/                        ← Flutter web platform files
├── test/
├── pubspec.yaml
├── firebase.json
└── .firebaserc
```

---

## Running the App

```bash
# Development (web)
flutter run -d chrome \
  --dart-define=SUPABASE_URL=<your_url> \
  --dart-define=SUPABASE_ANON_KEY=<your_key>

# Android
flutter run -d <device_id> \
  --dart-define=SUPABASE_URL=<your_url> \
  --dart-define=SUPABASE_ANON_KEY=<your_key>

# Production web build
flutter build web --release \
  --dart-define=SUPABASE_URL=<your_url> \
  --dart-define=SUPABASE_ANON_KEY=<your_key>
firebase deploy --only hosting
```

Environment variables are injected at build time via `--dart-define`. Copy `.env.example` to `.env` (already in `.gitignore`) for local reference, but do not hardcode values in Dart source.

---

## Key Coding Rules

### Flutter / Dart
- Use **Riverpod** for all state. No raw `setState` in screens.
- All Supabase interactions go through **service classes** in `lib/services/`. Screens only interact with Riverpod providers.
- Navigation is **`go_router`** only. Role-based redirects live in `app.dart`.
- Map component: **`flutter_map`** with OpenStreetMap tiles (no Google Maps — avoid API key/billing overhead).
- Offline writes: queue locally with `Hive` or `sqflite`, retry on reconnect. Never silently drop failures.
- No secrets in Dart source. Always `String.fromEnvironment('KEY')`.

### Supabase
- Schema changes → new numbered SQL file in `supabase/migrations/`. Never edit the DB manually without a migration.
- RLS enabled on every table. Role matrix in build plan Section 4.
- Server-side business logic (dispatch, status transitions) → Postgres `SECURITY DEFINER` functions or Deno Edge Functions. Call from Flutter with `supabase.rpc(...)`.
- Realtime subscriptions → expose as `Stream` via a service class; Riverpod `StreamProvider` consumes it.

---

## Phases at a Glance

| Phase | Dates | Deliverable |
|-------|-------|-------------|
| 0 | 17–18 Jun | Flutter project init, Supabase + Firebase connected, CI stubs |
| 1 | 18–20 Jun | Schema, Auth, RLS, seed data, login + role routing |
| 2 | 20–22 Jun | Dispatcher: incident form, live map, dashboard |
| 3 | 22–24 Jun | Auto-dispatch RPC with PostGIS nearest-ambulance query |
| 4 | 24–25 Jun | Driver mobile: dispatch alerts, live GPS, status buttons |
| 5 | 25–26 Jun | Hospital view: incoming patients, ETA, acknowledge |
| 6 | 26–27 Jun | Admin: fleet management, analytics charts |
| 7 | 27–29 Jun | Polish, offline hardening, Firebase + APK deploy |
| 8 | 29–30 Jun | Validation, screenshots, final docs, tag v1.0-demo |

Full task lists: `docs/ERAMS_TECHNICAL_BUILD_PLAN.md` Section 7.

---

## After Completing a Task

1. Mark it `[x]` in `docs/COMPLETED_WORK.md` and add a "Needs Team Testing" note.
2. Commit with message format: `feat(phase-N): <short description>`.
3. Do **not** push directly to `main` unless the CI pipeline passes.

---

## Roles and Data Model

Four roles: **Dispatcher** (web), **Driver** (mobile), **Hospital** (web/mobile), **Admin** (web).

Core tables: `profiles`, `hospitals`, `ambulances`, `incidents`, `incident_events`.

Full ERD with column types and relationships: `docs/ERAMS_TECHNICAL_BUILD_PLAN.md` Section 4.

Seeded demo sites: Healthstone Hospital (Banda, Kampala) and Mulago National Referral Hospital.
