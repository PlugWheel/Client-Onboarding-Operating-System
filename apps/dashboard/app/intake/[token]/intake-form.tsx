"use client";

import { useState } from "react";
import { Check, LockKeyhole } from "lucide-react";

export function IntakeForm({ token, client, engagement, alreadySubmitted }: { token: string; client: string; engagement: string; alreadySubmitted: boolean }) {
  const [done, setDone] = useState(alreadySubmitted);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  async function submit(formData: FormData) {
    setLoading(true); setError("");
    const response = await fetch(`/api/intake/${token}`, { method: "POST", body: formData });
    const result = await response.json(); setLoading(false);
    if (!response.ok) return setError(result.error ?? "Submission failed");
    setDone(true);
  }
  return <main className="intake-shell"><div className="intake-brand"><span>R</span> RELAY / CLIENT INTAKE</div><section className="intake-card">{done ? <div className="intake-success"><span><Check size={28} /></span><p>INTAKE COMPLETE</p><h1>Thank you, {client}.</h1><div>Your delivery team now has the information required to prepare kickoff. The onboarding manager has been notified.</div></div> : <form action={submit}><p className="eyebrow"><span /> Secure onboarding request</p><h1>Let’s prepare<br />your kickoff.</h1><p className="intake-lede">{engagement} · {client}</p><label>What should this engagement accomplish?<textarea name="goals" rows={4} required placeholder="Goals, success measures, and important deadlines…" /></label><label>Who should be involved?<textarea name="stakeholders" rows={3} required placeholder="Names, roles, and decision-makers…" /></label><label>What access will the team need?<textarea name="access_notes" rows={3} required placeholder="List systems and access owners. Do not enter passwords here." /></label><div className="security-note"><LockKeyhole size={16} /><span>Never submit passwords or secret keys. Your onboarding manager will provide secure credential-sharing instructions.</span></div>{error && <p className="form-error">{error}</p>}<button className="primary intake-submit" disabled={loading}>{loading ? "Submitting…" : "Complete intake"}</button></form>}</section><footer>Powered by Relay · Secure onboarding workspace</footer></main>;
}

