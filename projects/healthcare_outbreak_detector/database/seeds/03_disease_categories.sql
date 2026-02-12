-- ============================================================================
-- Seed: 03_disease_categories.sql
-- Purpose: Disease classification categories
-- ============================================================================

SET search_path TO surveillance, public;

INSERT INTO surveillance.disease_categories (category_code, category_name, description) VALUES
    ('VPD', 'Vaccine-Preventable Diseases', 'Diseases preventable through immunization'),
    ('AWD', 'Acute Watery Diarrhea', 'Diarrheal diseases including cholera'),
    ('VHF', 'Viral Hemorrhagic Fevers', 'Fevers with hemorrhagic manifestations'),
    ('VBD', 'Vector-Borne Diseases', 'Diseases transmitted by vectors like mosquitoes'),
    ('ZOO', 'Zoonotic Diseases', 'Diseases transmitted from animals to humans'),
    ('ARI', 'Acute Respiratory Infections', 'Respiratory tract infections'),
    ('NTD', 'Neglected Tropical Diseases', 'WHO-defined NTDs'),
    ('STI', 'Sexually Transmitted Infections', 'STIs and HIV/AIDS'),
    ('OTH', 'Other Notifiable', 'Other diseases requiring surveillance'),
    ('EPD', 'Epidemic-Prone Diseases', 'Diseases with outbreak potential')
ON CONFLICT (category_code) DO UPDATE SET
    category_name = EXCLUDED.category_name,
    description = EXCLUDED.description;
