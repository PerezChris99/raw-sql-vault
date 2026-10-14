-- Candidate indexes; retain only if measured execution plans justify them.
CREATE INDEX IF NOT EXISTS ix_agri_visit_topic_date ON agriculture_demo.extension_visits(topic,visit_at DESC);
CREATE INDEX IF NOT EXISTS ix_agri_delivery_exception ON agriculture_demo.input_deliveries(status,created_at DESC) WHERE status IN('disputed','dispatched');