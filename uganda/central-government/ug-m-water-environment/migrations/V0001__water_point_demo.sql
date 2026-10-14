-- Versioned psql bootstrap; not a Flyway/Liquibase migration. PostgreSQL 15+.
\set ON_ERROR_STOP on
\ir ../01_schema.sql
\ir ../04_procedures.sql
\ir ../02_seed.sql
\ir ../03_views.sql
\ir ../07_indexes_perf.sql
\ir ../06_security.sql