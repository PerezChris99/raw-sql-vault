# Statistical Survey Metadata and Disclosure-Control Register

Synthetic PostgreSQL 15+ package for survey wave metadata, instrument versions, aggregate quality findings and statistical-release review. It intentionally stores no respondent names, addresses, IDs or raw microdata.

## Setup
On a disposable database run `migrations/V0001__survey_metadata_demo.sql`, then `08_tests.sql`; use `05_queries.sql` for monitoring examples.

## Model
`survey_programmes` and `survey_waves` define official statistical work; `instruments` version question sets; `sample_units` use opaque synthetic IDs; `aggregate_cells` stores reportable aggregates with a small-cell suppression status; `release_events` records release transitions.

## Boundary
The suppression threshold in this sample is illustrative, not an approved UBOS disclosure policy. Real work needs a disclosure-risk assessment, output review, instrument governance, weighting/variance methodology, versioned metadata, data-owner access and reproducibility controls.