INSERT INTO app.clients (id, legal_name, display_name, website, primary_contact_name, primary_contact_email) VALUES
  ('10000000-0000-4000-8000-000000000001', 'Northstar Creative LLC', 'Northstar', 'https://northstar.example', 'Maya Chen', 'maya@northstar.example'),
  ('10000000-0000-4000-8000-000000000002', 'Fieldstone Advisory Inc', 'Fieldstone', 'https://fieldstone.example', 'Ellis Grant', 'ellis@fieldstone.example'),
  ('10000000-0000-4000-8000-000000000003', 'Arcwell Talent Partners', 'Arcwell', 'https://arcwell.example', 'Samira Khan', 'samira@arcwell.example');

INSERT INTO app.deals (id, client_id, source_provider, source_deal_id, name, value_cents, currency, service_template_key, closed_won_at) VALUES
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'hubspot', 'demo-101', 'Growth engagement', 2400000, 'USD', 'agency-growth', now() - interval '18 hours'),
  ('20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', 'hubspot', 'demo-102', 'Finance transformation', 1800000, 'USD', 'consulting-standard', now() - interval '3 days'),
  ('20000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000003', 'demo', 'demo-103', 'Recruiting partnership', 1250000, 'USD', 'recruiting-launch', now() - interval '6 days');

INSERT INTO app.onboardings (id, client_id, deal_id, status, owner_name, owner_email, sla_due_at, progress_percent, blocking_reason, started_at) VALUES
  ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'AWAITING_CLIENT', 'Olivia Park', 'olivia@example.com', now() + interval '30 hours', 68, 'Brand asset pack', now() - interval '18 hours'),
  ('30000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000002', 'BLOCKED_COMMERCIAL', 'Jon Bell', 'jon@example.com', now() + interval '10 hours', 22, 'Deposit pending', now() - interval '3 days'),
  ('30000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000003', 'READY_FOR_KICKOFF', 'Olivia Park', 'olivia@example.com', now() - interval '20 hours', 91, NULL, now() - interval '6 days');

INSERT INTO app.requirements (id, onboarding_id, key, label, category, is_blocking, status, due_at, completed_at) VALUES
  ('40000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 'contract', 'Signed agreement', 'commercial', true, 'APPROVED', now(), now() - interval '16 hours'),
  ('40000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000001', 'brand-assets', 'Brand asset pack', 'asset', true, 'PENDING', now() + interval '1 day', NULL),
  ('40000000-0000-4000-8000-000000000003', '30000000-0000-4000-8000-000000000002', 'deposit', 'Initial deposit', 'commercial', true, 'PENDING', now(), NULL),
  ('40000000-0000-4000-8000-000000000004', '30000000-0000-4000-8000-000000000003', 'role-intake', 'Role intake form', 'intake', true, 'APPROVED', now(), now() - interval '1 day');

INSERT INTO app.audit_events (onboarding_id, event_type, title, detail, actor_type, actor_name, occurred_at) VALUES
  ('30000000-0000-4000-8000-000000000001', 'intake.sent', 'Intake request sent', 'Questionnaire and asset checklist sent to Maya.', 'system', 'n8n', now() - interval '12 hours'),
  ('30000000-0000-4000-8000-000000000002', 'commercial.blocked', 'Deposit still pending', 'Provisioning is paused until Stripe confirms payment.', 'integration', 'Stripe', now() - interval '5 hours'),
  ('30000000-0000-4000-8000-000000000003', 'intake.completed', 'All client inputs received', 'Kickoff scheduling can begin.', 'client', 'Samira Khan', now() - interval '2 hours');

