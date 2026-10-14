-- Migration V0001: initial local service request demonstration.
-- Engine: PostgreSQL 15+; psql manifest, not a Flyway/Liquibase migration.
-- Synthetic data only. Confirm locality model with a real authority before use.
\set ON_ERROR_STOP on
\ir ../01_schema.sql
\ir ../04_procedures.sql
\ir ../02_seed.sql
\ir ../03_views.sql
\ir ../07_indexes_perf.sql
\ir ../06_security.sql