# Public Service Workforce Training Register

Synthetic PostgreSQL 15+ model for course catalogue, scheduled training cohorts, opaque staff tokens and completion evidence. It is not an official government HR integration and must not contain names, staff numbers, appraisals or sensitive employee notes.

## Setup
On a dedicated disposable database, run `migrations/V0001__workforce_training.sql`, then `08_tests.sql`. Review examples in `05_queries.sql`.

## Relationships
`departments` → `training_courses`; courses → `training_cohorts`; cohorts → `enrolments`; enrolments → `enrolment_events`. The lifecycle is request → enrolled → completed, with explicit cancellation/withdrawal.

## Boundary
All records are synthetic. A real deployment requires workforce-policy review, lawful data purpose, access separation, retention schedule, appeals/correction paths and validation by HR data owners. Completion counts are not evidence of workforce performance by themselves.