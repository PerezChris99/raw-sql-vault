# Social Programme Milestone and Referral Tracker

Synthetic PostgreSQL 15+ model for programme enrolment tokens, service milestones and referral follow-up. It intentionally excludes real beneficiary names, contact details, case narratives, disability/health details, refugee status and exact household locations.

## Setup
On a disposable database run `migrations/V0001__social_programme_demo.sql`, then `08_tests.sql`. Use `05_queries.sql` for aggregate reports.

## Model
`programmes` describe service offerings; `enrolments` use opaque test tokens; `service_milestones` track agreed administrative steps; `milestone_events` preserves transitions.

## Boundary
A production programme needs lawful purpose, data-owner review, clear eligibility authority, correction/appeal process, safeguarding, access controls, retention/deletion policy and independent human review. This database must not be used to automate high-impact eligibility decisions.