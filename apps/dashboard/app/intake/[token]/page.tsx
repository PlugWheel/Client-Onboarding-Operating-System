import { Pool } from "pg";
import { notFound } from "next/navigation";
import { IntakeForm } from "./intake-form";

const pool = new Pool({ connectionString: process.env.DATABASE_URL ?? "postgresql://onboarding:onboarding_local@localhost:55432/onboarding_os", max: 2 });

export default async function IntakePage({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  const result = await pool.query<{ client: string; engagement: string; expires_at: Date; submitted_at: Date | null }>(`
    SELECT c.display_name client,d.name engagement,it.expires_at,it.submitted_at
    FROM app.intake_tokens it JOIN app.onboardings o ON o.id=it.onboarding_id
    JOIN app.clients c ON c.id=o.client_id JOIN app.deals d ON d.id=o.deal_id
    WHERE it.token=$1 AND it.expires_at>now()
  `,[token]);
  if (!result.rowCount) notFound();
  const intake = result.rows[0];
  return <IntakeForm token={token} client={intake.client} engagement={intake.engagement} alreadySubmitted={Boolean(intake.submitted_at)} />;
}

