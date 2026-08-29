import { NextResponse } from "next/server";

export async function POST(request: Request) {
  const form = await request.formData();
  const required = ["company_name", "deal_name", "contact_name", "contact_email"] as const;
  for (const field of required) {
    if (!String(form.get(field) ?? "").trim()) {
      return NextResponse.json({ error: `${field.replaceAll("_", " ")} is required` }, { status: 400 });
    }
  }

  const id = crypto.randomUUID();
  const amount = Number(form.get("amount") ?? 0);
  const payload = {
    event_id: `manual-${id}`,
    source_deal_id: `manual-${id}`,
    dealstage: "closedwon",
    company_name: String(form.get("company_name")),
    primary_contact_name: String(form.get("contact_name")),
    primary_contact_email: String(form.get("contact_email")),
    deal_name: String(form.get("deal_name")),
    amount: Number.isFinite(amount) ? amount : 0,
    currency: "USD",
    service_template_key: String(form.get("service_template") ?? "consulting-standard"),
    owner_name: "Olivia Park",
    owner_email: "olivia@example.com",
    closed_won_at: new Date().toISOString(),
    sla_hours: 72,
  };

  try {
    const response = await fetch(`${process.env.N8N_INTERNAL_URL ?? "http://localhost:5678"}/webhook/hubspot-closed-won`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      cache: "no-store",
    });
    const result = await response.json();
    if (!response.ok) return NextResponse.json({ error: "The intake workflow rejected this handoff", detail: result }, { status: 502 });
    return NextResponse.json(result, { status: 201 });
  } catch {
    return NextResponse.json({ error: "The n8n intake workflow is unavailable" }, { status: 503 });
  }
}

