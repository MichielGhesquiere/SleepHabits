# SleepHabits

You are **Codex** (GPT‑5‑Codex) acting as a coding agent for the SleepHabits app. Build a cross‑platform mobile app and backend that: (1) ingests sleep data from Garmin devices (and platform fallbacks), (2) lets users log healthy/unhealthy bedtime habits via a simple checklist, and (3) analyzes correlations between habits and sleep quality with interpretable models.

Keep responses concise and actionable. Prefer implementing code over lengthy explanations. Ask for clarification only when absolutely necessary—otherwise make reasonable defaults, document them in README.md, and proceed.

---

## 0) Deliverables checklist (Definition of Done)

* **Mobile app** (Flutter) with screens listed below, running on iOS and Android.
* **Backend** (FastAPI + Postgres) with documented REST endpoints and OpenAPI schema.
* **Data pipelines** for Garmin (Health API or device‑side HealthKit/Health Connect fallbacks) + manual import (CSV/JSON ZIP from Garmin export).
* **Daily Cron/Scheduler** that computes stats and updates user dashboards.
* **Habits module** with configurable checklist, reminders, and streaks.
* **Analytics module** producing:

  * Descriptive stats (avg sleep duration, midpoint of sleep, bedtime/waketime histograms, sleep score distribution, variability).
  * Habit adherence metrics (per‑habit completion rate, streaks, rolling adherence).
  * Interpretable models: L1‑regularized logistic/linear regression and (optionally) mixed‑effects models; export coefficients + CIs + feature importances; per‑user partial‑dependence curves.
* **Privacy & Security** basics: consent flows, encrypted at rest/in transit, role‑based access, audit logs, export/delete account (GDPR).
* **CI/CD** with tests, linting, and containerized deploy.

---

## 1) Architecture (high‑level)

**Front end:** Flutter (Dart) + Riverpod state mgmt. Native bridges for Apple HealthKit (iOS) and Android Health Connect.

**Backend:** FastAPI (Python 3.11), Postgres (with TimescaleDB extension for time‑series features), Redis for tasks, Celery/Arq for jobs, S3‑compatible object storage for exports.

**Data ingestion paths (choose best available per user):**

1. **Garmin Health API** (webhooks + OAuth PKCE) → our backend receives JSON for sleep, sleep score, HR, stress, etc.
2. **Device‑side fallback** (no Garmin partner access):

   * iOS: read **HKCategoryTypeIdentifier.sleepAnalysis** + optional score proxies (HRV, resting HR, respiratory rate if available).
   * Android: read **Health Connect SleepSessionRecord** and related data.
3. **Manual import**: user uploads Garmin data export ZIP (or CSV) → parse DI‑Connect‑Wellness files (e.g., sleepData.json) into canonical tables.

**Analytics:** Pandas/Polars + Statsmodels + scikit‑learn; nightly batch jobs + on‑demand analyses.

**Deployment (baseline):** Dockerized. One‑click deploy to Fly.io/Render or Kubernetes. EU region by default.

---

## 2) Data model (canonical schema)

Create SQL migrations for these tables (snake_case). Include indices on `user_id`, `local_date`, and time ranges.

* **users**: id (uuid), auth_provider, email, created_at, tz, consent_health (bool, ts), consent_research (bool, ts).
* **devices**: id, user_id, vendor (garmin|apple|android), model, first_seen_at.
* **sleep_sessions**: id, user_id, start_ts, end_ts, duration_min, main_sleep (bool), timezone, source (garmin|healthkit|healthconnect|manual), score (0–100, nullable), quality_label (good|ok|poor, nullable), data_quality_flags (jsonb).
* **sleep_stages**: id, session_id, stage (awake|light|deep|rem), start_ts, end_ts, duration_min.
* **daily_metrics**: id, user_id, local_date, sleep_duration_min, time_in_bed_min, bedtime_local, wake_time_local, midpoint_local, efficiency, hr_avg, hrv, respiration_rate, body_battery, stress, spo2_avg, naps_min, sleep_score, source.
* **habits_catalog**: id, user_id (nullable for defaults), name, type (healthy|unhealthy), description, default_on (bool), icon.
* **habit_checkins**: id, user_id, habit_id, local_date, value (bool|int|enum), timestamp, notes.
* **reminders**: id, user_id, habit_id, schedule_cron/clock, channel (push|local), active (bool).
* **models**: id, user_id (nullable for global), kind (logistic|linear|mixed), formula, features (jsonb), trained_at, metrics (jsonb), artifact_path.
* **consents_audit**: id, user_id, scope, version, accepted_at, ip.
* **api_tokens**: id, user_id, purpose, created_at, expires_at, scopes.

> Add **views/materialized views** for: weekly and monthly aggregates, rolling 7/14/28‑day features, and adherence summaries.

---

## 3) Mobile app (Flutter) — core screens & flows

1. **Onboarding**

   * Consent (health data, analytics). Region picker (default to device TZ).
   * Connect data source: Garmin OAuth, or enable HealthKit/Health Connect, or choose manual import now/later.
2. **Today**

   * Tonight’s plan checklist (toggle habits: Read 20m, Meditate 10m, No screens 1h before bed, No alcohol, Consistent bedtime, etc.).
   * Quick log (alcohol units, caffeine after 2pm, heavy exercise after 7pm).
   * Reminders shortcuts (set bedtime reminder, wind‑down reminder).
3. **Sleep**

   * Last night: score, duration, stages, bedtime/waketime, efficiency.
   * Trend tabs (7/30/90 days): averages, variability, bedtime heatmap, midpoint histogram.
4. **Habits**

   * Streaks, adherence %, habit editing, custom tags, schedule.
5. **Insights**

   * “Which habits correlate with my sleep?” Simple cards: per‑habit coefficient/odds ratio with CI and caveats; personalized recommendations (e.g., “Your data suggests +18 min sleep when you read ≥15m; keep it up.”).
6. **Settings**

   * Data source connections, export/delete data, privacy, notifications, advanced model options (opt‑in).

> Implement local notifications (Android/iOS). Respect Do Not Disturb and quiet hours. All times in user’s local TZ.

---

## 4) Ingestion & sync

### A) Garmin Health API path

* Implement **OAuth2 PKCE** flow in app → token exchange via backend; store refresh tokens securely.
* Expose webhook endpoints `/webhooks/garmin/sleep` and `/webhooks/garmin/daily` (signed, verified). Persist raw payloads, then transform into canonical tables.
* Backfill: after connect, enqueue historical pulls where API allows; mark completeness per date.

### B) Device‑side fallbacks

* **iOS (HealthKit)**: request read permissions for Sleep Analysis + relevant quantities (HR, HRV, RR if available). Implement background delivery/observers.
* **Android (Health Connect)**: request read permissions for Sleep Sessions + related data; schedule periodic reads; handle permissions changes.

### C) Manual import

* File picker → accept Garmin ZIP/JSON/CSV; parse into canonical tables. Show a validation preview before committing.

> All paths funnel into the same schema. Set `source` fields and keep raw payloads for traceability.

---

## 5) Habit tracking & content

Seed **default habits** (editable per user):

* Healthy: *Read ≥15m*, *Meditate ≥10m*, *No screens in last hour*, *Go to bed between 22:30–23:30*, *Wind‑down routine*, *Keep bedroom cool & dark*, *Morning daylight*.
* Unhealthy: *Alcohol (any)* or *>1 unit*, *Caffeine after 14:00*, *Large meal <3h before bed*, *Intense exercise <3h before bed*, *Screens in last hour*, *Bedtime after 00:00*.

Support **binary** (yes/no) and **scalar** inputs (units of alcohol, minutes read). Allow **custom habits** and tagging (e.g., “sauna”, “eye mask”). Compute adherence % and streaks. Provide smart defaults (suggest habits with strongest user‑specific benefits).

---

## 6) Analytics & modeling

### Features (per day and rolling windows)

* Last night’s: duration, efficiency, stage proportions, score, bedtime/waketime/midpoint, variability (7‑day rolling SD), HR/HRV/stress proxies.
* Habit inputs: binary flags and counts (alcohol units), derived (screen_time>0). Include day‑of‑week, prior sleep debt, and recent training load (if available).

### Targets

* **Regression**: sleep duration (min), sleep score (0–100), efficiency.
* **Classification**: poor sleep (score < threshold or duration < target) vs not.

### Models (interpretable first)

* **Logistic/linear regression with L1** for sparsity; report coefficients, ORs, and CIs.
* **Mixed‑effects** (random intercepts) for population‑level analyses; per‑user models for personalization.
* **Sensitivity**: lagged effects (habit at day t affecting sleep at t), alternate thresholds, and exclusion of confounded nights (illness/travel).
* **Visualization**: coefficient bar charts, partial dependence, rolling correlations.

### Evaluation

* Time‑aware split (last 20–30% as holdout), blocked CV by week.
* Report AUROC/PR for classifiers; MAE/RMSE for regressions; calibration.
* Guard against leakage (e.g., don’t include post‑sleep signals as predictors).

> Export summaries to `/reports/` as Markdown + PNG/CSV for in‑app display.

---

## 7) API (FastAPI) — minimal surface

* `POST /auth/garmin/oauth/callback` — exchange code, persist tokens.
* `POST /webhooks/garmin/sleep` — receive sleep payload.
* `POST /webhooks/garmin/daily` — receive daily summaries & scores.
* `GET /me/summary?range=30d` — return aggregates for dashboard.
* `GET /me/habits` `POST /me/habits` `PATCH /me/habits/:id`
* `POST /me/habits/checkin` — upsert daily check‑ins.
* `GET /me/insights` — latest model outputs.
* `POST /me/import` — upload and ingest ZIP/CSV.
* `DELETE /me` — delete account & data (GDPR).

Auth via JWT (access/refresh). Use rate limiting and request signing for webhooks.

---

## 8) Privacy, security, compliance (baseline)

* Explicit consent screens for health data; link to Privacy Policy; log consent in `consents_audit`.
* Store PHI/health data only under `eu‑west` regions by default; encrypt at rest (Postgres TDE or disk‑level + S3 SSE); TLS in transit.
* Data minimization: collect only needed fields. Implement **Export My Data** and **Delete My Data** in Settings.
* DPIA template in `/compliance/DPIA.md`. Add audit logs (who/when/what) for data operations.

---

## 9) Repo layout

```
sleep-habits/
  app/                    # Flutter app
    lib/
    ios/
    android/
  backend/
    app/main.py          # FastAPI entry
    app/routers/*.py
    app/models/*.py
    app/schemas/*.py
    app/services/*.py
    workers/
    migrations/
  infra/
    docker-compose.yml
    Dockerfile.backend
    Dockerfile.app
    k8s/
  analytics/
    notebooks/
    jobs/
    reports/
  compliance/
    DPIA.md
  AGENT.md               # this file
  README.md
```

---

## 10) Implementation tasks (for Codex)

### Phase 1 — Skeleton & plumbing

* [ ] Scaffold Flutter app with Riverpod + routing; theme; placeholder screens.
* [ ] FastAPI project with `/health` endpoint; Postgres migrations; Alembic set up.
* [ ] Auth (email magic‑link or OAuth via platform provider) and JWT.
* [ ] Create canonical schema (tables above) + seed default habits.
* [ ] Implement manual import pipeline: accept Garmin ZIP/CSV → parse → upsert.
* [ ] Daily job: compute aggregates → `daily_metrics` and streaks.

### Phase 2 — Data integrations

* [ ] iOS: HealthKit bridge (Swift) to read sleep analysis; background delivery; permissions UI.
* [ ] Android: Health Connect plugin/bridge to read sleep sessions; periodic sync.
* [ ] Garmin: OAuth PKCE + webhook receivers; signature verification; test harness.

### Phase 3 — Habits & reminders

* [ ] Habit checklist UI with binary/scalar inputs; custom habit creation.
* [ ] Local notifications (bedtime reminder; wind‑down prompt; post‑sleep summary).
* [ ] Adherence & streaks components.

### Phase 4 — Analytics

* [ ] ETL jobs to build features/targets; guard against leakage.
* [ ] Implement regression/logistic baselines (statsmodels & scikit‑learn) with exportable summaries.
* [ ] Insights API + charts in app.

### Phase 5 — Polish & compliance

* [ ] Settings → Export/Delete data; consent screens; privacy policy link.
* [ ] CI/CD (GitHub Actions), tests, lint, SAST.
* [ ] App Store / Play Store build configs.

---

## 11) UX details (quick specs)

* Use bedtime heatmap (x=clock time 19:00–02:00; y=date) and wake‑time heatmap for pattern visibility.
* Show **most frequent schedule** (mode of bedtime/waketime bins). Show **consistency** (std dev of bedtime/waketime; aim <45 min).
* On insights, speak cautiously (correlation ≠ causation). Provide **per‑user** findings by default.

---

## 12) Config & secrets

* `.env` for DB_URL, JWT_SECRET, STORAGE_BUCKET, PUSH_KEYS (APNs/FCM), Garmin CLIENT_ID/REDIRECT_URI.
* Use Secret Manager in cloud. Never commit secrets.

---

## 13) Testing

* Unit tests for parsers (Garmin ZIP/CSV), HealthKit/Health Connect adapters (mocked), and analytics functions.
* Integration tests for OAuth, webhooks, and data pipelines.
* Golden tests for Flutter widgets; screenshot tests for charts.

---

## 14) Open questions (document as you go)

* Garmin Lifestyle Logging: if exposed via API, should we import these habit tags? Otherwise, keep local habit logging as the source of truth.
* Sleep score availability across sources (HealthKit/Health Connect may not provide a score). Define a derived score proxy (composite) for uniform analytics when native score is missing.

---

## 15) Nice‑to‑have (later)

* Mixed‑effects models for group insights; causal inference (A/B prompts; stepped‑wedge habit trials).
* Personalized recommendations (contextual bandits) with guardrails.
* Wear‑agnostic integration via aggregators (Validic/Thryve/Rook) as enterprise option.
* Web dashboard for exports and research reports.

---

## 16) Acceptance criteria examples

* Importing a Garmin export ZIP with 365 days yields ≥ 365 rows in `daily_metrics` with correct dates and ≥ 90% with complete stage splits where present.
* Enabling HealthKit/Health Connect shows last 14 nights within 60 seconds and continues to sync nightly.
* Logging “2 alcohol units” shows a clear badge on Today and is reflected in the next morning’s Insight feature tables.
* Insights page displays at least one statistically significant coefficient (p<0.05) for any habit with ≥ 30 nights of data, or explains insufficient data.

---

**Go build it.**
