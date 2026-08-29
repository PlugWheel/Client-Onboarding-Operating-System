# n8n automation workspace

Committed workflows live in `workflows/` and are imported into n8n through the editor or CLI. Credentials and secrets never belong in exported JSON.

Current workflows:

- `01 — Intake — HubSpot Closed-Won`: validates and normalizes a HubSpot-compatible event, then calls the atomic onboarding database function.
- `03 — Commercial — Stripe Payment Event`: records deposit success/failure and reevaluates the commercial gate.
- `04 — Commercial — PandaDoc Contract Event`: records signed/declined contracts and reevaluates the commercial gate.
- `05 — Provisioning — Create Delivery Environment`: creates simulated ClickUp, Drive, and Slack resources with optional failure injection.
- `11 — Intake — Missing-Item Reminder Cycle`: processes due client-intake reminders hourly.
- `12 — Kickoff — Calendly Booking Event`: records kickoff and generates template-driven delivery tasks.
- `13 — Kickoff — Complete Onboarding`: closes a kickoff-scheduled onboarding at 100%.
- `14 — Operations — SLA Monitor and Escalation`: detects SLA breaches and records manager escalations hourly.
- `15 — Operations — Retry Provisioning Step`: retries a failed provider step without duplicating successful resources.
- `99 — Operations — Global Error Handler`: normalizes terminal workflow failures; the notification destination is added during provisioning.

## Naming convention

`NN — Domain — Action`

- `01–19`: inbound events and normalization
- `20–39`: commercial readiness
- `40–59`: provisioning subworkflows
- `60–79`: intake, reminders, and kickoff
- `80–98`: SLA and operational maintenance
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
- Route terminal errors to `99 — Operations — Global Error Handler`.
- Use bounded retries: 3 attempts with increasing delays for transient provider errors.
- Write state transitions and external IDs to PostgreSQL before returning success.
- Never use n8n execution history as the business system of record.

## Tags

Apply one lifecycle tag (`intake`, `commercial`, `provisioning`, `kickoff`, `operations`) and one maturity tag (`draft`, `tested`, `production`) to every workflow.
