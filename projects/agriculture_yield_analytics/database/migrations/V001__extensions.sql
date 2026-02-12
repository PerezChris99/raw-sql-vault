-- ============================================================================
-- Migration V001: PostgreSQL Extensions
-- Purpose: Enable required database extensions
-- ============================================================================

-- UUID generation for primary keys
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Cryptographic functions for hashing
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Trigram matching for fuzzy text search
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- GiST index support for range queries
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- Create dedicated schema
CREATE SCHEMA IF NOT EXISTS agri;
COMMENT ON SCHEMA agri IS 'Agriculture Yield Analytics - Production Schema';

-- Migration tracking table
CREATE TABLE IF NOT EXISTS agri.schema_migrations (
    version VARCHAR(20) PRIMARY KEY,
    filename VARCHAR(255) NOT NULL,
    applied_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
