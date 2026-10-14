-- Fictional posts and engagement metadata; stable refs are re-runnable.
INSERT INTO diplomacy_demo.missions(mission_code,country_code,post_type) VALUES('DEMO-POST-A','KE','embassy'),('DEMO-POST-B','TZ','high_commission'),('DEMO-POST-C','BE','multilateral') ON CONFLICT(mission_code) DO NOTHING;
INSERT INTO diplomacy_demo.engagements(engagement_ref,mission_id,engagement_type,held_at,topic_code,summary,publication_state)
SELECT v.ref,m.mission_id,v.typ,v.held,v.topic,v.summary,v.pub FROM (VALUES
('DEMO-ENG-001','DEMO-POST-A','trade_promotion',TIMESTAMPTZ '2026-09-10 09:00+00','DEMO-TRADE','Synthetic market access discussion','approved_public'),
('DEMO-ENG-002','DEMO-POST-B','bilateral_meeting',TIMESTAMPTZ '2026-10-02 10:00+00','DEMO-COOP','Synthetic bilateral follow-up','internal_summary'),
('DEMO-ENG-003','DEMO-POST-C','multilateral_session',TIMESTAMPTZ '2026-10-08 14:00+00','DEMO-REGIONAL','Synthetic agenda item','draft')
) v(ref,post,typ,held,topic,summary,pub) JOIN diplomacy_demo.missions m ON m.mission_code=v.post ON CONFLICT(engagement_ref) DO NOTHING;
INSERT INTO diplomacy_demo.commitments(commitment_ref,engagement_id,action_summary,owner_ref,due_date,status)
SELECT v.ref,e.engagement_id,v.summary,'DEMO-OWNER',v.due,v.status FROM (VALUES
('DEMO-COM-001','DEMO-ENG-001','Share synthetic trade briefing',DATE '2026-11-15','open'),
('DEMO-COM-002','DEMO-ENG-002','Prepare fictional follow-up note',DATE '2026-10-20','in_progress')
) v(ref,eng,summary,due,status) JOIN diplomacy_demo.engagements e ON e.engagement_ref=v.eng ON CONFLICT(commitment_ref) DO NOTHING;