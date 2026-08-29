CREATE TABLE app.service_templates (
  key text PRIMARY KEY,
  name text NOT NULL,
  description text NOT NULL,
  drive_folders jsonb NOT NULL,
  initial_tasks jsonb NOT NULL,
  intake_requirements jsonb NOT NULL,
  sla_hours integer NOT NULL CHECK (sla_hours > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.intake_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  onboarding_id uuid NOT NULL UNIQUE REFERENCES app.onboardings(id) ON DELETE CASCADE,
  token text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  submitted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.reminders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  onboarding_id uuid NOT NULL REFERENCES app.onboardings(id) ON DELETE CASCADE,
  reminder_type text NOT NULL,
  recipient text NOT NULL,
  sequence_number integer NOT NULL,
  status text NOT NULL CHECK (status IN ('scheduled', 'sent', 'cancelled', 'failed')),
  scheduled_for timestamptz NOT NULL,
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (onboarding_id, reminder_type, sequence_number)
);

CREATE TABLE app.kickoff_bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  onboarding_id uuid NOT NULL UNIQUE REFERENCES app.onboardings(id) ON DELETE CASCADE,
  provider text NOT NULL DEFAULT 'calendly',
  external_event_id text NOT NULL UNIQUE,
  starts_at timestamptz NOT NULL,
  meeting_url text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.failures (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  onboarding_id uuid NOT NULL REFERENCES app.onboardings(id) ON DELETE CASCADE,
  provider text NOT NULL,
  operation text NOT NULL,
  error_message text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'resolved')),
  attempt_count integer NOT NULL DEFAULT 1,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO app.service_templates (key, name, description, drive_folders, initial_tasks, intake_requirements, sla_hours) VALUES
  ('agency-growth', 'Agency growth', 'Campaign and growth engagement onboarding', '["01 Strategy", "02 Creative", "03 Campaigns", "04 Reporting"]', '["Confirm success metrics", "Audit existing channels", "Prepare kickoff agenda"]', '["company-goals", "stakeholders", "access-notes"]', 72),
  ('consulting-standard', 'Consulting standard', 'Professional-services discovery and delivery setup', '["01 Commercial", "02 Discovery", "03 Working Files", "04 Deliverables"]', '["Confirm project charter", "Schedule discovery", "Prepare stakeholder map"]', '["company-goals", "stakeholders", "access-notes"]', 72),
  ('recruiting-launch', 'Recruiting launch', 'Role intake and search launch', '["01 Role Intake", "02 Candidates", "03 Interviews", "04 Reporting"]', '["Approve role scorecard", "Confirm interview panel", "Launch sourcing plan"]', '["company-goals", "stakeholders", "access-notes"]', 96)
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION app.provision_onboarding(target_onboarding_id uuid, simulated_failure_provider text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  current_status app.onboarding_status;
  intake_token text;
  failed_count integer;
BEGIN
  SELECT status INTO current_status FROM app.onboardings WHERE id = target_onboarding_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Onboarding % does not exist', target_onboarding_id; END IF;
  IF current_status NOT IN ('READY_TO_PROVISION', 'PROVISIONING_PARTIAL', 'PROVISIONING') THEN
    RAISE EXCEPTION 'Onboarding % cannot be provisioned from status %', target_onboarding_id, current_status;
  END IF;

  UPDATE app.onboardings SET status = 'PROVISIONING', progress_percent = 40, blocking_reason = NULL, updated_at = now() WHERE id = target_onboarding_id;

  INSERT INTO app.provisioning_steps (id, onboarding_id, provider, operation, status, attempt_count, external_resource_id, external_resource_url, last_error)
  VALUES
    (gen_random_uuid(), target_onboarding_id, 'clickup', 'create_project', CASE WHEN simulated_failure_provider='clickup' THEN 'FAILED'::app.step_status ELSE 'SUCCEEDED'::app.step_status END, 1, CASE WHEN simulated_failure_provider='clickup' THEN NULL ELSE 'cu-' || left(target_onboarding_id::text, 8) END, CASE WHEN simulated_failure_provider='clickup' THEN NULL ELSE 'https://app.clickup.com/demo/' || target_onboarding_id END, CASE WHEN simulated_failure_provider='clickup' THEN 'Simulated ClickUp timeout' END),
    (gen_random_uuid(), target_onboarding_id, 'google_drive', 'create_folder_tree', CASE WHEN simulated_failure_provider='google_drive' THEN 'FAILED'::app.step_status ELSE 'SUCCEEDED'::app.step_status END, 1, CASE WHEN simulated_failure_provider='google_drive' THEN NULL ELSE 'gd-' || left(target_onboarding_id::text, 8) END, CASE WHEN simulated_failure_provider='google_drive' THEN NULL ELSE 'https://drive.google.com/drive/folders/demo-' || target_onboarding_id END, CASE WHEN simulated_failure_provider='google_drive' THEN 'Simulated Google Drive quota error' END),
    (gen_random_uuid(), target_onboarding_id, 'slack', 'create_channel', CASE WHEN simulated_failure_provider='slack' THEN 'FAILED'::app.step_status ELSE 'SUCCEEDED'::app.step_status END, 1, CASE WHEN simulated_failure_provider='slack' THEN NULL ELSE 'sl-' || left(target_onboarding_id::text, 8) END, CASE WHEN simulated_failure_provider='slack' THEN NULL ELSE 'https://slack.com/app_redirect?channel=demo-' || left(target_onboarding_id::text, 8) END, CASE WHEN simulated_failure_provider='slack' THEN 'Simulated Slack permission error' END)
  ON CONFLICT (onboarding_id, provider, operation) DO UPDATE SET
    status = EXCLUDED.status, attempt_count = app.provisioning_steps.attempt_count + 1,
    external_resource_id = EXCLUDED.external_resource_id, external_resource_url = EXCLUDED.external_resource_url,
    last_error = EXCLUDED.last_error, updated_at = now();

  INSERT INTO app.failures (onboarding_id, provider, operation, error_message)
  SELECT target_onboarding_id, provider, operation, last_error
  FROM app.provisioning_steps
  WHERE onboarding_id = target_onboarding_id AND status = 'FAILED'
    AND NOT EXISTS (SELECT 1 FROM app.failures f WHERE f.onboarding_id=target_onboarding_id AND f.provider=provisioning_steps.provider AND f.operation=provisioning_steps.operation AND f.status='open');

  SELECT count(*) INTO failed_count FROM app.provisioning_steps WHERE onboarding_id=target_onboarding_id AND status='FAILED';

  IF failed_count > 0 THEN
    UPDATE app.onboardings SET status='PROVISIONING_PARTIAL', progress_percent=45, blocking_reason=simulated_failure_provider || ' provisioning failed', updated_at=now() WHERE id=target_onboarding_id;
  ELSE
    INSERT INTO app.requirements (id, onboarding_id, key, label, category, is_blocking, status, due_at) VALUES
      (gen_random_uuid(), target_onboarding_id, 'company-goals', 'Goals and success criteria', 'intake', true, 'PENDING', now()+interval '3 days'),
      (gen_random_uuid(), target_onboarding_id, 'stakeholders', 'Stakeholder list', 'intake', true, 'PENDING', now()+interval '3 days'),
      (gen_random_uuid(), target_onboarding_id, 'access-notes', 'Access and credential notes', 'credential', true, 'PENDING', now()+interval '3 days')
    ON CONFLICT (onboarding_id, key) DO NOTHING;

    intake_token := encode(gen_random_bytes(24), 'hex');
    INSERT INTO app.intake_tokens (onboarding_id, token, expires_at) VALUES (target_onboarding_id, intake_token, now()+interval '14 days')
    ON CONFLICT (onboarding_id) DO UPDATE SET token=EXCLUDED.token, expires_at=EXCLUDED.expires_at
    RETURNING token INTO intake_token;

    INSERT INTO app.reminders (onboarding_id, reminder_type, recipient, sequence_number, status, scheduled_for)
    SELECT target_onboarding_id, 'missing_intake', c.primary_contact_email, 1, 'scheduled', now()+interval '24 hours'
    FROM app.onboardings o JOIN app.clients c ON c.id=o.client_id WHERE o.id=target_onboarding_id
    ON CONFLICT DO NOTHING;

    UPDATE app.onboardings SET status='AWAITING_CLIENT', progress_percent=60, blocking_reason='Goals and success criteria, Stakeholder list, Access and credential notes', updated_at=now() WHERE id=target_onboarding_id;
  END IF;

  INSERT INTO app.audit_events (onboarding_id,event_type,title,detail,actor_type,actor_name)
  VALUES (target_onboarding_id,'provisioning.finished',CASE WHEN failed_count=0 THEN 'Delivery workspace provisioned' ELSE 'Provisioning needs attention' END,CASE WHEN failed_count=0 THEN 'ClickUp, Drive, and Slack resources were created. Client intake is ready.' ELSE failed_count || ' provider operation(s) failed and can be retried.' END,'system','n8n');

  RETURN jsonb_build_object('onboarding_id',target_onboarding_id,'status',CASE WHEN failed_count=0 THEN 'AWAITING_CLIENT' ELSE 'PROVISIONING_PARTIAL' END,'failed_steps',failed_count,'intake_token',intake_token);
END;
$$;

CREATE OR REPLACE FUNCTION app.retry_provisioning_step(target_onboarding_id uuid, target_provider text)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE remaining integer; intake_result jsonb;
BEGIN
  UPDATE app.provisioning_steps SET status='SUCCEEDED', attempt_count=attempt_count+1, last_error=NULL, next_retry_at=NULL,
    external_resource_id=target_provider || '-' || left(target_onboarding_id::text,8),
    external_resource_url=CASE target_provider WHEN 'clickup' THEN 'https://app.clickup.com/demo/' WHEN 'google_drive' THEN 'https://drive.google.com/drive/folders/demo-' ELSE 'https://slack.com/app_redirect?channel=demo-' END || target_onboarding_id,
    updated_at=now()
  WHERE onboarding_id=target_onboarding_id AND provider=target_provider AND status='FAILED';
  IF NOT FOUND THEN RAISE EXCEPTION 'No failed % step exists for onboarding %',target_provider,target_onboarding_id; END IF;
  UPDATE app.failures SET status='resolved',resolved_at=now() WHERE onboarding_id=target_onboarding_id AND provider=target_provider AND status='open';
  SELECT count(*) INTO remaining FROM app.provisioning_steps WHERE onboarding_id=target_onboarding_id AND status='FAILED';
  IF remaining=0 THEN SELECT app.provision_onboarding(target_onboarding_id,NULL) INTO intake_result; RETURN intake_result; END IF;
  RETURN jsonb_build_object('onboarding_id',target_onboarding_id,'status','PROVISIONING_PARTIAL','failed_steps',remaining);
END; $$;

CREATE OR REPLACE FUNCTION app.submit_client_intake(intake_token_value text, intake_payload jsonb)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE onboarding_uuid uuid; remaining integer;
BEGIN
  SELECT onboarding_id INTO onboarding_uuid FROM app.intake_tokens WHERE token=intake_token_value AND expires_at>now() FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Intake link is invalid or expired'; END IF;
  UPDATE app.requirements SET status='APPROVED',completed_at=now() WHERE onboarding_id=onboarding_uuid AND key='company-goals' AND nullif(trim(intake_payload->>'goals'),'') IS NOT NULL;
  UPDATE app.requirements SET status='APPROVED',completed_at=now() WHERE onboarding_id=onboarding_uuid AND key='stakeholders' AND nullif(trim(intake_payload->>'stakeholders'),'') IS NOT NULL;
  UPDATE app.requirements SET status='APPROVED',completed_at=now() WHERE onboarding_id=onboarding_uuid AND key='access-notes' AND nullif(trim(intake_payload->>'access_notes'),'') IS NOT NULL;
  SELECT count(*) INTO remaining FROM app.requirements WHERE onboarding_id=onboarding_uuid AND is_blocking AND status NOT IN ('APPROVED','WAIVED');
  UPDATE app.intake_tokens SET submitted_at=now() WHERE token=intake_token_value;
  UPDATE app.reminders SET status='cancelled' WHERE onboarding_id=onboarding_uuid AND status='scheduled';
  UPDATE app.onboardings SET status=CASE WHEN remaining=0 THEN 'READY_FOR_KICKOFF'::app.onboarding_status ELSE 'AWAITING_CLIENT'::app.onboarding_status END,progress_percent=CASE WHEN remaining=0 THEN 85 ELSE 70 END,blocking_reason=CASE WHEN remaining=0 THEN NULL ELSE 'Client intake incomplete' END,updated_at=now() WHERE id=onboarding_uuid;
  INSERT INTO app.audit_events(onboarding_id,event_type,title,detail,actor_type,actor_name,metadata) VALUES(onboarding_uuid,'intake.submitted','Client intake submitted',CASE WHEN remaining=0 THEN 'All required intake information was received.' ELSE remaining || ' blocking item(s) remain.' END,'client','Client contact',intake_payload);
  RETURN jsonb_build_object('onboarding_id',onboarding_uuid,'status',CASE WHEN remaining=0 THEN 'READY_FOR_KICKOFF' ELSE 'AWAITING_CLIENT' END,'remaining_requirements',remaining);
END; $$;

CREATE OR REPLACE FUNCTION app.record_kickoff_booking(target_onboarding_id uuid, external_id text, kickoff_time timestamptz, url text)
RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO app.kickoff_bookings(onboarding_id,external_event_id,starts_at,meeting_url) VALUES(target_onboarding_id,external_id,kickoff_time,url)
  ON CONFLICT(onboarding_id) DO UPDATE SET external_event_id=EXCLUDED.external_event_id,starts_at=EXCLUDED.starts_at,meeting_url=EXCLUDED.meeting_url;
  UPDATE app.onboardings SET status='KICKOFF_SCHEDULED',progress_percent=95,blocking_reason=NULL,updated_at=now() WHERE id=target_onboarding_id AND status='READY_FOR_KICKOFF';
  IF NOT FOUND THEN RAISE EXCEPTION 'Onboarding % is not ready for kickoff',target_onboarding_id; END IF;
  INSERT INTO app.audit_events(onboarding_id,event_type,title,detail,actor_type,actor_name) VALUES(target_onboarding_id,'kickoff.scheduled','Kickoff scheduled','The kickoff meeting and initial delivery tasks are ready.','integration','Calendly');
  RETURN jsonb_build_object('onboarding_id',target_onboarding_id,'status','KICKOFF_SCHEDULED','starts_at',kickoff_time,'meeting_url',url);
END; $$;
