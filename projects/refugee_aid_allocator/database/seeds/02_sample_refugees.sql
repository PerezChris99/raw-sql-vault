-- ============================================================================
-- Refugee Aid Allocator - Sample Refugee Data
-- PostgreSQL 14+
-- Seed: Generate sample households, refugees, and needs
-- ============================================================================

-- ============================================================================
-- Sample Households (Focus on Bidibidi camp)
-- ============================================================================

-- Get Bidibidi camp ID
DO $$
DECLARE
    v_bidibidi_id INT;
    v_palorinya_id INT;
    v_imvepi_id INT;
BEGIN
    SELECT camp_id INTO v_bidibidi_id FROM camps WHERE camp_name = 'Bidibidi';
    SELECT camp_id INTO v_palorinya_id FROM camps WHERE camp_name = 'Palorinya';
    SELECT camp_id INTO v_imvepi_id FROM camps WHERE camp_name = 'Imvepi';
    
    -- Insert sample households for Bidibidi
    INSERT INTO households (camp_id, household_code, head_name, size, shelter_type, has_special_needs, special_needs_desc, registration_date) VALUES
    (v_bidibidi_id, 'BID-HH-001', 'Akello Sarah', 6, 'semi-permanent', TRUE, 'Disabled family member', '2023-01-15'),
    (v_bidibidi_id, 'BID-HH-002', 'Okello James', 4, 'tent', FALSE, NULL, '2023-02-20'),
    (v_bidibidi_id, 'BID-HH-003', 'Auma Grace', 3, 'tent', TRUE, 'Single mother with infant', '2023-03-10'),
    (v_bidibidi_id, 'BID-HH-004', 'Opiyo Peter', 7, 'semi-permanent', TRUE, 'Elderly grandparents', '2022-11-05'),
    (v_bidibidi_id, 'BID-HH-005', 'Atim Rose', 2, 'transit', TRUE, 'Unaccompanied children', '2024-01-01'),
    (v_bidibidi_id, 'BID-HH-006', 'Kato John', 5, 'semi-permanent', FALSE, NULL, '2023-06-15'),
    (v_bidibidi_id, 'BID-HH-007', 'Nakato Mary', 4, 'tent', TRUE, 'Pregnant woman', '2023-09-01'),
    (v_bidibidi_id, 'BID-HH-008', 'Waswa Emmanuel', 8, 'permanent', FALSE, NULL, '2021-05-20'),
    (v_bidibidi_id, 'BID-HH-009', 'Nambi Joyce', 1, 'tent', TRUE, 'Elderly alone, chronic illness', '2024-02-01'),
    (v_bidibidi_id, 'BID-HH-010', 'Mubiru Charles', 6, 'semi-permanent', TRUE, 'Disabled child', '2023-04-10'),
    
    -- Palorinya households
    (v_palorinya_id, 'PAL-HH-001', 'Adong Betty', 5, 'tent', TRUE, 'Nursing mother', '2023-05-10'),
    (v_palorinya_id, 'PAL-HH-002', 'Ochen David', 3, 'semi-permanent', FALSE, NULL, '2023-07-20'),
    (v_palorinya_id, 'PAL-HH-003', 'Laker Agnes', 4, 'tent', TRUE, 'Single parent', '2023-08-15'),
    (v_palorinya_id, 'PAL-HH-004', 'Otim Simon', 6, 'permanent', FALSE, NULL, '2022-09-01'),
    (v_palorinya_id, 'PAL-HH-005', 'Acen Patricia', 2, 'tent', TRUE, 'Unaccompanied minor sibling', '2024-01-15'),
    
    -- Imvepi households
    (v_imvepi_id, 'IMV-HH-001', 'Okwera Paul', 4, 'semi-permanent', FALSE, NULL, '2023-03-01'),
    (v_imvepi_id, 'IMV-HH-002', 'Achola Helen', 5, 'tent', TRUE, 'Husband disabled', '2023-06-01'),
    (v_imvepi_id, 'IMV-HH-003', 'Olweny Mark', 7, 'permanent', TRUE, 'Multiple elderly', '2022-12-01'),
    (v_imvepi_id, 'IMV-HH-004', 'Apio Jennifer', 3, 'tent', TRUE, 'Pregnant, first-time mother', '2024-02-10'),
    (v_imvepi_id, 'IMV-HH-005', 'Odongo Michael', 4, 'transit', FALSE, NULL, '2024-03-01')
    ON CONFLICT (household_code) DO NOTHING;
END $$;

-- ============================================================================
-- Sample Refugees
-- ============================================================================

-- Insert refugees for each household
INSERT INTO refugees (household_id, unhcr_id, first_name, last_name, date_of_birth, gender, nationality, arrival_date, 
    is_head_of_household, vulnerability_score, is_unaccompanied_minor, is_elderly, is_pregnant_nursing, 
    is_disabled, is_single_parent, has_chronic_illness)
SELECT 
    h.household_id,
    'UGA-' || h.household_code || '-' || LPAD(seq::TEXT, 2, '0') AS unhcr_id,
    CASE MOD(seq, 10)
        WHEN 1 THEN 'Sarah' WHEN 2 THEN 'James' WHEN 3 THEN 'Grace'
        WHEN 4 THEN 'Peter' WHEN 5 THEN 'Rose' WHEN 6 THEN 'John'
        WHEN 7 THEN 'Mary' WHEN 8 THEN 'Emmanuel' WHEN 9 THEN 'Joyce'
        ELSE 'Charles'
    END AS first_name,
    CASE MOD(seq, 8)
        WHEN 1 THEN 'Akello' WHEN 2 THEN 'Okello' WHEN 3 THEN 'Auma'
        WHEN 4 THEN 'Opiyo' WHEN 5 THEN 'Atim' WHEN 6 THEN 'Kato'
        WHEN 7 THEN 'Nakato' ELSE 'Waswa'
    END AS last_name,
    CURRENT_DATE - ((RANDOM() * 25000 + 365)::INT) AS date_of_birth,
    CASE WHEN RANDOM() > 0.5 THEN 'male' ELSE 'female' END AS gender,
    CASE MOD(seq, 3)
        WHEN 0 THEN 'South Sudan' WHEN 1 THEN 'DRC' ELSE 'Burundi'
    END AS nationality,
    h.registration_date + (RANDOM() * 30)::INT AS arrival_date,
    (seq = 1) AS is_head_of_household,
    -- Vulnerability score calculation
    (CASE WHEN h.has_special_needs THEN 25 ELSE 0 END +
     CASE WHEN h.size >= 6 THEN 15 ELSE 0 END +
     (RANDOM() * 40)::INT) AS vulnerability_score,
    -- Vulnerability flags (randomized but realistic)
    (h.special_needs_desc ILIKE '%unaccompanied%' AND RANDOM() > 0.5) AS is_unaccompanied_minor,
    (h.special_needs_desc ILIKE '%elderly%' AND RANDOM() > 0.7) AS is_elderly,
    (h.special_needs_desc ILIKE '%pregnant%' OR h.special_needs_desc ILIKE '%nursing%') AS is_pregnant_nursing,
    (h.special_needs_desc ILIKE '%disabled%') AS is_disabled,
    (h.special_needs_desc ILIKE '%single%') AS is_single_parent,
    (h.special_needs_desc ILIKE '%illness%' OR RANDOM() > 0.85) AS has_chronic_illness
FROM households h
CROSS JOIN GENERATE_SERIES(1, h.size) AS seq
ON CONFLICT (unhcr_id) DO NOTHING;

-- Update vulnerability scores based on actual flags
UPDATE refugees SET vulnerability_score = 
    CASE WHEN is_unaccompanied_minor THEN 30 ELSE 0 END +
    CASE WHEN is_elderly THEN 20 ELSE 0 END +
    CASE WHEN is_pregnant_nursing THEN 25 ELSE 0 END +
    CASE WHEN is_disabled THEN 25 ELSE 0 END +
    CASE WHEN is_single_parent THEN 15 ELSE 0 END +
    CASE WHEN has_chronic_illness THEN 20 ELSE 0 END +
    (RANDOM() * 10)::INT;

-- ============================================================================
-- Sample Needs (with scoring)
-- ============================================================================

-- Create needs for refugees (randomized but realistic)
INSERT INTO needs (refugee_id, category_id, urgency_id, quantity_needed, assessed_date, assessed_by, status)
SELECT 
    r.refugee_id,
    ac.category_id,
    ul.urgency_id,
    CASE 
        WHEN ac.category_code = 'FOOD' THEN 10.0
        WHEN ac.category_code = 'WATER' THEN 20.0
        WHEN ac.category_code = 'MED' THEN 1.0
        WHEN ac.category_code = 'BLNK' THEN 2.0
        WHEN ac.category_code = 'HYG' THEN 1.0
        WHEN ac.category_code = 'BABY' AND r.is_pregnant_nursing THEN 2.0
        ELSE 1.0
    END AS quantity_needed,
    CURRENT_DATE - (RANDOM() * 30)::INT AS assessed_date,
    'Field Worker ' || (RANDOM() * 10 + 1)::INT::TEXT AS assessed_by,
    'pending' AS status
FROM refugees r
CROSS JOIN LATERAL (
    SELECT category_id, category_code, priority_weight
    FROM aid_categories 
    WHERE RANDOM() > 0.6  -- Random selection of categories needed
    ORDER BY RANDOM()
    LIMIT 3
) ac
CROSS JOIN LATERAL (
    SELECT urgency_id, urgency_score
    FROM urgency_levels
    ORDER BY RANDOM()
    LIMIT 1
) ul
WHERE r.status = 'active'
ON CONFLICT (refugee_id, category_id, status) DO NOTHING;

-- ============================================================================
-- Calculate Need Scores
-- ============================================================================

-- Update need scores using the formula:
-- Need Score = (Urgency × 0.35) + (Vulnerability × 0.25) + 
--              (Household Size × 0.20) + (Days Waiting × 0.15) + 
--              (Category Priority × 0.05)

UPDATE needs n SET need_score = (
    SELECT 
        (ul.urgency_score * 0.35) +
        (r.vulnerability_score * 0.25) +
        (LEAST(h.size * 10, 100) * 0.20) +
        (LEAST(EXTRACT(DAY FROM NOW() - n.assessed_date) * 3, 100) * 0.15) +
        (ac.priority_weight * 100 * 0.05)
    FROM refugees r
    JOIN households h ON r.household_id = h.household_id
    JOIN urgency_levels ul ON n.urgency_id = ul.urgency_id
    JOIN aid_categories ac ON n.category_id = ac.category_id
    WHERE r.refugee_id = n.refugee_id
);

-- ============================================================================
-- Summary
-- ============================================================================

SELECT 'Sample data loaded successfully' AS status;
SELECT COUNT(*) AS household_count FROM households;
SELECT COUNT(*) AS refugee_count FROM refugees;
SELECT COUNT(*) AS needs_count FROM needs;

-- Show distribution by camp
SELECT 
    c.camp_name,
    COUNT(DISTINCT h.household_id) AS households,
    COUNT(DISTINCT r.refugee_id) AS refugees,
    COUNT(n.need_id) AS pending_needs
FROM camps c
LEFT JOIN households h ON c.camp_id = h.camp_id
LEFT JOIN refugees r ON h.household_id = r.household_id
LEFT JOIN needs n ON r.refugee_id = n.refugee_id AND n.status = 'pending'
GROUP BY c.camp_name
ORDER BY refugees DESC;
