# Slack → HubSpot synchronization handoff

Updated: 2026-09-03 (Asia/Dhaka)

## Goal

When `/onboard-client` is submitted in Slack, the system should:

1. acknowledge Slack within 3 seconds;
2. create the onboarding in PostgreSQL (current behavior);
3. upsert the HubSpot contact by email;
4. find or create the HubSpot company by name;
5. create a closed-won HubSpot deal associated with that contact and company.

## Verified current state

- n8n is running in Docker on local port `5678`.
- PostgreSQL is running and healthy on local port `55432`.
- The Slack intake workflow is active in n8n:
  - ID: `SlackIntake0001`
  - Name: `01A | Slack Intake | Create Client Onboarding`
- The production webhook path is `/webhook/slack-onboard-client`.
- ngrok is running and forwards to `http://localhost:5678`.
- Public webhook URL:

  `https://devotedly-overdrive-hexagram.ngrok-free.dev/webhook/slack-onboard-client`

- An external invalid-payload test returned HTTP 200 in 0.3449 seconds.
- Slack Socket Mode must remain disabled because this implementation uses an HTTP webhook.
- HubSpot credential already configured in n8n:
  - Credential type: `hubspotAppToken`
  - Credential ID: `CCvhDg3jfqJm79pK`
  - Credential name: `HubSpot Service Key account`
- PostgreSQL credential used by the workflow:
  - Credential ID: `pWvncY5EEynulaOP`
  - Credential name: `Postgres account`

## Successful Slack test

The Slack command already created this PostgreSQL onboarding:

- Client: `Test Company`
- Engagement/deal: `Full Automation`
- Status: `RECEIVED`
- Onboarding ID: `adb5d5f2-b746-4c4c-be82-d14d54a05326`
- Created at: `2026-09-02 19:08:38.755188+00`
- Source deal ID: `slack:T0BTF71R343:hossainuday@gmail.com:full-automation`

It does not appear in HubSpot because the current Slack workflow only writes to PostgreSQL. The existing HubSpot poller operates in the opposite direction: HubSpot → PostgreSQL.

## Repository file to change

`automation/workflows/01-slack-client-intake.json`

No workflow change was applied during the previous attempt. The environment's patch helper repeatedly failed before reading the file with:

`bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted`

Check before continuing:

```bash
git diff -- automation/workflows/01-slack-client-intake.json
```

## Required workflow topology

Keep the existing valid-input path through PostgreSQL and Slack acknowledgement:

```text
Slack Slash Command
  → Validate Slack Client
  → Client Input Valid
  → Create Onboarding Atomically
  → Build Slack Confirmation
  → Reply Privately in Slack
```

Continue from `Reply Privately in Slack` with HubSpot synchronization:

```text
Reply Privately in Slack
  → Prepare HubSpot Sync
  → Upsert HubSpot Contact
  → Find HubSpot Company
  → Resolve HubSpot Company
  → Company Missing?
      true  → Create HubSpot Company ┐
      false ─────────────────────────┤
                                    ↓
                         Build HubSpot Associations
                                    ↓
                            Create HubSpot Deal
```

Important: HubSpot nodes must run **after** `Reply Privately in Slack`. A Respond to Webhook node can continue to downstream nodes in n8n. This prevents HubSpot API latency from delaying Slack's HTTP acknowledgement.

The invalid-input branch should still go directly to `Reply Privately in Slack`. Because it has no `payload_base64`, it must not continue into HubSpot synchronization. Either use a separate response node for invalid input, or add an IF node after the response checking that `$('Validate Slack Client').item.json.valid` is true.

## Node specifications

### 1. Prepare HubSpot Sync (Code node)

```javascript
const input = $('Validate Slack Client').item.json;
const payload = JSON.parse(
  Buffer.from(input.payload_base64, 'base64').toString('utf8'),
);
const names = payload.primary_contact_name.trim().split(/\s+/);
const firstname = names.shift() || payload.primary_contact_name;

return [{
  json: {
    ...payload,
    firstname,
    lastname: names.join(' '),
    amount: String((payload.value_cents / 100).toFixed(2)),
    closedate: payload.closed_won_at,
  },
}];
```

### 2. Upsert HubSpot Contact (HTTP Request node)

- Authentication: Predefined Credential Type
- Credential type: `hubspotAppToken`
- Credential: `HubSpot Service Key account`
- Method: POST
- URL: `https://api.hubapi.com/crm/v3/objects/contacts/batch/upsert`
- Content type: raw JSON
- Body expression:

```javascript
{{ JSON.stringify({
  inputs: [{
    id: $json.primary_contact_email,
    idProperty: 'email',
    properties: {
      email: $json.primary_contact_email,
      firstname: $json.firstname,
      lastname: $json.lastname,
    },
  }],
}) }}
```

Expected contact ID: `$json.results[0].id`.

### 3. Find HubSpot Company (HTTP Request node)

- Authentication and credential: same as above
- Method: POST
- URL: `https://api.hubapi.com/crm/v3/objects/companies/search`
- Content type: raw JSON
- Body expression:

```javascript
{{ JSON.stringify({
  filterGroups: [{
    filters: [{
      propertyName: 'name',
      operator: 'EQ',
      value: $('Prepare HubSpot Sync').item.json.company_name,
    }],
  }],
  properties: ['name'],
  limit: 1,
}) }}
```

### 4. Resolve HubSpot Company (Code node)

```javascript
const existing = $json.results?.[0];
const source = $('Prepare HubSpot Sync').item.json;

return [{
  json: {
    ...source,
    company_id: existing?.id ? String(existing.id) : '',
    create_company: !existing?.id,
  },
}];
```

### 5. Company Missing (IF node)

Boolean condition:

```javascript
{{ $json.create_company }}
```

- True output → Create HubSpot Company
- False output → Build HubSpot Associations

### 6. Create HubSpot Company (HTTP Request node)

- Authentication and credential: same as above
- Method: POST
- URL: `https://api.hubapi.com/crm/v3/objects/companies`
- Content type: raw JSON
- Body expression:

```javascript
{{ JSON.stringify({
  properties: { name: $json.company_name },
}) }}
```

Connect its output to Build HubSpot Associations. Its company ID is `$json.id`.

### 7. Build HubSpot Associations (Code node)

```javascript
const source = $('Prepare HubSpot Sync').item.json;
const contact = $('Upsert HubSpot Contact').item.json.results?.[0];
const companyId = $json.id ?? $json.company_id;

if (!contact?.id) {
  throw new Error('HubSpot contact upsert did not return an ID');
}
if (!companyId) {
  throw new Error('HubSpot company resolution did not return an ID');
}

return [{
  json: {
    ...source,
    contact_id: String(contact.id),
    company_id: String(companyId),
  },
}];
```

### 8. Create HubSpot Deal (HTTP Request node)

- Authentication and credential: same as above
- Method: POST
- URL: `https://api.hubapi.com/crm/v3/objects/deals`
- Content type: raw JSON
- Body expression:

```javascript
{{ JSON.stringify({
  properties: {
    dealname: $json.deal_name,
    pipeline: 'default',
    dealstage: 'closedwon',
    amount: $json.amount,
    closedate: $json.closedate,
  },
  associations: [
    {
      to: { id: $json.contact_id },
      types: [{
        associationCategory: 'HUBSPOT_DEFINED',
        associationTypeId: 3,
      }],
    },
    {
      to: { id: $json.company_id },
      types: [{
        associationCategory: 'HUBSPOT_DEFINED',
        associationTypeId: 5,
      }],
    },
  ],
}) }}
```

HubSpot-defined association type IDs used here:

- Deal → Contact: `3`
- Deal → Company: `5`

Verify these against the portal if HubSpot rejects the association request.

## Important idempotency improvement

The contact is safely upserted, and the company is reused by exact name. Deal creation is not yet idempotent. Slack retries or repeatedly submitting the same command could create duplicate HubSpot deals.

Recommended production-safe solution:

1. Create a unique custom HubSpot deal property such as `onboarding_source_id`.
2. Before creating the deal, search HubSpot deals for:

   `onboarding_source_id = source_deal_id`

3. Reuse/update the existing deal if found; create only if absent.
4. Include `onboarding_source_id: $json.source_deal_id` in deal properties.

If custom properties are not desired, search by exact deal name plus associated company before creating, but this is less reliable.

## Owner mapping

The Slack input includes owner name/email, but the proposed minimum sync does not assign a HubSpot owner. To assign one:

1. Query `GET https://api.hubapi.com/crm/v3/owners/?email=<owner_email>`.
2. If an owner is found, include `hubspot_owner_id` in the deal properties.
3. Do not fail the entire sync when no matching HubSpot owner exists; leave the deal unassigned and record a warning.

## HubSpot private-app scopes required

Confirm that `HubSpot Service Key account` has at least:

- `crm.objects.contacts.read`
- `crm.objects.contacts.write`
- `crm.objects.companies.read`
- `crm.objects.companies.write`
- `crm.objects.deals.read`
- `crm.objects.deals.write`
- owner read access if owner mapping is added

The existing health workflow currently proves deal read access only; it does not prove write permissions.

## Deployment

Validate the JSON first:

```bash
jq empty automation/workflows/01-slack-client-intake.json
```

Import the workflow into the running n8n container:

```bash
docker compose exec -T n8n n8n import:workflow --input=/files/workflows/01-slack-client-intake.json
```

Restart n8n so the active production webhook uses the imported version:

```bash
docker compose restart n8n
```

Then verify activation in logs:

```bash
docker compose logs --since=5m n8n
```

Look for:

`Activated workflow "01A | Slack Intake | Create Client Onboarding" (ID: SlackIntake0001)`

Note: exported repository JSON currently contains `"active": false`, while the database copy is active. After import, open n8n and ensure the workflow is published/active. Do not assume importing preserves activation.

## Testing

Use a new unique email/deal name to avoid confusing the result with the existing test:

```text
/onboard-client Acme Sync Test | Jane Test | jane+slacksync@example.com | Slack HubSpot Sync Test | 1000 | Existing HubSpot Owner | owner@example.com
```

Expected results:

1. Slack immediately returns the onboarding confirmation.
2. PostgreSQL/dashboard shows Acme Sync Test with status `RECEIVED`.
3. HubSpot Contacts shows `jane+slacksync@example.com`.
4. HubSpot Companies shows `Acme Sync Test`.
5. HubSpot Deals shows `Slack HubSpot Sync Test` as closed-won.
6. The deal is associated with the contact and company.

Inspect n8n executions if HubSpot objects do not appear. Common errors:

- `403`: private app lacks write scopes.
- `400 Property values were not valid`: `default`/`closedwon` are not the portal's internal pipeline/stage IDs.
- Association error: verify association type IDs.
- Contact batch upsert error: portal/token may not permit batch upsert; fall back to contact search by email followed by create/update.

## Existing unrelated runtime warnings

These were observed but are unrelated to Slack/HubSpot sync:

- Python task runner missing in the n8n image.
- Duplicate reminder key violations from the reminder workflow.
- PostgreSQL 16 compatibility warning from n8n 2.36.8.
