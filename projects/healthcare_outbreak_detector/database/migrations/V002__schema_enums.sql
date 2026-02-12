-- ============================================================================
-- Migration: V002__schema_enums.sql
-- Purpose: Define custom ENUM types for the surveillance system
-- ============================================================================

SET search_path TO surveillance, public;

-- Gender classification
CREATE TYPE surveillance.gender_type AS ENUM (
    'male',
    'female',
    'other',
    'unknown'
);
COMMENT ON TYPE surveillance.gender_type IS 'Patient gender classification';

-- Case classification status
CREATE TYPE surveillance.case_status AS ENUM (
    'suspected',
    'probable',
    'confirmed',
    'not_a_case',
    'recovered',
    'deceased'
);
COMMENT ON TYPE surveillance.case_status IS 'Epidemiological case classification per WHO guidelines';

-- Clinical severity
CREATE TYPE surveillance.severity_level AS ENUM (
    'asymptomatic',
    'mild',
    'moderate',
    'severe',
    'critical'
);
COMMENT ON TYPE surveillance.severity_level IS 'Clinical severity classification';

-- Alert priority levels
CREATE TYPE surveillance.alert_level AS ENUM (
    'watch',
    'alert',
    'outbreak',
    'emergency'
);
COMMENT ON TYPE surveillance.alert_level IS 'Alert escalation levels from monitoring to emergency';

-- Alert processing status
CREATE TYPE surveillance.alert_status AS ENUM (
    'active',
    'acknowledged',
    'investigating',
    'resolved',
    'dismissed'
);
COMMENT ON TYPE surveillance.alert_status IS 'Alert lifecycle status';

-- Laboratory specimen types
CREATE TYPE surveillance.specimen_type AS ENUM (
    'blood',
    'serum',
    'plasma',
    'urine',
    'stool',
    'swab_nasal',
    'swab_throat',
    'swab_rectal',
    'csf',
    'sputum',
    'tissue',
    'other'
);
COMMENT ON TYPE surveillance.specimen_type IS 'Laboratory specimen classification';

-- Laboratory test outcomes
CREATE TYPE surveillance.test_result AS ENUM (
    'pending',
    'positive',
    'negative',
    'inconclusive',
    'invalid'
);
COMMENT ON TYPE surveillance.test_result IS 'Laboratory test result classification';

-- Disease transmission modes
CREATE TYPE surveillance.transmission_mode AS ENUM (
    'airborne',
    'droplet',
    'contact',
    'fecal_oral',
    'vector',
    'blood_borne',
    'vertical',
    'zoonotic',
    'unknown'
);
COMMENT ON TYPE surveillance.transmission_mode IS 'Primary mode of disease transmission';

-- Health facility classification
CREATE TYPE surveillance.facility_type AS ENUM (
    'national_referral',
    'regional_referral',
    'district_hospital',
    'health_center_iv',
    'health_center_iii',
    'health_center_ii',
    'clinic',
    'laboratory'
);
COMMENT ON TYPE surveillance.facility_type IS 'Health facility tier classification';
