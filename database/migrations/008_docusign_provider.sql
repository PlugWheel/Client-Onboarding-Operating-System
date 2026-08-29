ALTER TABLE app.integration_connections
  DROP CONSTRAINT IF EXISTS integration_connections_provider_check;

ALTER TABLE app.integration_connections
  ADD CONSTRAINT integration_connections_provider_check
  CHECK (provider IN ('hubspot','n8n','stripe','pandadoc','docusign','clickup','google_drive','slack','calendly','email'));

INSERT INTO app.integration_connections
  (provider,display_name,category,mode,health,configuration)
VALUES
  ('docusign','DocuSign','Contract','simulated','not_configured',
   '{"environment":"demo","required_non_secret":["account_id","base_uri","template_id"]}'::jsonb)
ON CONFLICT(provider) DO NOTHING;

UPDATE app.integration_connections
SET configuration = configuration || '{"replaced_by":"docusign"}'::jsonb,
    updated_at = now()
WHERE provider = 'pandadoc';
