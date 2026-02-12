-- ============================================================================
-- Seed: 01_regions.sql
-- Purpose: Administrative regions (Uganda example)
-- ============================================================================

SET search_path TO surveillance, public;

INSERT INTO surveillance.regions (region_code, region_name, population) VALUES
    ('CEN', 'Central', 9529227),
    ('EAS', 'Eastern', 9042422),
    ('NOR', 'Northern', 7188139),
    ('WES', 'Western', 8874862)
ON CONFLICT (region_code) DO UPDATE SET
    region_name = EXCLUDED.region_name,
    population = EXCLUDED.population;
