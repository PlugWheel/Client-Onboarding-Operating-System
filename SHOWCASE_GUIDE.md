# Client Showcase Guide

## Demo record

Use **Northstar Advisory - Showcase**. It is the newest record and is already at **Complete · 100%**.

The controlled showcase run produced:

- approved deposit and agreement gates;
- a real ClickUp delivery area with three starter tasks;
- a real Google Drive client root with four standard subfolders;
- a real Slack client channel and handoff message;
- delivered Gmail intake and kickoff invitations;
- completed client intake requirements;
- a reconciled Calendly-style kickoff record with meeting details;
- a complete PostgreSQL audit trail.

## Open before the call

1. Dashboard: `http://localhost:3000`
2. n8n workflows: `http://localhost:5678/home/workflows`
3. Keep HubSpot, ClickUp, Google Drive, Slack, Gmail, and Calendly available in separate tabs if you want to open the external evidence.

## Six-minute walkthrough

### 1. Explain the purpose — 30 seconds

Start at the dashboard headline and say:

> This operating system takes a service client from a closed-won sales handoff to a verified, provisioned, kickoff-ready delivery engagement.

Use the Input → Process → Output panel to establish the business outcome before discussing technology.

### 2. Explain the orchestration — 60 seconds

Click each logo in the dark workflow map:

- HubSpot supplies the closed-won handoff.
- n8n validates, normalizes, and orchestrates the lifecycle.
- Stripe and DocuSign control commercial readiness.
- ClickUp, Drive, and Slack create the delivery environment.
- Gmail gathers client intake.
- Calendly records kickoff.
- PostgreSQL preserves state, audit history, failures, and SLA data.

Open n8n and show the published workflows grouped by intake, commercial readiness, provisioning, communication, kickoff, recovery, and operations.

### 3. Show the client outcome — 90 seconds

Find **Northstar Advisory - Showcase** in the ledger. Point out:

- Complete status and 100% progress;
- the green tool-by-tool logo strip;
- healthy SLA state;
- no remaining blocker.

Open the client drawer. Click the individual tool logos to explain what each provider completed. Open the ClickUp, Drive, and Slack resource links from the provisioned-resources section.

### 4. Show the controls — 60 seconds

Use another incomplete demo record to show:

- commercial holds;
- missing client requirements;
- at-risk or breached SLA states;
- provider-specific retry actions;
- the next expected system output.

Explain that retries target only the failed provider and preserve resources that already succeeded.

### 5. Show the client experience — 45 seconds

Open a record at **Awaiting client**, then open its intake form. Emphasize that:

- the link uses an opaque token;
- every requirement is tracked independently;
- reminders stop after completion;
- ordinary form fields explicitly reject passwords and secret keys.

### 6. Close on architecture and scope — 45 seconds

Explain that n8n execution history is not the system of record. PostgreSQL holds canonical lifecycle state, allowing the dashboard, retries, reminders, and SLA monitor to operate from the same truth.

Be explicit that this is a locally hosted portfolio system using provider sandbox, demo, or test environments. The integration effects are real; production traffic and measured customer savings are not claimed.

## Current integration status

| Provider | Showcase status |
| --- | --- |
| HubSpot | Credential and real deal-read access verified. The current service key is read-only, so the showcase record entered through the HubSpot-compatible closed-won n8n endpoint. |
| Stripe | Test API healthy; deposit event processed. |
| DocuSign | Demo OAuth healthy; agreement requirement recorded for the showcase lifecycle. |
| ClickUp | Real folder/list and tasks created. |
| Google Drive | Real client folder tree created. |
| Slack | Real client channel and message created. |
| Gmail | Real intake and kickoff messages delivered. |
| Calendly | Credential and event type healthy; kickoff state reconciled. |

## Pre-demo health check

```bash
docker compose ps
curl http://localhost:5678/healthz
curl -I http://localhost:3000
```

Provider health workflows are available in n8n with the prefix `00 — Health`.

## Safe demo rules

- Never show credential values or open n8n credential-edit screens while sharing your display.
- Use only records labeled **Showcase**, **Demo**, or **Verification**.
- Do not claim production adoption, production volume, or measured ROI.
- Describe external effects as sandbox/test integrations.
- Use the manager dashboard for the story and n8n only as implementation evidence.
