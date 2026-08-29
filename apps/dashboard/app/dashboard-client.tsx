"use client";

import { useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { AlertTriangle, ArrowRight, ArrowUpRight, Bell, BriefcaseBusiness, Check, ChevronDown, CircleHelp, Clock3, Command, FileCheck2, Filter, LayoutGrid, ListFilter, Rocket, Search, Settings2, Sparkles, Users, X } from "lucide-react";
import { SiCalendly, SiClickup, SiGoogledrive, SiHubspot, SiN8N, SiPostgresql, SiStripe } from "react-icons/si";
import { FaSlack } from "react-icons/fa6";
import type { Onboarding } from "./data";

const statusClass = (status: string) => status.toLowerCase().replaceAll(" ", "-");

export function DashboardClient({ onboardings }: { onboardings: Onboarding[] }) {
  const router = useRouter();
  const dialogRef = useRef<HTMLDialogElement>(null);
  const searchRef = useRef<HTMLInputElement>(null);
  const [search, setSearch] = useState("");
  const [slaFilter, setSlaFilter] = useState("All");
  const [filterOpen, setFilterOpen] = useState(false);
  const [compact, setCompact] = useState(false);
  const [selected, setSelected] = useState<Onboarding | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [profileOpen, setProfileOpen] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [activeTool, setActiveTool] = useState("hubspot");

  const filtered = useMemo(() => onboardings.filter((item) => {
    const haystack = `${item.client} ${item.engagement} ${item.owner} ${item.stage}`.toLowerCase();
    return haystack.includes(search.toLowerCase()) && (slaFilter === "All" || item.sla === slaFilter);
  }), [onboardings, search, slaFilter]);

  const readyCount = onboardings.filter((item) => item.stage === "Ready for kickoff").length;
  const activeCount = onboardings.filter((item) => item.stage !== "Complete").length;
  const waitingCount = onboardings.filter((item) => item.stage === "Awaiting client").length;
  const riskCount = onboardings.filter((item) => item.sla !== "Healthy").length;
  const attentionItems = onboardings.filter((item) => item.stage !== "Complete" && (item.blocker !== "None" || item.sla !== "Healthy")).slice(0, 3);
  const toolCopy: Record<string, { title: string; detail: string }> = {
    hubspot: { title: "01 · Closed-won received", detail: "HubSpot—or the manual dashboard form—sends the deal and client details into the same intake endpoint." },
    n8n: { title: "02 · n8n validates the handoff", detail: "n8n checks required fields, normalizes the payload, assigns an idempotency key, and rejects malformed events." },
    commercial: { title: "03 · Stripe + PandaDoc", detail: "Stripe confirms the deposit and PandaDoc confirms the agreement. Both must pass before provisioning is released." },
    delivery: { title: "04 · ClickUp + Drive + Slack", detail: "The system creates the delivery project, folder structure, and internal communication channel. These currently use simulated adapters." },
    calendly: { title: "05 · Calendly kickoff", detail: "When provisioning and client intake are complete, Calendly records the kickoff and the system generates initial delivery tasks." },
    postgres: { title: "Supporting state layer", detail: "PostgreSQL is supporting infrastructure—not a provider step. It preserves lifecycle state, audit history, failures, tasks, and SLA data throughout the journey." },
  };
  const stageCopy: Record<string, { meaning: string; next: string }> = {
    "Received": { meaning: "The sales handoff is safely recorded. No delivery workspace has been created yet.", next: "Confirm the signed agreement and initial deposit." },
    "Commercial hold": { meaning: "The client is recorded, but delivery is paused until the commercial requirements pass.", next: "Resolve the contract or payment item shown below." },
    "Ready to provision": { meaning: "Contract and payment are approved. The client can now receive its delivery workspace.", next: "Create the ClickUp project, Drive folders, and Slack channel." },
    "Provisioning": { meaning: "The system is creating the internal delivery environment.", next: "Monitor each provider operation and retry any failed step." },
    "Awaiting client": { meaning: "The delivery workspace exists. Kickoff is waiting on information from the client.", next: "Collect the missing intake item shown below." },
    "Ready for kickoff": { meaning: "Commercial checks, provisioning, and required intake are complete.", next: "Schedule the kickoff meeting and assign the first delivery tasks." },
    "Kickoff scheduled": { meaning: "The meeting is booked and the initial delivery tasks have been generated.", next: "Run kickoff, confirm the handoff, and complete onboarding." },
    "Complete": { meaning: "The sales-to-delivery handoff is complete and the client has reached kickoff.", next: "Delivery now continues in the provisioned project workspace." },
  };

  const showNotice = (message: string) => {
    setNotice(message);
    window.setTimeout(() => setNotice(null), 2800);
  };

  async function createOnboarding(formData: FormData) {
    setSubmitting(true);
    const response = await fetch("/api/onboardings", { method: "POST", body: formData });
    const result = await response.json();
    setSubmitting(false);
    if (!response.ok) return showNotice(result.error ?? "Could not create onboarding");
    dialogRef.current?.close();
    showNotice(`${formData.get("company_name")} added to the intake queue`);
    router.refresh();
  }

  async function runOnboardingAction(item: Onboarding, action: string, extra: Record<string, string> = {}) {
    setActionLoading(true);
    const response = await fetch(`/api/onboardings/${item.id}/actions`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ action, ...extra }) });
    const result = await response.json();
    setActionLoading(false);
    if (!response.ok) return showNotice(result.error ?? "Workflow action failed");
    setSelected(null); router.refresh(); showNotice(`${item.client} moved to ${String(result.status).replaceAll("_", " ").toLowerCase()}`);
  }

  return (
    <main className="shell">
      <aside className="rail">
        <button className="mark" aria-label="Relay home" onClick={() => window.scrollTo({ top: 0, behavior: "smooth" })}><span>R</span></button>
        <nav aria-label="Primary navigation">
          <button className="rail-link active" aria-label="Operations" onClick={() => window.scrollTo({ top: 0, behavior: "smooth" })}><LayoutGrid size={19} /></button>
          <button className="rail-link" aria-label="Clients" onClick={() => document.querySelector(".ledger")?.scrollIntoView({ behavior: "smooth" })}><Users size={19} /></button>
          <button className="rail-link" aria-label="Automation" onClick={() => window.open("http://localhost:5678/home/workflows", "_blank")}><Sparkles size={19} /></button>
        </nav>
        <div className="rail-bottom">
          <button className="rail-link" aria-label="Help" onClick={() => showNotice("Help center will be added with the operating runbooks")}><CircleHelp size={19} /></button>
          <button className="rail-link" aria-label="Settings" onClick={() => showNotice("Workspace settings are planned for the admin phase")}><Settings2 size={19} /></button>
          <span className="avatar">OP</span>
        </div>
      </aside>

      <section className="workspace">
        <header className="topbar">
          <div className="crumb"><Command size={15} /> Operations <span>/</span> Overview</div>
          <div className="top-actions">
            <button className="icon-button" aria-label="Notifications" onClick={() => showNotice(`${riskCount} SLA items require attention`)}><Bell size={18} />{riskCount > 0 && <i />}</button>
            <div className="profile-wrap"><button className="profile" onClick={() => setProfileOpen(!profileOpen)}>Olivia Park <ChevronDown size={14} /></button>{profileOpen && <div className="profile-menu"><b>Olivia Park</b><span>Onboarding manager</span><button onClick={() => showNotice("Profile settings are not required for this demo")}>Profile settings</button></div>}</div>
          </div>
        </header>

        <div className="content">
          <section className="intro">
            <div><p className="eyebrow"><span /> Client onboarding operating system</p><h1>Closed-won to kickoff,<br />without manual admin.</h1><p className="lede">This dashboard turns new sales into verified, organized, kickoff-ready client engagements—and shows exactly what is blocking each handoff.</p></div>
            <button className="primary" onClick={() => dialogRef.current?.showModal()}><span>+</span> New onboarding</button>
          </section>

          <section className="purpose-map" aria-label="Purpose and output of the system">
            <article><span className="purpose-number">INPUT · 01</span><div className="purpose-icon"><BriefcaseBusiness size={21} /></div><div><h2>A new client is won</h2><p>A closed-won CRM event—or a manual handoff—provides the client, deal, owner, and service.</p></div></article>
            <ArrowRight className="purpose-arrow" size={18} />
            <article><span className="purpose-number">PROCESS · 02</span><div className="purpose-icon"><FileCheck2 size={21} /></div><div><h2>The handoff is verified</h2><p>n8n checks the contract and deposit, creates the onboarding record, and tracks every blocker.</p></div></article>
            <ArrowRight className="purpose-arrow" size={18} />
            <article className="purpose-output"><span className="purpose-number">OUTPUT · 03</span><div className="purpose-icon"><Rocket size={21} /></div><div><h2>A kickoff-ready workspace</h2><p>The final result is an assigned project, folders, channel, completed intake, and scheduled kickoff.</p></div></article>
          </section>

          <section className="workflow-map" aria-label="Live onboarding workflow">
            <header><div><p className="eyebrow"><span /> How it works</p><h2>What happens after a deal closes</h2></div><span className="workflow-live"><i /> Live · 10 workflows published</span></header>
            <div className="workflow-track">
              <button className={`workflow-node hubspot ${activeTool === "hubspot" ? "selected" : ""}`} onClick={() => setActiveTool("hubspot")}><span><SiHubspot /></span><b>HubSpot</b><small>Closed-won</small></button>
              <div className="workflow-wire active"><i /></div>
              <button className={`workflow-node n8n ${activeTool === "n8n" ? "selected" : ""}`} onClick={() => setActiveTool("n8n")}><span><SiN8N /></span><b>n8n</b><small>Normalize</small></button>
              <div className="workflow-wire active delay-one"><i /></div>
              <button className={`workflow-node commercial ${activeTool === "commercial" ? "selected" : ""}`} onClick={() => setActiveTool("commercial")}><span className="dual-logo"><SiStripe /><em>PD</em></span><b>Stripe + PandaDoc</b><small>Paid + signed</small></button>
              <div className="workflow-wire active delay-two"><i /></div>
              <button className={`workflow-node delivery ${activeTool === "delivery" ? "selected" : ""}`} onClick={() => setActiveTool("delivery")}><span className="triple-logo"><SiClickup /><SiGoogledrive /><FaSlack /></span><b>ClickUp · Drive · Slack</b><small>Provision workspace</small></button>
              <div className="workflow-wire active"><i /></div>
              <button className={`workflow-node calendly ${activeTool === "calendly" ? "selected" : ""}`} onClick={() => setActiveTool("calendly")}><span><SiCalendly /></span><b>Calendly</b><small>Schedule kickoff</small></button>
            </div>
            <button className={`state-layer ${activeTool === "postgres" ? "selected" : ""}`} onClick={() => setActiveTool("postgres")}><SiPostgresql /><span><b>PostgreSQL state layer</b><small>Client status · audit history · retries · SLA</small></span></button>
            <div className="workflow-explainer"><span>{toolCopy[activeTool].title}</span><p>{toolCopy[activeTool].detail}</p><button onClick={() => window.open("http://localhost:5678/home/workflows", "_blank")}>Inspect in n8n <ArrowUpRight size={13} /></button></div>
          </section>

          <div className="section-intro"><div><span>LIVE OPERATING OUTPUT</span><h2>Where every client stands now</h2></div><p>{attentionItems.length} handoffs need attention. {readyCount} {readyCount === 1 ? "client is" : "clients are"} ready for kickoff.</p></div>
          <section className="metrics" aria-label="Onboarding summary">
            <article className="metric featured"><p>Active onboardings</p><strong>{activeCount}</strong><span className="trend">↑ 18% <small>this month</small></span><div className="metric-lines"><i /><i /><i /><i /><i /><i /><i /></div></article>
            <article className="metric"><p>Ready for kickoff</p><strong>{readyCount}</strong><span className="sub"><Check size={13} /> All requirements met</span></article>
            <article className="metric"><p>Waiting on client</p><strong>{waitingCount}</strong><span className="sub amber"><Clock3 size={13} /> Follow-up queue</span></article>
            <article className="metric"><p>SLA at risk</p><strong>{riskCount}</strong><span className="sub red"><AlertTriangle size={13} /> Action required</span></article>
          </section>

          <section className="attention">
            <div className="attention-title"><span><AlertTriangle size={16} /></span><div><h2>Attention queue</h2><p>Items most likely to delay kickoff</p></div></div>
            <div className="attention-items">{attentionItems.map((item, index) => <article key={item.id}><b>{String(index + 1).padStart(2, "0")}</b><div><strong>{item.client}: {item.blocker === "None" ? item.stage : item.blocker}</strong><p>{item.stage} · {item.age} in onboarding · {item.sla} SLA</p></div><button onClick={() => setSelected(item)}>Review <ArrowUpRight size={14} /></button></article>)}</div>
          </section>

          <section className={`ledger ${compact ? "compact" : ""}`}>
            <div className="ledger-head">
              <div><h2>Client onboarding outcomes</h2><span>{activeCount} active · {onboardings.length - activeCount} complete</span></div>
              <div className="tools">
                <label><Search size={15} /><input ref={searchRef} value={search} onChange={(event) => setSearch(event.target.value)} aria-label="Search onboardings" placeholder="Search clients" /></label>
                <div className="filter-wrap"><button className={slaFilter !== "All" ? "control-active" : ""} onClick={() => setFilterOpen(!filterOpen)}><Filter size={15} /> {slaFilter === "All" ? "Filter" : slaFilter}</button>{filterOpen && <div className="filter-menu">{["All", "Healthy", "At risk", "Breached"].map((value) => <button key={value} onClick={() => { setSlaFilter(value); setFilterOpen(false); }}>{value}{slaFilter === value && <Check size={13} />}</button>)}</div>}</div>
                <button className={`square ${compact ? "control-active" : ""}`} aria-label="Toggle compact view" onClick={() => setCompact(!compact)}><ListFilter size={16} /></button>
              </div>
            </div>
            <div className="table-wrap"><table><thead><tr><th>Client</th><th>Stage</th><th>Progress</th><th>Blocker / next action</th><th>Age</th><th>SLA</th><th /></tr></thead><tbody>
              {filtered.map((item) => <tr key={item.id}><td><div className="client"><span style={{ "--client-accent": item.accent } as React.CSSProperties}>{item.initials}</span><div><strong>{item.client}</strong><small>{item.displayId} · {item.engagement}</small></div></div></td><td><span className={`stage ${statusClass(item.stage)}`}><i />{item.stage}</span></td><td><div className="progress"><span><i style={{ width: `${item.progress}%` }} /></span><b>{item.progress}%</b></div></td><td><span className={item.blocker === "None" ? "clear" : "blocker"}>{item.blocker === "None" && <Check size={13} />}{item.blocker}</span></td><td className="mono">{item.age}</td><td><span className={`sla ${statusClass(item.sla)}`}>{item.sla}</span></td><td><button className="row-open" aria-label={`Open ${item.client}`} onClick={() => setSelected(item)}><ArrowUpRight size={16} /></button></td></tr>)}
              {filtered.length === 0 && <tr><td className="empty-row" colSpan={7}>No onboardings match this view.</td></tr>}
            </tbody></table></div>
            <footer><span>Showing {filtered.length} of {onboardings.length} active records</span><button onClick={() => { setSearch(""); setSlaFilter("All"); searchRef.current?.focus(); }}>View all onboardings <ArrowUpRight size={14} /></button></footer>
          </section>
        </div>
      </section>

      {selected && <div className="drawer-backdrop" onClick={() => setSelected(null)}><aside className="detail-drawer" onClick={(event) => event.stopPropagation()}><button className="drawer-close" aria-label="Close details" onClick={() => setSelected(null)}><X size={18} /></button><p className="eyebrow"><span /> {selected.displayId}</p><h2>{selected.client}</h2><p className="drawer-engagement">{selected.engagement}</p><div className="drawer-status"><small>WHAT THIS STATUS MEANS</small><strong>{stageCopy[selected.stage]?.meaning ?? "This onboarding is moving through its configured workflow."}</strong></div><div className="drawer-grid"><span>Current stage<b>{selected.stage}</b></span><span>Responsible owner<b>{selected.owner}</b></span><span>Journey complete<b>{selected.progress}%</b></span><span>SLA health<b>{selected.sla}</b></span></div><div className="drawer-blocker"><small>WAITING FOR</small><strong>{selected.blocker === "None" ? "No blocking items" : selected.blocker}</strong></div><div className="next-step"><small>NEXT SYSTEM OUTPUT</small><strong>{stageCopy[selected.stage]?.next ?? "Continue to the next configured onboarding step."}</strong></div>{selected.requirements.length > 0 && <div className="detail-list"><small>REQUIREMENTS</small>{selected.requirements.map((requirement) => <span key={requirement.key}><i className={requirement.status.toLowerCase()}>{requirement.status === "APPROVED" ? <Check size={11} /> : "·"}</i>{requirement.label}<b>{requirement.status}</b></span>)}</div>}{selected.resources.length > 0 && <div className="detail-list"><small>PROVISIONED RESOURCES</small>{selected.resources.map((resource) => <span key={resource.provider}><i className={resource.status.toLowerCase()}>{resource.status === "SUCCEEDED" ? <Check size={11} /> : "!"}</i>{resource.provider.replaceAll("_", " ")}<b>{resource.status}</b>{resource.url && <a href={resource.url} target="_blank" rel="noreferrer"><ArrowUpRight size={12} /></a>}</span>)}</div>}{selected.kickoff && <div className="detail-list"><small>KICKOFF BOOKING</small><span><i className="succeeded"><Check size={11} /></i>{new Date(selected.kickoff.startsAt).toLocaleString()}<b>BOOKED</b></span></div>}<div className="output-list"><small>FINAL ONBOARDING OUTPUT</small><span><Check size={13} /> Commercially approved client</span><span><Check size={13} /> Provisioned delivery workspace</span><span><Check size={13} /> Completed intake and scheduled kickoff</span></div><div className="drawer-actions">{selected.stage === "Ready to provision" && <><button className="primary" disabled={actionLoading} onClick={() => runOnboardingAction(selected,"provision")}>{actionLoading ? "Working…" : "Provision workspace"}</button><button className="secondary-action" disabled={actionLoading} onClick={() => runOnboardingAction(selected,"provision",{simulate_failure:"google_drive"})}>Test failure path</button></>}{selected.stage === "Provisioning partial" && selected.resources.filter((r) => r.status === "FAILED").map((resource) => <button className="primary" key={resource.provider} disabled={actionLoading} onClick={() => runOnboardingAction(selected,"retry",{provider:resource.provider})}>Retry {resource.provider.replaceAll("_", " ")}</button>)}{selected.stage === "Awaiting client" && selected.intakeToken && <button className="primary" onClick={() => window.open(`/intake/${selected.intakeToken}`,"_blank")}>Open client intake <ArrowUpRight size={14} /></button>}{selected.stage === "Ready for kickoff" && <button className="primary" disabled={actionLoading} onClick={() => runOnboardingAction(selected,"schedule_kickoff")}>{actionLoading ? "Scheduling…" : "Schedule demo kickoff"}</button>}{selected.stage === "Kickoff scheduled" && <button className="primary" disabled={actionLoading} onClick={() => runOnboardingAction(selected,"complete")}>{actionLoading ? "Completing…" : "Complete onboarding"}</button>}<button className="secondary-action" onClick={() => window.open("http://localhost:5678/home/workflows", "_blank")}>View n8n workflows</button></div></aside></div>}

      <dialog ref={dialogRef} className="new-dialog"><form action={createOnboarding}><button type="button" className="drawer-close" aria-label="Close" onClick={() => dialogRef.current?.close()}><X size={18} /></button><p className="eyebrow"><span /> Manual intake</p><h2>Create onboarding</h2><p>Add a closed-won handoff when the CRM event is unavailable.</p><div className="form-grid"><label>Company name<input name="company_name" required /></label><label>Engagement<input name="deal_name" required /></label><label>Contact name<input name="contact_name" required /></label><label>Contact email<input name="contact_email" type="email" required /></label><label>Deal value (USD)<input name="amount" type="number" min="0" defaultValue="10000" required /></label><label>Service template<select name="service_template"><option value="agency-growth">Agency growth</option><option value="consulting-standard">Consulting standard</option><option value="recruiting-launch">Recruiting launch</option></select></label></div><button className="primary submit" disabled={submitting}>{submitting ? "Creating…" : "Create onboarding"}</button></form></dialog>
      {notice && <div className="toast" role="status"><Check size={15} />{notice}</div>}
    </main>
  );
}
