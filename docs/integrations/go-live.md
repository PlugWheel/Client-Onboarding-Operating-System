# External integration go-live checklist

The local product is functionally complete with simulated provider adapters. Activate real providers one at a time in n8n.

## Required credentials

- HubSpot private app token and webhook subscription
- Stripe test secret plus webhook signing secret
- PandaDoc sandbox API key and webhook secret
- ClickUp API token, workspace ID, and template/list IDs
- Google OAuth2 credential with Drive access and template-folder ID
- Slack OAuth2 app with channel-management and messaging scopes
- Calendly personal access token and webhook subscription

Store credentials only in n8n. Never place them in workflow JSON, `.env.example`, fixtures, screenshots, or repository history.

## Adapter replacement rule

Keep the database function contracts unchanged. Replace the simulated provider node with the real API node, then send its external ID and URL into the existing provisioning-step write. This preserves retries, lifecycle state, dashboard output, and audit history.

## Production requirements

- Verify every provider webhook signature before normalization.
- Replace demo resource URLs with provider-returned URLs.
- Add a real email or Slack delivery node to reminder and escalation workflows.
- Configure a public HTTPS webhook base URL.
- Rotate the n8n encryption key and database password.
- Upgrade PostgreSQL to the n8n-supported production version.
- Add application authentication and role-based access before exposing the dashboard.

