CREATE OR REPLACE FUNCTION app.process_commercial_event(event_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  event_row app.integration_events%ROWTYPE;
  onboarding_uuid uuid;
  requirement_key text := event_payload->>'requirement_key';
  next_requirement_status app.requirement_status;
  next_onboarding_status app.onboarding_status;
  outstanding_count integer;
  outstanding_labels text;
  current_status app.onboarding_status;
BEGIN
  onboarding_uuid := NULLIF(event_payload->>'onboarding_id', '')::uuid;
  IF onboarding_uuid IS NULL AND event_payload->>'source_deal_id' IS NOT NULL THEN
    SELECT o.id INTO onboarding_uuid
    FROM app.onboardings o
    JOIN app.deals d ON d.id = o.deal_id
    WHERE d.source_provider = 'hubspot'
      AND d.source_deal_id = event_payload->>'source_deal_id';
  END IF;

  SELECT status INTO current_status
  FROM app.onboardings
  WHERE id = onboarding_uuid
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Onboarding % does not exist', onboarding_uuid;
  END IF;

  next_requirement_status := CASE lower(event_payload->>'result')
    WHEN 'approved' THEN 'APPROVED'::app.requirement_status
    WHEN 'paid' THEN 'APPROVED'::app.requirement_status
    WHEN 'signed' THEN 'APPROVED'::app.requirement_status
    WHEN 'waived' THEN 'WAIVED'::app.requirement_status
    WHEN 'failed' THEN 'REJECTED'::app.requirement_status
    WHEN 'rejected' THEN 'REJECTED'::app.requirement_status
    ELSE 'PENDING'::app.requirement_status
  END;

  INSERT INTO app.integration_events (
    id, provider, external_event_id, event_type, onboarding_id, payload
  ) VALUES (
    gen_random_uuid(),
    event_payload->>'provider',
    event_payload->>'event_id',
    event_payload->>'event_type',
    onboarding_uuid,
    event_payload
  )
  ON CONFLICT (provider, external_event_id) DO NOTHING
  RETURNING * INTO event_row;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'duplicate', true,
      'event_id', event_payload->>'event_id',
      'onboarding_id', onboarding_uuid,
      'status', current_status
    );
  END IF;

  UPDATE app.requirements
  SET status = next_requirement_status,
      completed_at = CASE
        WHEN next_requirement_status IN ('APPROVED', 'WAIVED') THEN now()
        ELSE NULL
      END
  WHERE onboarding_id = onboarding_uuid
    AND key = requirement_key
    AND category = 'commercial';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Commercial requirement % does not exist for onboarding %', requirement_key, onboarding_uuid;
  END IF;

  SELECT count(*), string_agg(label, ', ' ORDER BY label)
  INTO outstanding_count, outstanding_labels
  FROM app.requirements
  WHERE onboarding_id = onboarding_uuid
    AND category = 'commercial'
    AND is_blocking
    AND status NOT IN ('APPROVED', 'WAIVED');

  next_onboarding_status := CASE
    WHEN outstanding_count = 0 THEN 'READY_TO_PROVISION'::app.onboarding_status
    ELSE 'BLOCKED_COMMERCIAL'::app.onboarding_status
  END;

  IF current_status IN ('RECEIVED', 'VALIDATING', 'BLOCKED_COMMERCIAL', 'READY_TO_PROVISION') THEN
    UPDATE app.onboardings
    SET status = next_onboarding_status,
        progress_percent = CASE WHEN next_onboarding_status = 'READY_TO_PROVISION' THEN 30 ELSE 15 END,
        blocking_reason = CASE WHEN outstanding_count = 0 THEN NULL ELSE outstanding_labels END,
        updated_at = now()
    WHERE id = onboarding_uuid;
  ELSE
    next_onboarding_status := current_status;
  END IF;

  INSERT INTO app.audit_events (
    onboarding_id, event_type, title, detail, actor_type, actor_name, metadata
  ) VALUES (
    onboarding_uuid,
    'commercial.' || requirement_key || '.' || lower(next_requirement_status::text),
    CASE requirement_key
      WHEN 'deposit' THEN 'Payment status updated'
      WHEN 'contract' THEN 'Contract status updated'
      ELSE 'Commercial requirement updated'
    END,
    CASE
      WHEN outstanding_count = 0 THEN 'All commercial requirements are satisfied. Provisioning can begin.'
      ELSE 'Provisioning remains blocked by: ' || outstanding_labels || '.'
    END,
    'integration',
    initcap(event_payload->>'provider'),
    jsonb_build_object('external_event_id', event_payload->>'event_id', 'result', event_payload->>'result')
  );

  UPDATE app.integration_events
  SET processed_at = now()
  WHERE id = event_row.id;

  RETURN jsonb_build_object(
    'duplicate', false,
    'event_id', event_payload->>'event_id',
    'onboarding_id', onboarding_uuid,
    'requirement', requirement_key,
    'requirement_status', next_requirement_status,
    'outstanding_requirements', outstanding_count,
    'status', next_onboarding_status
  );
END;
$$;
