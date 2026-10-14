# Local Government Service Request Tracker

## Problem statement

This synthetic demonstrator tracks reports about drainage, road defects, waste collection and public assets from receipt through triage, work and resolution. It is designed to illustrate a workflow, not to connect to a real district or KCCA system.

## Users

- Intake team: register and categorise reports.
- Service desk: triage and assign priority.
- Field operations: report blocked/in-progress/resolved states.
- Supervisors: inspect overdue requests and aggregate service levels.
- Auditors: inspect request status history.

## ERD

localities 1-to-many service_requests; localities may refer to a parent locality; service_requests 1-to-many request_events. Use effective-dated official boundary reference data in any real implementation.

## Setup

On a dedicated PostgreSQL 15+ test database, from repository root:
1. 01_schema.sql
2. 04_procedures.sql
3. 02_seed.sql
4. 03_views.sql
5. 07_indexes_perf.sql
6. 06_security.sql
7. Read/execute 05_queries.sql
8. Execute 08_tests.sql

Fixtures are synthetic and avoid names, phone numbers, precise home addresses and sensitive narratives. Reporter references are optional opaque tokens only.

## Rules

Transitions are controlled by fn_transition_request and event inserts occur in the same transaction. Resolved requests require a resolved timestamp. A queue flag or overdue report is not a formal finding about an employee or contractor.

## Deployment boundary

Before real use, validate the responsible local authority, current administrative codes, intake channel, public records obligations, privacy and retention requirements, audit access, escalation path, offline/manual workflow and operational owner. Do not publish unredacted reporter narratives.