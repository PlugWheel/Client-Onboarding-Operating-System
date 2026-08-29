CREATE TABLE IF NOT EXISTS app.email_deliveries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  onboarding_id uuid NOT NULL REFERENCES app.onboardings(id) ON DELETE CASCADE,
  reminder_id uuid REFERENCES app.reminders(id) ON DELETE SET NULL,
  provider text NOT NULL DEFAULT 'gmail',
  purpose text NOT NULL,
  recipient text NOT NULL,
  provider_message_id text NOT NULL UNIQUE,
  status text NOT NULL CHECK(status IN ('sent','failed')),
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

