-- Fictional survey metadata; stable codes make seeds rerunnable.
INSERT INTO ubos_demo.survey_programmes(programme_code,title,domain,owner_ref) VALUES
('DEMO-SURVEY-PRICE','Synthetic Consumer Price Sample','prices','demo-stats-owner'),
('DEMO-SURVEY-AGRI','Synthetic Crop Area Survey','agriculture','demo-stats-owner')
ON CONFLICT(programme_code) DO NOTHING;
INSERT INTO ubos_demo.survey_waves(wave_ref,programme_id,reference_period_start,reference_period_end,fieldwork_start,fieldwork_end,status)
SELECT v.ref,p.programme_id,v.ps,v.pe,v.fs,v.fe,v.status FROM (VALUES
('DEMO-WAVE-PRICE-2026-09','DEMO-SURVEY-PRICE',DATE '2026-09-01',DATE '2026-09-30',DATE '2026-09-01',DATE '2026-09-25','quality_review'),
('DEMO-WAVE-AGRI-2026B','DEMO-SURVEY-AGRI',DATE '2026-08-01',DATE '2026-12-31',DATE '2026-08-15',NULL,'fieldwork')
) v(ref,prog,ps,pe,fs,fe,status) JOIN ubos_demo.survey_programmes p ON p.programme_code=v.prog
ON CONFLICT(wave_ref) DO NOTHING;
INSERT INTO ubos_demo.instruments(instrument_code,version_no,title,status,approved_at) VALUES
('DEMO-PRICE-INSTRUMENT',1,'Synthetic price collection form','approved',TIMESTAMPTZ '2026-08-01 00:00+00'),
('DEMO-AGRI-INSTRUMENT',2,'Synthetic crop observation form','draft',NULL)
ON CONFLICT(instrument_code,version_no) DO NOTHING;
INSERT INTO ubos_demo.sample_units(wave_id,sample_token,area_code,mode,response_status,quality_state)
SELECT w.wave_id,v.token,v.area,v.mode,v.response,v.quality FROM (VALUES
('DEMO-WAVE-PRICE-2026-09','SAMPLE-TOKEN-A','DEMO-AREA-A','observation','complete','passed'),
('DEMO-WAVE-PRICE-2026-09','SAMPLE-TOKEN-B','DEMO-AREA-B','observation','partial','flagged'),
('DEMO-WAVE-AGRI-2026B','SAMPLE-TOKEN-C','DEMO-AREA-A','interview','pending','unreviewed')
) v(wave,token,area,mode,response,quality) JOIN ubos_demo.survey_waves w ON w.wave_ref=v.wave
ON CONFLICT(wave_id,sample_token) DO NOTHING;
INSERT INTO ubos_demo.aggregate_cells(wave_id,table_ref,area_code,metric_code,cell_count,value,suppression_state)
SELECT w.wave_id,v.table_ref,v.area,v.metric,v.n,v.value,v.state FROM (VALUES
('DEMO-WAVE-PRICE-2026-09','DEMO-TABLE-001','DEMO-AREA-A','DEMO-PRICE-INDEX',25,103.2::numeric,'publishable'),
('DEMO-WAVE-PRICE-2026-09','DEMO-TABLE-001','DEMO-AREA-B','DEMO-PRICE-INDEX',4,101.8::numeric,'suppressed')
) v(wave,table_ref,area,metric,n,value,state) JOIN ubos_demo.survey_waves w ON w.wave_ref=v.wave
ON CONFLICT(wave_id,table_ref,area_code,metric_code) DO NOTHING;