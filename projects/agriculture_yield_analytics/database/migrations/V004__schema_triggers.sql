-- ============================================================================
-- Migration V004: Triggers and Auto-generation
-- Purpose: Automated code generation and audit triggers
-- ============================================================================

SET search_path TO agri, public;

-- ============================================================================
-- AUTO-GENERATED CODES
-- ============================================================================

-- Farmer code generator (FRM-YYYY-NNNNNN)
CREATE OR REPLACE FUNCTION agri.generate_farmer_code()
RETURNS TRIGGER AS $$
DECLARE
    v_seq INTEGER;
BEGIN
    SELECT COALESCE(MAX(CAST(SUBSTRING(farmer_code FROM 10) AS INTEGER)), 0) + 1
    INTO v_seq
    FROM agri.farmers
    WHERE farmer_code LIKE 'FRM-' || EXTRACT(YEAR FROM CURRENT_DATE) || '-%';
    
    NEW.farmer_code := 'FRM-' || EXTRACT(YEAR FROM CURRENT_DATE) || '-' || LPAD(v_seq::TEXT, 6, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_farmer_code_generate
    BEFORE INSERT ON agri.farmers
    FOR EACH ROW
    WHEN (NEW.farmer_code IS NULL)
    EXECUTE FUNCTION agri.generate_farmer_code();

-- Farm code generator (FARM-DIST-NNNN)
CREATE OR REPLACE FUNCTION agri.generate_farm_code()
RETURNS TRIGGER AS $$
DECLARE
    v_dist_code VARCHAR(10);
    v_seq INTEGER;
BEGIN
    SELECT district_code INTO v_dist_code FROM agri.districts WHERE district_id = NEW.district_id;
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(farm_code FROM 15) AS INTEGER)), 0) + 1
    INTO v_seq
    FROM agri.farms
    WHERE farm_code LIKE 'FARM-' || v_dist_code || '-%';
    
    NEW.farm_code := 'FARM-' || v_dist_code || '-' || LPAD(v_seq::TEXT, 4, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_farm_code_generate
    BEFORE INSERT ON agri.farms
    FOR EACH ROW
    WHEN (NEW.farm_code IS NULL)
    EXECUTE FUNCTION agri.generate_farm_code();

-- Harvest code generator (HRV-CROP-SEASON-NNNN)
CREATE OR REPLACE FUNCTION agri.generate_harvest_code()
RETURNS TRIGGER AS $$
DECLARE
    v_crop_code VARCHAR(20);
    v_season_code VARCHAR(15);
    v_seq INTEGER;
BEGIN
    SELECT crop_code INTO v_crop_code FROM agri.crops WHERE crop_id = NEW.crop_id;
    SELECT season_code INTO v_season_code FROM agri.seasons WHERE season_id = NEW.season_id;
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(harvest_code FROM '[0-9]+$') AS INTEGER)), 0) + 1
    INTO v_seq
    FROM agri.harvests
    WHERE crop_id = NEW.crop_id AND season_id = NEW.season_id;
    
    NEW.harvest_code := 'HRV-' || v_crop_code || '-' || v_season_code || '-' || LPAD(v_seq::TEXT, 4, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_harvest_code_generate
    BEFORE INSERT ON agri.harvests
    FOR EACH ROW
    WHEN (NEW.harvest_code IS NULL)
    EXECUTE FUNCTION agri.generate_harvest_code();

-- ============================================================================
-- FARM SIZE CLASSIFICATION
-- ============================================================================

CREATE OR REPLACE FUNCTION agri.classify_farm_size()
RETURNS TRIGGER AS $$
BEGIN
    NEW.size_class := CASE
        WHEN NEW.total_area_hectares < 0.5 THEN 'micro'
        WHEN NEW.total_area_hectares < 2 THEN 'small'
        WHEN NEW.total_area_hectares < 10 THEN 'medium'
        WHEN NEW.total_area_hectares < 50 THEN 'large'
        ELSE 'commercial'
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_farm_size_classify
    BEFORE INSERT OR UPDATE OF total_area_hectares ON agri.farms
    FOR EACH ROW
    EXECUTE FUNCTION agri.classify_farm_size();

-- ============================================================================
-- TIMESTAMP TRIGGERS
-- ============================================================================

CREATE OR REPLACE FUNCTION agri.update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_regions_timestamp
    BEFORE UPDATE ON agri.regions FOR EACH ROW
    EXECUTE FUNCTION agri.update_timestamp();

CREATE TRIGGER trg_districts_timestamp
    BEFORE UPDATE ON agri.districts FOR EACH ROW
    EXECUTE FUNCTION agri.update_timestamp();

CREATE TRIGGER trg_farmers_timestamp
    BEFORE UPDATE ON agri.farmers FOR EACH ROW
    EXECUTE FUNCTION agri.update_timestamp();

CREATE TRIGGER trg_farms_timestamp
    BEFORE UPDATE ON agri.farms FOR EACH ROW
    EXECUTE FUNCTION agri.update_timestamp();

CREATE TRIGGER trg_harvests_timestamp
    BEFORE UPDATE ON agri.harvests FOR EACH ROW
    EXECUTE FUNCTION agri.update_timestamp();

-- ============================================================================
-- AUDIT LOGGING
-- ============================================================================

CREATE OR REPLACE FUNCTION agri.audit_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO agri.audit_log (table_name, record_id, action, old_data)
        VALUES (TG_TABLE_NAME, OLD.farmer_id::TEXT, 'DELETE', to_jsonb(OLD));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO agri.audit_log (table_name, record_id, action, old_data, new_data)
        VALUES (TG_TABLE_NAME, NEW.farmer_id::TEXT, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO agri.audit_log (table_name, record_id, action, new_data)
        VALUES (TG_TABLE_NAME, NEW.farmer_id::TEXT, 'INSERT', to_jsonb(NEW));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_farmers_audit
    AFTER INSERT OR UPDATE OR DELETE ON agri.farmers
    FOR EACH ROW EXECUTE FUNCTION agri.audit_trigger();
