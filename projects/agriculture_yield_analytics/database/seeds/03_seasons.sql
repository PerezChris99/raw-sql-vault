-- ============================================================================
-- Seed Data: Seasons
-- Purpose: Agricultural season definitions
-- ============================================================================

SET search_path TO agri, public;

-- ============================================================================
-- SEASONS (2020-2025)
-- ============================================================================

INSERT INTO agri.seasons (season_code, season_name, season_type, year, start_date, end_date, expected_rainfall_mm)
VALUES
    -- 2020
    ('2020A', 'Season A 2020', 'season_a', 2020, '2020-03-01', '2020-06-30', 450),
    ('2020B', 'Season B 2020', 'season_b', 2020, '2020-09-01', '2020-12-31', 380),
    
    -- 2021
    ('2021A', 'Season A 2021', 'season_a', 2021, '2021-03-01', '2021-06-30', 480),
    ('2021B', 'Season B 2021', 'season_b', 2021, '2021-09-01', '2021-12-31', 420),
    
    -- 2022
    ('2022A', 'Season A 2022', 'season_a', 2022, '2022-03-01', '2022-06-30', 460),
    ('2022B', 'Season B 2022', 'season_b', 2022, '2022-09-01', '2022-12-31', 400),
    
    -- 2023
    ('2023A', 'Season A 2023', 'season_a', 2023, '2023-03-01', '2023-06-30', 470),
    ('2023B', 'Season B 2023', 'season_b', 2023, '2023-09-01', '2023-12-31', 410),
    
    -- 2024
    ('2024A', 'Season A 2024', 'season_a', 2024, '2024-03-01', '2024-06-30', 480),
    ('2024B', 'Season B 2024', 'season_b', 2024, '2024-09-01', '2024-12-31', 430),
    
    -- 2025
    ('2025A', 'Season A 2025', 'season_a', 2025, '2025-03-01', '2025-06-30', 490),
    ('2025B', 'Season B 2025', 'season_b', 2025, '2025-09-01', '2025-12-31', 440)
ON CONFLICT (season_code) DO UPDATE SET
    expected_rainfall_mm = EXCLUDED.expected_rainfall_mm;

-- Set current season
UPDATE agri.seasons SET is_current = FALSE;
UPDATE agri.seasons SET is_current = TRUE 
WHERE start_date <= CURRENT_DATE AND end_date >= CURRENT_DATE;
