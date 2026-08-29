# Client Onboarding OS — Project Completion Plan

## Portfolio headline

**Client Onboarding OS: From Closed-Won to Kickoff Without Manual Admin**

## Product purpose

Client Onboarding OS automates the operational handoff after a B2B services deal closes. It verifies commercial readiness, provisions the delivery environment, gathers client inputs, schedules kickoff, and gives managers a clear view of blockers, failures, and SLA risk.

## Selected stack

The primary implementation path is:

```text
HubSpot
→ n8n
→ Stripe + PandaDoc
→ ClickUp + Google Drive + Slack
→ Calendly
```

Supporting infrastructure:

- Next.js: manager dashboard and client intake portal
- PostgreSQL: canonical lifecycle state, audit history, failures, tasks, and SLA data
- Docker Compose: local n8n and PostgreSQL environment

GoHighLevel, DocuSign, Asana, and Microsoft Teams are future adapters. They are not required for the primary portfolio implementation.

## Current honest status

### Working locally

- Next.js manager dashboard
- PostgreSQL lifecycle and audit model
- Dockerized n8n and PostgreSQL
- Manual closed-won intake from the dashboard
- Published n8n workflows
- Idempotent client, deal, and onboarding creation
- Contract and deposit readiness logic
- Provisioning state, partial failure, and retry behavior
- Tokenized client intake portal
- Intake requirement tracking
- Reminder and SLA records
- Kickoff booking state
- Template-driven delivery task generation
- Closed-won-to-complete lifecycle verification

### Simulated external integrations

- HubSpot closed-won event
- Stripe payment event
- PandaDoc contract event
- ClickUp project and task creation
- Google Drive folder and document creation
- Slack channel and notification delivery
- Calendly booking event
- Reminder email delivery
- SLA notification delivery

The lifecycle is real; the external SaaS effects are not yet real.

## Definition of done

The project is complete only when all conditions below are satisfied.

1. A real HubSpot sandbox/test deal marked closed-won starts n8n automatically.
2. HubSpot webhook authenticity is verified.
3. A real Stripe test payment updates the deposit requirement.
4. Stripe webhook signatures are verified.
5. A real PandaDoc sandbox document completion updates the contract requirement.
6. PandaDoc webhook authenticity is verified where supported.
7. Commercial readiness releases provisioning only after every blocking requirement passes.
8. n8n creates a real ClickUp project/list and template-driven tasks.
9. n8n creates a real Google Drive folder tree and copies document templates.
10. n8n creates a real Slack channel, invites assigned staff, and sends the handoff message.
11. Provider IDs and URLs are stored in PostgreSQL and open correctly from the dashboard.
12. Partial provisioning failures can be retried without duplicating successful resources.
13. A real intake email is delivered to the client.
14. The client completes the tokenized intake form and reminders stop automatically.
15. Missing-item reminders and SLA escalations are delivered through a real channel.
16. A real Calendly booking updates the onboarding and creates initial ClickUp tasks.
17. The dashboard shows lifecycle state, requirements, resources, audit events, failures, SLA, kickoff, and completion.
18. Secrets are stored in n8n credentials or deployment secrets, never workflow JSON or Git.
19. Automated tests cover duplicates, out-of-order events, failures, retries, and invalid signatures.
20. The system has deployment, backup, recovery, and operating documentation.

## Delivery phases

### Phase A — Configuration and security foundation

Status: In progress. HubSpot credential verification completed on 2026-08-29; the remaining
provider credentials and webhook-security work are still pending.

User/account work:

- Create or select sandbox/test accounts for every provider.
- Create provider apps, tokens, OAuth connections, and webhook secrets.
- Enter credentials directly inside n8n.
- Provide non-secret IDs such as HubSpot pipeline/stage, ClickUp workspace, Drive template folder, Slack workspace/channel prefix, and Calendly event type.

Engineering work:

- Add credential-health checks. (HubSpot complete; remaining providers pending.)
- Add environment validation.
- Add webhook signature verification before payload normalization.
- Add provider configuration tables without storing secrets.
- Remove remaining n8n 2.x deprecation warnings.
- Plan PostgreSQL 16 to 17+ migration for production.

Acceptance criteria:

- Every credential tests successfully in n8n.
- Invalid or unsigned webhook requests are rejected.
- No secret appears in Git, logs, fixtures, screenshots, or dashboard responses.

### Phase B — HubSpot sales handoff

Status: Core ingestion complete in sandbox on 2026-08-29. The service-key integration polls
HubSpot every five minutes, enriches Closed Won deals with contact, company, and owner data,
and creates onboarding records idempotently. Dashboard source attribution and the real deal link
remain pending.

🟧 n8n work:

- Replace the simulated HubSpot fixture with a real HubSpot trigger. (Completed using an
  authenticated five-minute poller; a developer-app webhook can replace it later if required.)
- Verify the signature and subscription metadata.
- Fetch associated company, contact, and owner. (Complete; line-item/service-template mapping pending.)
- Map the closed-won stage to the canonical payload. (Complete.)
- Preserve the current idempotency and atomic database transaction. (Complete and repeat-tested.)
- Return a fast webhook acknowledgement and process safely.

Dashboard work:

- Display the real HubSpot deal link.
- Identify whether a record came from HubSpot or manual intake.

Acceptance test:

- Marking one HubSpot test deal closed-won creates exactly one onboarding with the correct owner, contact, value, and service template.

### Phase C — Stripe and PandaDoc commercial gate

Status: Stripe sandbox integration completed and tested on 2026-08-29. A real test-mode
PaymentIntent carrying `source_deal_id` was forwarded by Stripe CLI, processed by n8n, and marked
the deposit Approved. PandaDoc remains pending.

🟧 n8n work:

- Connect the Stripe test credential. (Complete.)
- Verify Stripe signatures using the raw request body.
- Correlate Stripe objects using `onboarding_id` or `source_deal_id` metadata.
- Connect PandaDoc sandbox credentials and webhook.
- Fetch document state when webhook payloads are insufficient.
- Handle payment failure, refund, contract decline, void, and correction events.
- Preserve out-of-order processing and replay safety.

Dashboard work:

- Show contract and deposit provider IDs, event times, and verified state.
- Show why a commercial gate is blocked.

Acceptance test:

- Provisioning remains blocked with only one approved requirement and releases automatically when both are approved.

### Phase D — Real delivery provisioning

🟧 n8n parent workflow:

- Load client, deal, owner, template, and configuration from PostgreSQL.
- Set onboarding to `PROVISIONING`.
- Execute provider subworkflows independently.
- Store every provider result before moving to the next lifecycle stage.
- Route terminal errors to workflow `99`.

🟧 ClickUp subworkflow:

- Create project/folder/list from the selected service template.
- Create template-driven tasks.
- Assign tasks from role mappings.
- Store ClickUp IDs and URLs.
- Use deterministic resource keys to prevent duplicates.

🟧 Google Drive subworkflow:

- Create the configured folder tree.
- Copy approved document templates.
- Set appropriate sharing permissions.
- Store folder and document IDs and URLs.
- Avoid exposing files publicly.

🟧 Slack subworkflow:

- Create a normalized client channel name.
- Invite assigned staff.
- Post the sales-to-delivery summary and resource links.
- Store the channel ID and URL.

🟧 Retry workflow:

- Retry only failed provider steps.
- Skip successful provider operations.
- Reuse existing provider resources when found.
- Resolve failure records after successful recovery.

Dashboard work:

- Replace simulated resource labels with live integration status.
- Open real ClickUp, Drive, and Slack links.
- Show attempts, errors, retry controls, and timestamps.
- Remove the failure-simulation control from production mode.

Acceptance test:

- A forced single-provider failure results in `PROVISIONING_PARTIAL`; retry completes only that provider without duplicating the other resources.

### Phase E — Client intake and communication

🟧 n8n work:

- Connect a real email provider or approved Gmail account.
- Send the tokenized intake link after successful provisioning.
- Send reminders at configured business-hour intervals.
- Stop reminders immediately after completion.
- Escalate overdue intake internally through Slack and email.
- Record delivery IDs and failures.

Application work:

- Add expiry and resending controls.
- Add accessible field validation and completion confirmation.
- Never collect passwords in ordinary form fields.
- Integrate an approved secure credential-sharing method.

Acceptance test:

- The client receives an email, completes intake, pending requirements clear, reminders cancel, and status becomes `READY_FOR_KICKOFF`.

### Phase F — Calendly kickoff and delivery handoff

🟧 n8n work:

- Connect Calendly credentials and webhook subscription.
- Include `onboarding_id` in booking tracking metadata.
- Verify and normalize invitee-created and cancellation events.
- Create kickoff agenda and initial ClickUp tasks.
- Notify the Slack channel and assigned staff.
- Handle rescheduling and cancellation.

Dashboard work:

- Show kickoff date, timezone, attendees, and meeting link.
- Show generated delivery tasks.
- Allow authorized completion after kickoff.

Acceptance test:

- A real Calendly test booking updates the dashboard, creates tasks, posts to Slack, and can complete onboarding at 100%.

### Phase G — Dashboard, audit, and operations hardening

Application work:

- Add authentication.
- Add manager and operator roles.
- Add full onboarding timeline.
- Add completed and cancelled views.
- Add integration-health page.
- Add accessible confirmation dialogs for mutations.
- Add pagination and server-side filtering.
- Add real trend calculations instead of illustrative values.

🟧 n8n work:

- Send global failures to a real Slack/email operations destination.
- Add dead-letter review and replay procedure.
- Add workflow timeouts and retry policies per provider.
- Add execution-data retention appropriate to sensitive information.

Acceptance criteria:

- Managers can identify the owner, blocker, next action, failure, resource, and SLA state for any onboarding without opening n8n.

### Phase H — Testing, deployment, and portfolio case study

Testing:

- Unit tests for lifecycle transitions and payload validation.
- Integration tests for database functions and dashboard routes.
- Recorded webhook fixtures for every provider.
- End-to-end tests for happy path, duplicate events, out-of-order events, provider failure, retry, reminder cancellation, reschedule, and completion.

Deployment:

- Production Docker or managed n8n architecture.
- Public HTTPS domains for dashboard and webhooks.
- PostgreSQL backup and restore procedure.
- Secret rotation procedure.
- Health checks and uptime monitoring.
- Separate test and production credentials.

Portfolio assets:

- Architecture diagram.
- Ninety-second demo script.
- Before/after business-process comparison.
- Screenshots of every major lifecycle stage.
- Metrics framed as test/demo outcomes unless measured in production.
- Clear disclosure of sandbox versus live integrations.

## Implementation order

Work should proceed in this order:

1. Phase A: credentials, configuration, and webhook security
2. Phase B: real HubSpot trigger
3. Phase C: real Stripe and PandaDoc gate
4. Phase D: ClickUp, Google Drive, and Slack provisioning
5. Phase E: intake delivery and reminders
6. Phase F: Calendly and kickoff tasks
7. Phase G: authentication and operational hardening
8. Phase H: automated tests, deployment, and case study

This order gives one complete real integration path before adding optional provider alternatives.

## Required user inputs before implementation

Do not put secrets in chat. Create credentials directly in n8n and provide only confirmation plus non-secret identifiers.

| Provider | User action | Non-secret configuration to share |
| --- | --- | --- |
| HubSpot | Create private app and n8n credential | Pipeline ID, closed-won stage ID, service-template property |
| Stripe | Connect test credential and webhook secret in n8n | Test price/payment flow and metadata convention |
| PandaDoc | Connect sandbox credential | Template ID and webhook event names |
| ClickUp | Connect API credential | Workspace, Space, Folder/List, template IDs |
| Google Drive | Connect OAuth2 | Parent folder and template folder IDs |
| Slack | Install OAuth app in test workspace | Workspace, staff user IDs, channel prefix |
| Calendly | Connect token and webhook | Event type URI and scheduling owner |
| Email | Connect approved sender | Sender name, sender address, reply-to address |

## Decisions locked for the primary build

- HubSpot instead of GoHighLevel
- PandaDoc instead of DocuSign
- ClickUp instead of Asana
- Slack instead of Microsoft Teams
- Provider alternatives remain adapter documentation until the primary path passes end-to-end tests
- PostgreSQL remains the canonical orchestration state
- n8n remains the automation engine

## Completion evidence

At final handoff, the repository must contain:

- Exported sanitized n8n workflow JSON
- Database migrations and deterministic seed data
- Automated tests and test fixtures
- Environment-variable documentation
- Integration setup guides
- Failure and recovery runbooks
- Deployment and backup guide
- Architecture documentation
- Portfolio case study and demo script
- A final matrix identifying every integration as simulated, sandbox, or production-ready
