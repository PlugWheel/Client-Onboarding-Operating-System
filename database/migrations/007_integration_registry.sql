CREATE TYPE app.integration_mode AS ENUM ('simulated', 'sandbox', 'live');
CREATE TYPE app.integration_health AS ENUM ('not_configured', 'configured', 'healthy', 'degraded', 'failed');

CREATE TABLE app.integration_connections (
  provider text PRIMARY KEY,
  display_name text NOT NULL,
  category text NOT NULL,
  mode app.integration_mode NOT NULL DEFAULT 'simulated',
  health app.integration_health NOT NULL DEFAULT 'not_configured',
  credential_name text,
  configuration jsonb NOT NULL DEFAULT '{}'::jsonb,
  last_checked_at timestamptz,
  last_error text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (provider IN ('hubspot','n8n','stripe','pandadoc','clickup','google_drive','slack','calendly','email'))
);

INSERT INTO app.integration_connections (provider,display_name,category,mode,health,credential_name,configuration,last_checked_at) VALUES
  ('hubspot','HubSpot','CRM','simulated','not_configured',NULL,'{"required_non_secret":["pipeline_id","closed_won_stage_id","service_template_property"]}',NULL),
  ('n8n','n8n','Automation','live','healthy',NULL,'{"base_url":"http://localhost:5678","version":"2.36.8"}',now()),
  ('stripe','Stripe','Payment','simulated','not_configured',NULL,'{"required_non_secret":["test_payment_flow","metadata_convention"]}',NULL),
  ('pandadoc','PandaDoc','Contract','simulated','not_configured',NULL,'{"required_non_secret":["template_id"]}',NULL),
  ('clickup','ClickUp','Project management','simulated','not_configured',NULL,'{"required_non_secret":["workspace_id","space_id","template_or_list_id"]}',NULL),
  ('google_drive','Google Drive','File storage','simulated','not_configured',NULL,'{"required_non_secret":["parent_folder_id","template_folder_id"]}',NULL),
  ('slack','Slack','Communication','simulated','not_configured',NULL,'{"required_non_secret":["workspace_id","channel_prefix","staff_user_ids"]}',NULL),
  ('calendly','Calendly','Scheduling','simulated','not_configured',NULL,'{"required_non_secret":["event_type_uri","scheduling_owner"]}',NULL),
  ('email','Email delivery','Communication','simulated','not_configured',NULL,'{"required_non_secret":["sender_name","sender_address","reply_to"]}',NULL)
ON CONFLICT(provider) DO UPDATE SET configuration=EXCLUDED.configuration,updated_at=now();

CREATE VIEW app.integration_readiness AS
SELECT provider,display_name,category,mode,health,credential_name,configuration,last_checked_at,last_error,
  CASE
    WHEN mode='simulated' THEN 'Simulation only'
    WHEN health='healthy' THEN 'Ready'
    WHEN health='configured' THEN 'Credential requires verification'
    ELSE 'Action required'
  END AS readiness_label
FROM app.integration_connections;

