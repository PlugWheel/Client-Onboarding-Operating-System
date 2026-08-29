# Credential setup — user actions

Create credentials directly in n8n at `http://localhost:5678`. Never paste access tokens, OAuth secrets, signing secrets, or private keys into chat.

## Setup order

Configure one provider at a time in this order:

1. HubSpot
2. Stripe
3. PandaDoc
4. ClickUp
5. Google Drive
6. Slack
7. Calendly
8. Email delivery

After each credential tests successfully, report only the credential name and requested non-secret IDs.

## 1. HubSpot

Create a HubSpot service key/private app in a test account with the minimum scopes needed to read deals, companies, contacts, owners, pipelines, and associations. Create the HubSpot credential in n8n.

Current local credential: `HubSpot Service Key account` (verified 2026-08-29).

Do not send the private-app token. Report:

- Credential test succeeded: yes/no
- Pipeline ID
- Closed-won stage ID
- Deal property used for service-template selection
- One test deal ID, if available

## 2. Stripe

Current local credential: `Stripe account` (verified 2026-08-29). Local signed events are
forwarded by the official Stripe CLI container to the n8n webhook. The verified test convention is
PaymentIntent metadata `source_deal_id=<HubSpot deal ID>`.

Use Stripe test mode. Create the Stripe credential in n8n and name it:

`Stripe Test — Client Onboarding OS`

Store the webhook signing secret in n8n or deployment secrets. Do not send either secret. Report:

- Credential test succeeded: yes/no
- Payment object used: PaymentIntent or Checkout Session
- Metadata key that will carry `onboarding_id` or `source_deal_id`

## 3. PandaDoc

Use a PandaDoc sandbox or development workspace. Create the credential in n8n and name it:

`PandaDoc Sandbox — Client Onboarding OS`

Report:

- Credential test succeeded: yes/no
- Template ID
- Metadata or field used to carry the onboarding correlation ID

## 4. ClickUp

Create the ClickUp credential in n8n and name it:

`ClickUp — Client Onboarding OS`

Report:

- Credential test succeeded: yes/no
- Workspace/team ID
- Space ID
- Folder/List or template ID
- Test assignee user IDs and their onboarding roles

## 5. Google Drive

Connect Google Drive using OAuth2 in n8n and name it:

`Google Drive — Client Onboarding OS`

Report:

- Credential test succeeded: yes/no
- Parent client-folder ID
- Document-template folder ID
- Intended sharing rule

## 6. Slack

Install a Slack app in a test workspace with the minimum channel-management, membership, and messaging scopes. Name the credential:

`Slack — Client Onboarding OS`

Report:

- Credential test succeeded: yes/no
- Workspace/team ID
- Channel prefix, such as `client-`
- Test staff user IDs
- Operations-alert channel ID

## 7. Calendly

Create the Calendly credential in n8n and name it:

`Calendly — Client Onboarding OS`

Report:

- Credential test succeeded: yes/no
- Event type URI
- Scheduling owner URI

## 8. Email delivery

Choose one approved sender: Resend, Gmail, Microsoft Outlook, or SMTP. Name it:

`Email — Client Onboarding OS`

Report:

- Credential test succeeded: yes/no
- Sender name
- Sender address
- Reply-to address
# Credential verification

After saving the HubSpot credential in n8n, run `00 — Health — HubSpot Connection` or open
`http://localhost:5678/webhook/health/hubspot`. A successful check verifies read-only deal access
and marks HubSpot as healthy in the dashboard integration registry. It does not expose or persist
the service key outside n8n's encrypted credential store.
