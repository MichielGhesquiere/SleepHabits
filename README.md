# SleepHabits Proof of Concept

This repository contains a vertical slice of the SleepHabits mobile app and FastAPI backend. The goal is a working prototype that lets a user:

- sign in with an email address (magic-link style, simulated locally),
- connect a Garmin account (stubbed with sample payloads),
- view basic sleep statistics, and
- log healthy/unhealthy bedtime habits with a checklist UI.

The code is organised per the product spec: a Flutter client in `app/`, a FastAPI backend in `backend/`, infra stubs, analytics placeholders, and compliance docs.

## Backend

### Quick start

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
uvicorn app.main:app --reload --port 8000
```

The API exposes:

- `POST /auth/login` — accepts `{ "email": "user@example.com" }` and returns an access token.
- `GET /me/summary` — returns the current user’s sleep snapshot and habit compliance stats.
- `POST /me/garmin/connect` — simulates a Garmin OAuth connect and loads sample sleep data.
- `POST /me/garmin/pull` — re-syncs the sample sleep dataset.
- `GET /me/habits` — returns the configured habits plus today’s check-ins.
- `POST /me/habits/checkin` — records a bedtime habit entry for today (or an optional `local_date`).

Tokens are in-memory only (`Authorization: Bearer <token>`). Garmin integration is stubbed: connecting loads `backend/app/data/sample_garmin_sleep.json` into a temporary store.

### Tests

```bash
cd backend
pytest
```

## Mobile app (Flutter)

The Flutter source lives under `app/` and uses Riverpod for state management.

Key screens:

- **AuthScreen** — simple email capture and sign-in.
- **Dashboard** — connect Garmin, view last night + 7-day averages, and check off tonight’s habits.
- **SleepScreen** — pull latest sample sleep data and view stage breakdowns.
- **HabitsScreen** — manage the healthy/unhealthy checklist.

Configure the backend base URL via a compile-time environment override, or use the default `http://localhost:8000`:

```bash
flutter run --dart-define=SLEEP_HABITS_API_BASE=http://10.0.2.2:8000
```

A lightweight widget test lives in `app/test/widget_test.dart`.

## Project layout

```
sleep-habits/
  app/                # Flutter client
  backend/            # FastAPI app + tests
  infra/              # Deployment stubs (Docker, k8s placeholders)
  analytics/          # Future analytics notebooks/jobs
  compliance/         # DPIA & policy docs
  README.md
  AGENTS.md
```

## Defaults & assumptions

- Authentication uses in-memory tokens; a real build would swap in JWT/refresh tokens and persistent storage.
- Sample Garmin data powers the “connect” and “pull” flows — replace with live Health API / webhooks later.
- Daily aggregates and analytics jobs are placeholders; add proper ETL + model training once real data flows.
- Notifications, reminders, and HealthKit/Health Connect bridges are not yet implemented.

Documented open questions:

- Whether to ingest Garmin Lifestyle Logging once production credentials are issued.
- How to derive a sleep score proxy for platforms that do not expose a first-party score.

## Next steps

1. Replace the stubbed Garmin service with OAuth + webhook ingestion.
2. Back the in-memory store with Postgres (Timescale) and add Alembic migrations for the canonical schema.
3. Flesh out the analytics pipelines, nightly scheduler, and insights surface.
4. Implement secure auth (JWT + refresh tokens), consent logging, and privacy tooling (export/delete).
5. Add CI (GitHub Actions) with linting, typed API schemas, and device builds.
