CREATE TABLE IF NOT EXISTS app.contract_envelopes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  onboarding_id uuid NOT NULL REFERENCES app.onboardings(id) ON DELETE CASCADE,
  provider text NOT NULL DEFAULT 'docusign' CHECK (provider = 'docusign'),
  envelope_id text NOT NULL UNIQUE,
  template_id text NOT NULL,
  status text NOT NULL,
  recipient_email text NOT NULL,
  sent_at timestamptz,
  completed_at timestamptz,
  last_checked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (onboarding_id, provider)
);

CREATE INDEX IF NOT EXISTS contract_envelopes_open_idx
  ON app.contract_envelopes (last_checked_at)
  WHERE status NOT IN ('completed', 'declined', 'voided');

