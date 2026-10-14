-- Migration V0001: initial staging/warehouse/feature-store demonstration.
-- Engine: PostgreSQL 15+; psql manifest, not a Flyway/Liquibase migration.
-- Synthetic data only; feature-time cutoff is part of the data contract.
\set ON_ERROR_STOP on
\ir ../01_schema.sql
\ir ../04_procedures.sql
\ir ../02_seed.sql
\ir ../03_views.sql
\ir ../07_indexes_perf.sql
\ir ../06_security.sql