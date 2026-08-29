CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION app.process_closed_won(event_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  event_row app.integration_events%ROWTYPE;
  client_uuid uuid := gen_random_uuid();
  deal_uuid uuid := gen_random_uuid();
  onboarding_uuid uuid := gen_random_uuid();
  inserted_event boolean := false;
BEGIN
  INSERT INTO app.integration_events (
    id, provider, external_event_id, event_type, payload
  ) VALUES (
    gen_random_uuid(), 'hubspot', event_payload->>'event_id', 'deal.closed_won', event_payload
  )
  ON CONFLICT (provider, external_event_id) DO NOTHING
  RETURNING * INTO event_row;

  inserted_event := FOUND;

  IF NOT inserted_event THEN
    SELECT * INTO event_row
    FROM app.integration_events
    WHERE provider = 'hubspot' AND external_event_id = event_payload->>'event_id';

    RETURN jsonb_build_object(
      'duplicate', true,
      'event_id', event_payload->>'event_id',
      'onboarding_id', event_row.onboarding_id
    );
  END IF;

  INSERT INTO app.clients (
    id, legal_name, display_name, website,
    primary_contact_name, primary_contact_email
  ) VALUES (
    client_uuid,
    event_payload->>'company_name',
    event_payload->>'company_name',
    NULLIF(event_payload->>'website', ''),
    event_payload->>'primary_contact_name',
    lower(event_payload->>'primary_contact_email')
  );

  INSERT INTO app.deals (
    id, client_id, source_provider, source_deal_id, name,
    value_cents, currency, service_template_key, closed_won_at
  ) VALUES (
    deal_uuid,
    client_uuid,
    'hubspot',
    event_payload->>'source_deal_id',
    event_payload->>'deal_name',
    (event_payload->>'value_cents')::bigint,
    upper(event_payload->>'currency'),
    event_payload->>'service_template_key',
    (event_payload->>'closed_won_at')::timestamptz
  );

  INSERT INTO app.onboardings (
    id, client_id, deal_id, status, owner_name, owner_email,
    sla_due_at, progress_percent, started_at
  ) VALUES (
    onboarding_uuid,
    client_uuid,
    deal_uuid,
    'RECEIVED',
    event_payload->>'owner_name',
    lower(event_payload->>'owner_email'),
    now() + make_interval(hours => COALESCE((event_payload->>'sla_hours')::integer, 72)),
    5,
    now()
  );

  INSERT INTO app.requirements (
    id, onboarding_id, key, label, category, is_blocking, status, due_at
  ) VALUES
    (gen_random_uuid(), onboarding_uuid, 'contract', 'Signed agreement', 'commercial', true, 'PENDING', now() + interval '24 hours'),
    (gen_random_uuid(), onboarding_uuid, 'deposit', 'Initial deposit', 'commercial', true, 'PENDING', now() + interval '24 hours');

  INSERT INTO app.audit_events (
    onboarding_id, event_type, title, detail, actor_type, actor_name, metadata
  ) VALUES (
    onboarding_uuid,
    'onboarding.received',
    'Closed-won handoff received',
    'HubSpot deal was accepted into the onboarding queue.',
    'integration',
    'HubSpot',
    jsonb_build_object('source_deal_id', event_payload->>'source_deal_id', 'event_id', event_payload->>'event_id')
  );

  UPDATE app.integration_events
  SET onboarding_id = onboarding_uuid, processed_at = now()
  WHERE id = event_row.id;

  RETURN jsonb_build_object(
    'duplicate', false,
    'event_id', event_payload->>'event_id',
    'onboarding_id', onboarding_uuid,
    'status', 'RECEIVED'
  );
END;
$$;
