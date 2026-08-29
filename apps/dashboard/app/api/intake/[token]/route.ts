import { NextResponse } from "next/server";
import { Pool } from "pg";

const pool = new Pool({ connectionString: process.env.DATABASE_URL ?? "postgresql://onboarding:onboarding_local@localhost:55432/onboarding_os", max: 2 });

export async function POST(request: Request, context: { params: Promise<{ token: string }> }) {
  const { token } = await context.params;
  const form = await request.formData();
  const payload = {
    goals: String(form.get("goals") ?? ""),
    stakeholders: String(form.get("stakeholders") ?? ""),
    access_notes: String(form.get("access_notes") ?? ""),
  };
  if (Object.values(payload).some((value) => !value.trim())) return NextResponse.json({ error: "All intake fields are required" }, { status: 400 });
  try {
    const result = await pool.query("SELECT app.submit_client_intake($1,$2::jsonb) AS result", [token, JSON.stringify(payload)]);
    return NextResponse.json(result.rows[0].result);
  } catch (error) {
    return NextResponse.json({ error: error instanceof Error ? error.message : "Intake could not be submitted" }, { status: 400 });
  }
}

