# OPM Programme Action Register (Synthetic Demonstrator)

## Problem and boundaries

Illustrates how a programme coordination office can track multi-agency actions, accountable offices, target dates, blockers and a chronological status history. This is an educational demonstrator, not an official OPM system and not integrated with any government service. It must not store classified, security-sensitive or real citizen case data.

## Stakeholders

- Programme coordination staff: view cross-office actions and overdue work.
- Responsible departments: update actions they are authorised to manage.
- Review/audit staff: inspect recorded state transitions.
- Database operator: apply migrations and control grants.

## Entities and relationships

- departments 1-to-many programme_actions as sponsor and responsible owner.
- programme_actions 1-to-many action_events.
- action_events capture old/new status, actor reference, time and a brief note.

ERD (text): departments(department_id) <- programme_actions(sponsor_department_id, owner_department_id) -> action_events(action_id).

## Setup (PostgreSQL 15+)

Run from repository root against a dedicated development database, in order:
1. 01_schema.sql
2. 04_procedures.sql
3. 02_seed.sql
4. 03_views.sql
5. 07_indexes_perf.sql
6. 06_security.sql
7. Run the read-only examples in 05_queries.sql.
8. Run 08_tests.sql to assert the expected behavior.

Seed data uses fictional offices and action records. Scripts do not connect to any government network.

## Key invariants

- Status changes go through fn_transition_action, which locks the row and writes an event in the same transaction.
- Completed/cancelled actions are terminal.
- Due dates and reporting timestamps have explicit semantics.
- A status event is not proof that the programme outcome itself has occurred.

## Operations and limitations

- Run EXPLAIN (ANALYZE, BUFFERS) only on a safe test system with representative synthetic data.
- Production use requires a validated mandate/data owner, access-control review, backup/restore plan, retention schedule, operational ownership and user acceptance.
- Roles created by 06_security.sql are NOLOGIN demonstration roles. A DBA must assign authentication and deployment-specific grants.
- No real identity information or attachments are captured in the sample schema.