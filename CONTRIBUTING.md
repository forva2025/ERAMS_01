# Contributing to ERAMS

This document covers how to work on the ERAMS codebase during the active build window (17–30 June 2026).

---

## Before You Start

1. Read [`docs/ERAMS_TECHNICAL_BUILD_PLAN.md`](docs/ERAMS_TECHNICAL_BUILD_PLAN.md) — it is the canonical reference for architecture, data model, and phase tasks.
2. Check [`docs/COMPLETED_WORK.md`](docs/COMPLETED_WORK.md) — confirm what's already done before starting work.
3. Check out a feature branch (see Branching below).

---

## Branching Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable, deployable code. CI must pass before merging. |
| `phase-N/description` | One branch per build phase or significant feature (e.g. `phase-1/auth-rls`, `phase-3/dispatch-rpc`). |

```bash
git checkout -b phase-2/dispatcher-map
```

Merge back to `main` via a Pull Request once the phase deliverable is working and self-tested.

---

## Commit Message Format

```
type(scope): short description

Optional longer explanation if needed.
```

**Types:** `feat`, `fix`, `chore`, `docs`, `test`, `refactor`  
**Scope:** phase number or module name (e.g. `phase-1`, `auth`, `dispatcher`, `supabase`)

Examples:
```
feat(phase-1): add RLS policies for dispatcher and driver roles
fix(dispatcher): correct ambulance marker colour not updating on status change
chore(supabase): add GIST index on ambulances.current_location
docs(phase-2): mark incident form task complete in COMPLETED_WORK.md
```

---

## Updating Progress

When you finish a task:

1. Open `docs/COMPLETED_WORK.md`.
2. Change `[ ]` to `[x]` for the completed task.
3. Add a short note under "Needs Team Testing" if the team needs to validate something manually.
4. Commit the update alongside the code change.

When the team has tested and confirmed a task:

- Change `[x]` to `[✓]`.

---

## Code Style

- Follow the [Dart style guide](https://dart.dev/guides/language/effective-dart/style) and `analysis_options.yaml`.
- Run `flutter analyze` before committing — no warnings should be introduced.
- Run `flutter test` to ensure existing tests pass.
- No secrets or API keys in source files. Use `--dart-define` (see `.env.example`).

---

## Database Changes

- Every schema change must have a corresponding SQL migration file in `supabase/migrations/`.
- Name migrations sequentially: `001_initial_schema.sql`, `002_add_rls_policies.sql`, etc.
- Never edit the live Supabase database without a migration file.
- RLS must be enabled on every table before merging to `main`.

---

## Pull Request Checklist

Before opening a PR:

- [ ] `flutter analyze` passes with no new warnings
- [ ] `flutter test` passes
- [ ] `COMPLETED_WORK.md` updated for finished tasks
- [ ] No hardcoded secrets or credentials
- [ ] New schema changes have a migration file in `supabase/migrations/`
- [ ] PR description states what was built and references the phase

---

## Questions

Contact the team directly or leave a comment on the relevant GitHub issue.
