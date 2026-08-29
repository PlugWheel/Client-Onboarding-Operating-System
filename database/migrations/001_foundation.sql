CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS n8n;

CREATE TYPE app.onboarding_status AS ENUM (
  'RECEIVED',
  'VALIDATING',
  'BLOCKED_COMMERCIAL',
  'READY_TO_PROVISION',
  'PROVISIONING',
  'PROVISIONING_PARTIAL',
  'AWAITING_CLIENT',
  'READY_FOR_KICKOFF',
  'KICKOFF_SCHEDULED',
  'COMPLETE',
  'NEEDS_REVIEW',
  'INTEGRATION_FAILED',
  'CANCELLED'
);

CREATE TYPE app.step_status AS ENUM ('PENDING', 'IN_PROGRESS', 'SUCCEEDED', 'FAILED', 'SKIPPED');
CREATE TYPE app.requirement_status AS ENUM ('PENDING', 'RECEIVED', 'APPROVED', 'REJECTED', 'WAIVED');

CREATE TABLE app.clients (
  id uuid PRIMARY KEY,
  legal_name text NOT NULL,
  display_name text NOT NULL,
  website text,
  primary_contact_name text NOT NULL,
  primary_contact_email text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.deals (
  id uuid PRIMARY KEY,
  client_id uuid NOT NULL REFERENCES app.clients(id),
  source_provider text NOT NULL CHECK (source_provider IN ('hubspot', 'ghl', 'demo')),
  source_deal_id text NOT NULL,
  name text NOT NULL,
  value_cents bigint NOT NULL DEFAULT 0 CHECK (value_cents >= 0),
  currency char(3) NOT NULL DEFAULT 'USD',
  service_template_key text NOT NULL,
  closed_won_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (source_provider, source_deal_id)
);

CREATE TABLE app.onboardings (
  id uuid PRIMARY KEY,
  client_id uuid NOT NULL REFERENCES app.clients(id),
  deal_id uuid NOT NULL UNIQUE REFERENCES app.deals(id),
  status app.onboarding_status NOT NULL DEFAULT 'RECEIVED',
  owner_name text NOT NULL,
  owner_email text NOT NULL,
  sla_due_at timestamptz NOT NULL,
  progress_percent integer NOT NULL DEFAULT 0 CHECK (progress_percent BETWEEN 0 AND 100),
  blocking_reason text,
  started_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.requirements (
  id uuid PRIMARY KEY,
  onboarding_id uuid NOT NULL REFERENCES app.onboardings(id) ON DELETE CASCADE,
  key text NOT NULL,
  label text NOT NULL,
  category text NOT NULL CHECK (category IN ('commercial', 'intake', 'credential', 'asset')),
  is_blocking boolean NOT NULL DEFAULT true,
  status app.requirement_status NOT NULL DEFAULT 'PENDING',
  due_at timestamptz,
  completed_at timestamptz,
  UNIQUE (onboarding_id, key)
);

CREATE TABLE app.provisioning_steps (
  id uuid PRIMARY KEY,
  onboarding_id uuid NOT NULL REFERENCES app.onboardings(id) ON DELETE CASCADE,
  provider text NOT NULL,
  operation text NOT NULL,
  status app.step_status NOT NULL DEFAULT 'PENDING',
  attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  external_resource_id text,
  external_resource_url text,
  last_error text,
  next_retry_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (onboarding_id, provider, operation)
);

CREATE TABLE app.integration_events (
  id uuid PRIMARY KEY,
  provider text NOT NULL,
  external_event_id text NOT NULL,
  event_type text NOT NULL,
  onboarding_id uuid REFERENCES app.onboardings(id),
  payload jsonb NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  processing_error text,
  UNIQUE (provider, external_event_id)
);

CREATE TABLE app.audit_events (
  id bigserial PRIMARY KEY,
  onboarding_id uuid NOT NULL REFERENCES app.onboardings(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  title text NOT NULL,
  detail text,
  actor_type text NOT NULL CHECK (actor_type IN ('system', 'user', 'client', 'integration')),
  actor_name text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX onboardings_status_idx ON app.onboardings(status);
CREATE INDEX onboardings_sla_due_at_idx ON app.onboardings(sla_due_at);
CREATE INDEX audit_events_onboarding_time_idx ON app.audit_events(onboarding_id, occurred_at DESC);
CREATE INDEX integration_events_unprocessed_idx ON app.integration_events(received_at) WHERE processed_at IS NULL;

