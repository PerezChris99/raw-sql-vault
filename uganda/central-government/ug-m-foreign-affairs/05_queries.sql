-- 20 read-only reports over synthetic engagement metadata.
-- 01 Register.
SELECT * FROM diplomacy_demo.v_engagement_register ORDER BY held_at DESC;
-- 02 Open commitments.
SELECT * FROM diplomacy_demo.v_open_commitments ORDER BY due_date NULLS LAST;
-- 03 Overdue commitments.
SELECT * FROM diplomacy_demo.v_overdue_commitments ORDER BY due_date;
-- 04 Engagement volume by country and type.
SELECT country_code,engagement_type,COUNT(*) FROM diplomacy_demo.v_engagement_register GROUP BY 1,2;
-- 05 Engagements by publication state.
SELECT publication_state,COUNT(*) FROM diplomacy_demo.engagements GROUP BY publication_state;
-- 06 Missions with no engagement.
SELECT mission_code FROM diplomacy_demo.missions m WHERE NOT EXISTS(SELECT 1 FROM diplomacy_demo.engagements e WHERE e.mission_id=m.mission_id);
-- 07 Commitments by status.
SELECT status,COUNT(*) FROM diplomacy_demo.commitments GROUP BY status;
-- 08 Commitment event timeline.
SELECT c.commitment_ref,e.previous_status,e.new_status,e.actor_ref,e.happened_at FROM diplomacy_demo.commitment_events e JOIN diplomacy_demo.commitments c USING(commitment_id) ORDER BY c.commitment_ref,e.happened_at;
-- 09 Latest commitment event.
SELECT DISTINCT ON(commitment_id) commitment_id,new_status,happened_at FROM diplomacy_demo.commitment_events ORDER BY commitment_id,happened_at DESC,event_id DESC;
-- 10 Completed commitments missing timestamp (should be empty).
SELECT commitment_ref FROM diplomacy_demo.commitments WHERE status='completed' AND completed_at IS NULL;
-- 11 Engagements without commitment records.
SELECT e.engagement_ref FROM diplomacy_demo.engagements e WHERE NOT EXISTS(SELECT 1 FROM diplomacy_demo.commitments c WHERE c.engagement_id=e.engagement_id);
-- 12 Upcoming due commitments.
SELECT commitment_ref,due_date FROM diplomacy_demo.v_open_commitments WHERE due_date>=CURRENT_DATE AND due_date<CURRENT_DATE+30;
-- 13 Commitments grouped by owner.
SELECT owner_ref,COUNT(*) FROM diplomacy_demo.commitments WHERE status NOT IN('completed','cancelled') GROUP BY owner_ref;
-- 14 Engagement counts by UTC month.
SELECT date_trunc('month',held_at AT TIME ZONE 'UTC') AS month_utc,COUNT(*) FROM diplomacy_demo.engagements GROUP BY 1 ORDER BY 1;
-- 15 Draft public-summary queue.
SELECT engagement_ref,mission_code,topic_code FROM diplomacy_demo.v_engagement_register WHERE publication_state='draft';
-- 16 Withheld summaries for internal review.
SELECT engagement_ref,mission_code FROM diplomacy_demo.v_engagement_register WHERE publication_state='withheld';
-- 17 Follow-up lag signal.
SELECT commitment_ref,CURRENT_DATE-due_date AS days_past_due FROM diplomacy_demo.v_overdue_commitments;
-- 18 Topic distribution by post.
SELECT mission_code,topic_code,COUNT(*) FROM diplomacy_demo.v_engagement_register GROUP BY 1,2;
-- 19 Commitments without due dates.
SELECT commitment_ref FROM diplomacy_demo.commitments WHERE due_date IS NULL AND status NOT IN('completed','cancelled');
-- 20 Data quality scan for status transitions missing events.
SELECT commitment_ref FROM diplomacy_demo.commitments c WHERE status<>'open' AND NOT EXISTS(SELECT 1 FROM diplomacy_demo.commitment_events e WHERE e.commitment_id=c.commitment_id);