CREATE TABLE IF NOT EXISTS app.payment_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  onboarding_id uuid NOT NULL UNIQUE REFERENCES app.onboardings(id) ON DELETE CASCADE,
  stripe_price_id text NOT NULL,
  stripe_payment_link_id text NOT NULL UNIQUE,
  payment_url text NOT NULL,
  amount_cents integer NOT NULL CHECK (amount_cents > 0),
  currency text NOT NULL,
  recipient text NOT NULL,
  status text NOT NULL DEFAULT 'sent' CHECK (status IN ('sent','paid','failed','expired')),
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS payment_requests_status_idx
  ON app.payment_requests(status, created_at DESC);
