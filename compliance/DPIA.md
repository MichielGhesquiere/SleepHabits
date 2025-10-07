# SleepHabits Data Protection Impact Assessment (Draft)

**Status:** Draft for prototype. Update once production data flows.

## 1. Scope

- Garmin sleep data, device fallbacks, and manually uploaded exports
- Habit check-ins and reminder preferences

## 2. Stakeholders

- Data Subject: SleepHabits end users
- Data Controller: SleepHabits Ltd. (TBD)
- Data Processors: Cloud hosting providers (TBD)

## 3. Processing Activities

| Activity | Purpose | Storage | Retention |
| --- | --- | --- | --- |
| Sleep ingestion | Provide nightly feedback and insights | Postgres/Timescale | 2 years (configurable) |
| Habit logging | Behaviour tracking & model inputs | Postgres | 2 years |
| Analytics jobs | Generate personalised recommendations | Object storage (S3-compatible) | Until studies end |

## 4. Risks & mitigations

- **Unauthorized access to health data** —> enforce RBAC, audit logs, encryption at rest/in transit.
- **Cross-region transfers** —> default EU region, document sub-processors.
- **Model explainability** —> ship interpretable models and expose summaries to users.

## 5. Outstanding actions

- Finalize legal entity & DPA
- Add consent versioning UI copies
- Complete vendor reviews before launch
