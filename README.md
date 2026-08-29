# Client Onboarding OS

**From closed-won to kickoff without manual admin.**

Client Onboarding OS coordinates commercial validation, workspace provisioning, client intake, missing-item reminders, kickoff scheduling, and onboarding SLA visibility.

## Integration status

The complete lifecycle runs locally through n8n and PostgreSQL. Real HubSpot sandbox deals enter
the system through an idempotent five-minute poller, and real Stripe sandbox PaymentIntents update
the commercial deposit gate through the Stripe CLI relay. DocuSign demo OAuth, template-driven
envelope sending, and completion polling provide the contract gate. Real ClickUp project/task,
Google Drive folder-tree, and Slack channel/message provisioning are connected with persistent
resource tracking and recovery. Gmail sends tracked intake invitations and missing-item reminders.
Calendly remains simulated.

Working lifecycle:

```text
Closed-won intake
→ contract and deposit gate
→ provisioning with partial-failure recovery
→ tokenized client intake
→ missing-item reminders
→ kickoff booking and generated tasks
→ SLA escalation
→ completed onboarding
```

## Phase 1

This foundation includes:

- A Next.js operations dashboard with deterministic demo data
- PostgreSQL onboarding schema, lifecycle types, audit history, and seed records
- Dockerized PostgreSQL and n8n
- An importable n8n global error-handler workflow
- Workflow naming, idempotency, retry, and payload conventions

## Start the dashboard

```bash
npm install
npm run dev
```

Open `http://localhost:3000`.

## Start PostgreSQL and n8n

```bash
cp .env.example .env
docker compose up -d
```

Open n8n at `http://localhost:5678`. On first launch, create the local owner account and import `automation/workflows/99-global-error-handler.json`.

PostgreSQL is exposed to the host on port `55432` by default to avoid colliding with commonly installed local PostgreSQL services. n8n connects to it internally on port `5432`.

The SQL files under `database/migrations/` run automatically only when the PostgreSQL volume is first created. Apply later migrations through a migration runner or `psql` rather than recreating the volume.

## Verify

```bash
npm run typecheck
npm run lint
npm run build
docker compose config --quiet
```

See [Phase 1 architecture](docs/architecture/phase-1.md) and [n8n conventions](automation/README.md).

## Test the closed-won webhook

Workflow `01 — Intake — HubSpot Closed-Won` exposes the production endpoint below after it is published:

```bash
curl -X POST http://localhost:5678/webhook/hubspot-closed-won \
  -H 'Content-Type: application/json' \
  --data-binary @automation/fixtures/hubspot-closed-won.json
```

Replaying the fixture is safe: the response returns `"duplicate": true` and the existing onboarding ID.

## Test commercial readiness

Send the payment first to confirm the onboarding remains commercially blocked, then send the signed contract to release it:

```bash
curl -X POST http://localhost:5678/webhook/stripe-payment-event \
  -H 'Content-Type: application/json' \
  --data-binary @automation/fixtures/stripe-payment-succeeded.json

curl -X POST http://localhost:5678/webhook/docusign-send-contract \
  -H 'Content-Type: application/json' \
  -d '{"onboarding_id":"YOUR_ONBOARDING_UUID"}'

# After the signer completes the envelope, run the poller immediately:
curl http://localhost:5678/webhook/docusign-contract-poller
```
