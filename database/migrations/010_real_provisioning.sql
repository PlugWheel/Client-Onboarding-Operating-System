CREATE OR REPLACE FUNCTION app.complete_real_provisioning(resource_payload jsonb)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  target_onboarding_id uuid := (resource_payload->>'onboarding_id')::uuid;
  intake_token_value text;
BEGIN
  IF coalesce(resource_payload->>'clickup_id','')='' OR coalesce(resource_payload->>'drive_id','')='' OR coalesce(resource_payload->>'slack_id','')='' THEN
    RAISE EXCEPTION 'All real provisioning resource IDs are required';
  END IF;

  UPDATE app.provisioning_steps SET status='SUCCEEDED',attempt_count=attempt_count+1,
    external_resource_id=CASE provider WHEN 'clickup' THEN resource_payload->>'clickup_id' WHEN 'google_drive' THEN resource_payload->>'drive_id' WHEN 'slack' THEN resource_payload->>'slack_id' END,
    external_resource_url=CASE provider WHEN 'clickup' THEN resource_payload->>'clickup_url' WHEN 'google_drive' THEN resource_payload->>'drive_url' WHEN 'slack' THEN resource_payload->>'slack_url' END,
    last_error=NULL,next_retry_at=NULL,updated_at=now()
  WHERE onboarding_id=target_onboarding_id AND provider IN ('clickup','google_drive','slack');

  INSERT INTO app.requirements(id,onboarding_id,key,label,category,is_blocking,status,due_at) VALUES
    (gen_random_uuid(),target_onboarding_id,'company-goals','Goals and success criteria','intake',true,'PENDING',now()+interval '3 days'),
    (gen_random_uuid(),target_onboarding_id,'stakeholders','Stakeholder list','intake',true,'PENDING',now()+interval '3 days'),
    (gen_random_uuid(),target_onboarding_id,'access-notes','Access and credential notes','credential',true,'PENDING',now()+interval '3 days')
  ON CONFLICT(onboarding_id,key) DO NOTHING;

  intake_token_value:=encode(gen_random_bytes(24),'hex');
  INSERT INTO app.intake_tokens(onboarding_id,token,expires_at) VALUES(target_onboarding_id,intake_token_value,now()+interval '14 days')
  ON CONFLICT(onboarding_id) DO UPDATE SET token=EXCLUDED.token,expires_at=EXCLUDED.expires_at RETURNING token INTO intake_token_value;

  INSERT INTO app.reminders(onboarding_id,reminder_type,recipient,sequence_number,status,scheduled_for)
  SELECT target_onboarding_id,'missing_intake',c.primary_contact_email,1,'scheduled',now()+interval '24 hours'
  FROM app.onboardings o JOIN app.clients c ON c.id=o.client_id WHERE o.id=target_onboarding_id ON CONFLICT DO NOTHING;

  UPDATE app.onboardings SET status='AWAITING_CLIENT',progress_percent=60,
    blocking_reason='Goals and success criteria, Stakeholder list, Access and credential notes',updated_at=now()
  WHERE id=target_onboarding_id AND status='PROVISIONING';
  IF NOT FOUND THEN RAISE EXCEPTION 'Onboarding % is not provisioning',target_onboarding_id; END IF;

  INSERT INTO app.audit_events(onboarding_id,event_type,title,detail,actor_type,actor_name,metadata)
  VALUES(target_onboarding_id,'provisioning.finished','Delivery workspace provisioned',
    'Real ClickUp, Google Drive, and Slack resources were created. Client intake is ready.','system','n8n',resource_payload-'onboarding_id');

  RETURN jsonb_build_object('onboarding_id',target_onboarding_id,'status','AWAITING_CLIENT','intake_token',intake_token_value,'resources',resource_payload-'onboarding_id');
END; $$;
