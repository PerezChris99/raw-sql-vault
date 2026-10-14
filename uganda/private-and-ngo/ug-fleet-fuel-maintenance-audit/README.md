# Uganda Fleet Fuel and Maintenance Audit

**Status:** synthetic fleet-management example; PostgreSQL execution unverified.  
**Scope:** vehicles, approved assignments, fuel records, odometer readings, maintenance orders and exception candidates.

## Intended users

Fleet clerks, maintenance managers and aggregate finance/operations reviewers. A real fleet owner must define fuel standards, vehicle classes, odometer units, maintenance intervals, authorised operators and document custody.

## Model and operation

The guarded fuel routine locks the vehicle row, checks the latest odometer reading and requires a unique receipt and idempotency key. Maintenance orders require evidence for approval and completion. The included candidate report flags unusual readings/quantities for investigation; it does not label fraud.

## Setup

Run numbered files on PostgreSQL 15+. The migration uses psql `\\ir` includes. All vehicle, supplier and operator references are synthetic.

## Safeguards

- Restrict vehicle assignment and location data to authorised fleet staff.
- Review anomaly flags alongside route, terrain, vehicle type, fuel tank capacity and recording errors.
- Preserve source receipts and record corrections rather than silently replacing readings.
- Define odometer reset/rollover and electric/hybrid energy handling before extending this model.
- Apply role scoping, maintenance evidence, retention and backup restoration before use.

## Validation

Included assertions cover odometer regression and a valid fuel event. PostgreSQL tests have **not** been executed in this session. Test concurrent fuel entry, correction workflows, real tank capacities and recovery before operational adoption.
