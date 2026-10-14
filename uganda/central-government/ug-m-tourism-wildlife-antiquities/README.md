# Tourism Establishment and Permit Tracker

Synthetic PostgreSQL 15+ example for tourism-establishment reference metadata, permit expiry review, periodic inspections and corrective-action follow-up. It is not an official permit registry and contains no traveller, passport, booking or precise sensitive wildlife-location data.

## Setup
On a disposable database run `migrations/V0001__tourism_permit_demo.sql`, then `08_tests.sql`. Run reports in `05_queries.sql`.

## Model
`establishments` uses invented operator references; `permits` models a permit lifecycle; `inspections` captures a dated review result; `actions` tracks next steps and event history.

## Boundary
All data are synthetic. Real use requires an approved licensing taxonomy, current mandate, legal review, evidence retention, privacy controls and human review. An overdue permit/inspection flag is not a legal finding.