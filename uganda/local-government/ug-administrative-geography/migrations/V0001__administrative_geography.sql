-- Versioned bootstrap migration for the reference package.
-- Source SQL remains readable in the numbered learning files; run from this directory with psql.
\ir ../01_schema.sql
\ir ../02_seed.sql
\ir ../03_views.sql
\ir ../04_procedures.sql
\ir ../06_security.sql
