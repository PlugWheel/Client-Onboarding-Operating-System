import { Pool } from "pg";
import type { Onboarding } from "./data";

const connectionString = process.env.DATABASE_URL ?? "postgresql://onboarding:onboarding_local@localhost:55432/onboarding_os";

const globalForDb = globalThis as unknown as { onboardingPool?: Pool };
const pool = globalForDb.onboardingPool ?? new Pool({ connectionString, max: 5 });

if (process.env.NODE_ENV !== "production") globalForDb.onboardingPool = pool;

const stageLabels: Record<string, Onboarding["stage"]> = {
  RECEIVED: "Received",
  VALIDATING: "Validating",
  BLOCKED_COMMERCIAL: "Commercial hold",
  READY_TO_PROVISION: "Ready to provision",
  PROVISIONING: "Provisioning",
  PROVISIONING_PARTIAL: "Provisioning partial",
  AWAITING_CLIENT: "Awaiting client",
  READY_FOR_KICKOFF: "Ready for kickoff",
  KICKOFF_SCHEDULED: "Kickoff scheduled",
  COMPLETE: "Complete",
  NEEDS_REVIEW: "Needs review",
  INTEGRATION_FAILED: "Integration failed",
  CANCELLED: "Cancelled",
};

const palette = ["#cf5c36", "#507463", "#334e68", "#a27b5c", "#71607a"];

export async function getOnboardings(): Promise<Onboarding[]> {
  const result = await pool.query<{
    id: string; client: string; engagement: string; owner: string; status: string;
    progress: number; blocker: string | null; age_hours: string; sla_due_at: Date;
    resources: Onboarding["resources"]; requirements: Onboarding["requirements"];
    intake_token: string | null; kickoff_starts_at: Date | null; meeting_url: string | null;
    tasks: Onboarding["tasks"]; timeline: Onboarding["timeline"];
  }>(`
    SELECT o.id::text, c.display_name AS client, d.name AS engagement,
      o.owner_name AS owner, o.status::text, o.progress_percent AS progress,
      COALESCE(
        o.blocking_reason,
        (
          SELECT string_agg(r.label, ', ' ORDER BY r.label)
          FROM app.requirements r
          WHERE r.onboarding_id = o.id
            AND r.is_blocking
            AND r.status NOT IN ('APPROVED', 'WAIVED')
        )
      ) AS blocker,
      floor(extract(epoch FROM (now() - o.started_at)) / 3600)::text AS age_hours,
      o.sla_due_at,
      COALESCE((SELECT jsonb_agg(jsonb_build_object('provider',p.provider,'status',p.status,'url',p.external_resource_url,'lastError',p.last_error) ORDER BY p.provider) FROM app.provisioning_steps p WHERE p.onboarding_id=o.id),'[]'::jsonb) AS resources,
      COALESCE((SELECT jsonb_agg(jsonb_build_object('key',r.key,'label',r.label,'status',r.status) ORDER BY r.category,r.label) FROM app.requirements r WHERE r.onboarding_id=o.id),'[]'::jsonb) AS requirements,
      it.token AS intake_token, kb.starts_at AS kickoff_starts_at, kb.meeting_url,
      COALESCE((SELECT jsonb_agg(jsonb_build_object('title',t.title,'status',t.status,'role',t.assignee_role) ORDER BY t.created_at) FROM app.delivery_tasks t WHERE t.onboarding_id=o.id),'[]'::jsonb) AS tasks,
      COALESCE((SELECT jsonb_agg(jsonb_build_object('title',a.title,'detail',a.detail,'occurredAt',a.occurred_at) ORDER BY a.occurred_at DESC) FROM (SELECT * FROM app.audit_events ae WHERE ae.onboarding_id=o.id ORDER BY ae.occurred_at DESC LIMIT 8) a),'[]'::jsonb) AS timeline
    FROM app.onboardings o
    JOIN app.clients c ON c.id = o.client_id
    JOIN app.deals d ON d.id = o.deal_id
    LEFT JOIN app.intake_tokens it ON it.onboarding_id=o.id
    LEFT JOIN app.kickoff_bookings kb ON kb.onboarding_id=o.id
    WHERE o.status <> 'CANCELLED'
    ORDER BY o.created_at DESC
    LIMIT 50
  `);

  return result.rows.map((row, index) => {
    const ageHours = Number(row.age_hours);
    const remainingHours = (row.sla_due_at.getTime() - Date.now()) / 3_600_000;
    const initials = row.client.split(/\s+/).map((word) => word[0]).join("").slice(0, 2).toUpperCase();
    return {
      id: row.id,
      displayId: `OB-${row.id.replaceAll("-", "").slice(-6).toUpperCase()}`,
      initials, client: row.client,
      engagement: row.engagement, owner: row.owner,
      stage: stageLabels[row.status] ?? "Needs review",
      progress: row.progress, blocker: row.blocker ?? "None",
      age: ageHours < 48 ? `${ageHours}h` : `${Math.floor(ageHours / 24)}d`,
      sla: row.status === "COMPLETE" ? "Healthy" : remainingHours < 0 ? "Breached" : remainingHours < 24 ? "At risk" : "Healthy",
      accent: palette[index % palette.length],
      resources: row.resources, requirements: row.requirements, intakeToken: row.intake_token,
      kickoff: row.kickoff_starts_at ? { startsAt: row.kickoff_starts_at.toISOString(), meetingUrl: row.meeting_url } : null,
      tasks: row.tasks, timeline: row.timeline,
    };
  });
}
