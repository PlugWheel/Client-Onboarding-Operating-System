# n8n automation workspace

Committed workflows live in `workflows/` and are imported into n8n through the editor or CLI. Credentials and secrets never belong in exported JSON.

Current workflows are named for the business outcome they produce:

- `00 | Connection Check | Provider`: verifies each configured provider before a showcase or production run (HubSpot, Stripe, DocuSign, ClickUp, Google Drive, Slack, Gmail, and Calendly).
- `01 | Sales Handoff | Receive Closed-Won Deal`: validates a HubSpot-compatible closed-won event and creates the onboarding record.
- `01A | Slack Intake | Create Client Onboarding`: accepts a structured `/onboard-client` command and creates the onboarding record directly from Slack.
- `02 | Sales Handoff | Sync HubSpot Closed-Won Deals`: polls HubSpot for newly won deals when webhooks are unavailable.
- `03 | Commercial Gate | Record Stripe Payment`: records deposit success or failure and reevaluates readiness.
- `03A | Commercial Gate | Create & Email Stripe Payment Link`: creates an onboarding-specific Stripe payment link and emails it to the client after HubSpot synchronization.
- `04A | Commercial Gate | Send DocuSign Agreement`: sends the onboarding agreement for signature.
- `04B | Commercial Gate | Check DocuSign Agreement`: checks agreement status and records completion.
- `04Z | Legacy Adapter | Receive PandaDoc Contract Event`: retains compatibility with the earlier PandaDoc implementation; it is not part of the primary showcase path.
- `05A | Workspace Setup | Create ClickUp, Drive & Slack`: provisions the delivery project, client folder, and communication channel.
- `05B | Workspace Recovery | Resume Drive & Slack Setup`: resumes incomplete provisioning without duplicating successful resources.
- `10 | Client Intake | Send Questionnaire Email`: sends the onboarding questionnaire and credential request.
- `11 | Client Intake | Send Missing-Item Reminders`: follows up on outstanding client inputs.
- `12A | Kickoff | Send Calendly Scheduling Email`: invites a ready client to book kickoff.
- `12B | Kickoff | Receive Calendly Booking`: receives a booking event and creates the initial delivery tasks.
- `12C | Kickoff | Sync Calendly Bookings`: polls Calendly when webhook delivery is unavailable.
- `13 | Onboarding | Mark Client Complete`: closes a kickoff-scheduled onboarding at 100%.
- `14 | Operations | Monitor SLA & Escalate`: detects SLA risk and records manager escalations.
- `15 | Operations | Retry Failed Provisioning`: retries a failed provider step without duplicating successful resources.
- `99 | Operations | Handle Workflow Errors`: normalizes terminal failures for operations notification.

## Naming convention

`NN[A-Z] | Business stage | Plain-English outcome`

- `00`: provider connection checks
- `01–04`: sales handoff and commercial readiness
- `05`: delivery workspace provisioning and recovery
- `10–13`: client intake, kickoff, and completion
- `14–15`: SLA and operational maintenance
- `98`: archived or unused drafts
- `99`: global error handling

## Workflow contract

Every business workflow accepts and returns an object containing:

```json
{
  "onboarding_id": "uuid",
  "correlation_id": "provider-event-id or generated uuid",
  "triggered_at": "ISO-8601 timestamp"
}
```

Every mutating provider operation also requires an `idempotency_key`, formatted as:

`{onboarding_id}:{provider}:{operation}:{version}`

## Required workflow settings

- Save failed production executions and successful executions only while developing.
- Set workflow timezone explicitly to `Asia/Dhaka` unless the workflow operates in a client timezone.
- Route terminal errors to `99 | Operations | Handle Workflow Errors`.
- Use bounded retries: 3 attempts with increasing delays for transient provider errors.
- Write state transitions and external IDs to PostgreSQL before returning success.
- Never use n8n execution history as the business system of record.

## Tags

Apply one lifecycle tag (`intake`, `commercial`, `provisioning`, `kickoff`, `operations`) and one maturity tag (`draft`, `tested`, `production`) to every workflow.
