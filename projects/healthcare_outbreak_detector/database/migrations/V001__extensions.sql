-- ============================================================================
-- Migration: V001__extensions.sql
-- Purpose: Install required PostgreSQL extensions
-- ============================================================================

-- UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Cryptographic functions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Trigram text search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- GiST index support for exclusion constraints
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Create dedicated schema
CREATE SCHEMA IF NOT EXISTS surveillance;

-- Set default search path
ALTER DATABASE CURRENT SET search_path TO surveillance, public;

COMMENT ON SCHEMA surveillance IS 'Healthcare outbreak detection and disease surveillance system';
