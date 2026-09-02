import { NextResponse } from "next/server";

const n8nBase = process.env.N8N_INTERNAL_URL ?? "http://localhost:5678";

export async function POST(request: Request, context: { params: Promise<{ id: string }> }) {
  const { id } = await context.params;
  if (!/^[0-9a-f-]{36}$/i.test(id)) return NextResponse.json({ error: "Invalid onboarding ID" }, { status: 400 });
  const body = await request.json();
  let endpoint: string;
  let payload: Record<string, unknown>;

  if (body.action === "provision") {
    endpoint = "provision-onboarding";
    payload = { onboarding_id: id, simulate_failure: String(body.simulate_failure ?? "") };
  } else if (body.action === "retry") {
    endpoint = "retry-provisioning";
    payload = { onboarding_id: id, provider: String(body.provider ?? "") };
  } else if (body.action === "schedule_kickoff") {
    endpoint = "calendly-kickoff-event";
    payload = {
      onboarding_id: id,
      event_id: `demo-kickoff-${crypto.randomUUID()}`,
      starts_at: new Date(Date.now() + 86_400_000).toISOString(),
      meeting_url: "https://meet.google.com/demo-kickoff",
    };
  } else if (body.action === "complete") {
    endpoint = "complete-onboarding";
    payload = { onboarding_id: id };
  } else if (body.action === "simulate_contract") {
    endpoint = "docusign-simulate-signed";
    payload = { onboarding_id: id };
  } else if (body.action === "simulate_deposit") {
    endpoint = "stripe-payment-event";
    payload = {
      id: `evt_demo_${crypto.randomUUID()}`,
      type: "payment_intent.succeeded",
      data: { object: { id: `pi_demo_${crypto.randomUUID()}`, metadata: { onboarding_id: id } } },
    };
  } else {
    return NextResponse.json({ error: "Unknown action" }, { status: 400 });
  }

  try {
    const response = await fetch(`${n8nBase}/webhook/${endpoint}`, {
      method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload), cache: "no-store",
    });
    const result = await response.json();
    if (!response.ok) return NextResponse.json({ error: "Workflow action failed", detail: result }, { status: 502 });
    return NextResponse.json(result);
  } catch {
    return NextResponse.json({ error: "n8n workflow is unavailable" }, { status: 503 });
  }
}
