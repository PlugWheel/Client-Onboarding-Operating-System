CREATE TABLE app.delivery_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  onboarding_id uuid NOT NULL REFERENCES app.onboardings(id) ON DELETE CASCADE,
  title text NOT NULL,
  assignee_role text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','cancelled')),
  due_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(onboarding_id,title)
);

CREATE OR REPLACE FUNCTION app.record_kickoff_booking(target_onboarding_id uuid, external_id text, kickoff_time timestamptz, url text)
RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO app.kickoff_bookings(onboarding_id,external_event_id,starts_at,meeting_url) VALUES(target_onboarding_id,external_id,kickoff_time,url)
  ON CONFLICT(onboarding_id) DO UPDATE SET external_event_id=EXCLUDED.external_event_id,starts_at=EXCLUDED.starts_at,meeting_url=EXCLUDED.meeting_url;
  UPDATE app.onboardings SET status='KICKOFF_SCHEDULED',progress_percent=95,blocking_reason=NULL,updated_at=now() WHERE id=target_onboarding_id AND status='READY_FOR_KICKOFF';
  IF NOT FOUND THEN RAISE EXCEPTION 'Onboarding % is not ready for kickoff',target_onboarding_id; END IF;
  INSERT INTO app.delivery_tasks(onboarding_id,title,assignee_role,due_at)
  SELECT target_onboarding_id,task,'Delivery lead',kickoff_time+interval '1 day'
  FROM app.onboardings o JOIN app.deals d ON d.id=o.deal_id JOIN app.service_templates st ON st.key=d.service_template_key,
  LATERAL jsonb_array_elements_text(st.initial_tasks) task WHERE o.id=target_onboarding_id
  ON CONFLICT(onboarding_id,title) DO NOTHING;
  INSERT INTO app.audit_events(onboarding_id,event_type,title,detail,actor_type,actor_name) VALUES(target_onboarding_id,'kickoff.scheduled','Kickoff scheduled','The kickoff meeting and initial delivery tasks are ready.','integration','Calendly');
  RETURN jsonb_build_object('onboarding_id',target_onboarding_id,'status','KICKOFF_SCHEDULED','starts_at',kickoff_time,'meeting_url',url);
END; $$;

CREATE OR REPLACE FUNCTION app.complete_onboarding(target_onboarding_id uuid)
RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
  UPDATE app.onboardings SET status='COMPLETE',progress_percent=100,completed_at=now(),updated_at=now() WHERE id=target_onboarding_id AND status='KICKOFF_SCHEDULED';
  IF NOT FOUND THEN RAISE EXCEPTION 'Onboarding % is not kickoff scheduled',target_onboarding_id; END IF;
  INSERT INTO app.audit_events(onboarding_id,event_type,title,detail,actor_type,actor_name) VALUES(target_onboarding_id,'onboarding.completed','Onboarding completed','The client has reached kickoff with its delivery workspace and initial tasks ready.','user','Onboarding manager');
  RETURN jsonb_build_object('onboarding_id',target_onboarding_id,'status','COMPLETE','progress_percent',100);
END; $$;

CREATE OR REPLACE FUNCTION app.run_reminder_cycle()
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE sent_count integer;
BEGIN
  WITH due AS (
    UPDATE app.reminders r SET status='sent',sent_at=now()
    FROM app.onboardings o WHERE r.onboarding_id=o.id AND r.status='scheduled' AND r.scheduled_for<=now() AND o.status='AWAITING_CLIENT'
    RETURNING r.onboarding_id,r.sequence_number,r.recipient
  ), audit AS (
    INSERT INTO app.audit_events(onboarding_id,event_type,title,detail,actor_type,actor_name)
    SELECT onboarding_id,'reminder.sent','Missing-item reminder sent','Reminder '||sequence_number||' was delivered to '||recipient||'.','system','n8n' FROM due RETURNING 1
  ) SELECT count(*) INTO sent_count FROM audit;
  RETURN jsonb_build_object('sent_reminders',sent_count,'run_at',now());
END; $$;

CREATE OR REPLACE FUNCTION app.run_sla_monitor()
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE breach_count integer;
BEGIN
  WITH breached AS (
    SELECT o.id,o.owner_email,
      coalesce((SELECT max(r.sequence_number) + 1 FROM app.reminders r WHERE r.onboarding_id=o.id AND r.reminder_type='sla_escalation'),1) AS sequence_number
    FROM app.onboardings o
    WHERE o.sla_due_at<now() AND o.status NOT IN ('COMPLETE','CANCELLED')
      AND NOT EXISTS (SELECT 1 FROM app.reminders r WHERE r.onboarding_id=o.id AND r.reminder_type='sla_escalation' AND r.created_at>now()-interval '24 hours')
  ), inserted AS (
    INSERT INTO app.reminders(onboarding_id,reminder_type,recipient,sequence_number,status,scheduled_for,sent_at)
    SELECT id,'sla_escalation',owner_email,sequence_number,'sent',now(),now() FROM breached
    ON CONFLICT(onboarding_id,reminder_type,sequence_number) DO NOTHING
    RETURNING onboarding_id
  ), audit AS (
    INSERT INTO app.audit_events(onboarding_id,event_type,title,detail,actor_type,actor_name)
    SELECT onboarding_id,'sla.breached','Onboarding SLA breached','The onboarding manager was escalated automatically.','system','n8n' FROM inserted RETURNING 1
  ) SELECT count(*) INTO breach_count FROM audit;
  RETURN jsonb_build_object('new_escalations',breach_count,'run_at',now());
END; $$;
