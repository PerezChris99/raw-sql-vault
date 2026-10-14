# Diplomatic Engagement and Commitment Tracker

Synthetic PostgreSQL 15+ example for official engagement metadata, meeting outcomes and follow-up commitments. It contains no diplomatic cables, classified positions, personal passport details or operationally sensitive travel plans.

## Setup
In a disposable database run `migrations/V0001__diplomatic_engagement_demo.sql`, then `08_tests.sql`; use `05_queries.sql` for reporting.

## Model
`missions` reference fictional diplomatic posts; `engagements` record approved metadata about an event; `commitments` track assigned actions; `commitment_events` preserves state transitions.

## Boundaries
All fixtures are synthetic. A production deployment needs an information-classification policy, clearance-based access, retention/legal hold controls, source-document permissions and human review. This package does not model classified diplomacy or imply official ministry endorsement.