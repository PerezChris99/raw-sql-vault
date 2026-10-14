-- Migration V0001: bootstrap the isolated vault_demo correctness examples.
-- Engine: PostgreSQL 15+ with PostGIS.
-- Runner: psql only; this manifest uses psql \ir. Translate into the target
-- migration tool's source files for deployment. Never run on production data.
\set ON_ERROR_STOP on
\ir ../fixes/00_demo_schema.sql
\ir ../fixes/01_sales_filter_consistency.sql
\ir ../fixes/02_date_range_overlap.sql
\ir ../fixes/03_null_safe_scoring.sql
\ir ../fixes/04_rolling_window.sql
\ir ../fixes/05_spatial_dedup.sql
\ir ../fixes/06_batch_insert_safety.sql
\ir ../patterns/keyset_pagination.sql
\ir ../patterns/rls_tenant_isolation.sql
\ir ../patterns/audit_trigger.sql
\ir ../patterns/soft_delete.sql
\ir ../patterns/idempotent_upsert.sql