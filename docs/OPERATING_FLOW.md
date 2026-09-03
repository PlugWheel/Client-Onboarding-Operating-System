# Client onboarding operating flow

## Production sequence

1. Run `/onboard-client` in Slack. The onboarding is recorded and the company, contact, and closed-won deal are synchronized to HubSpot.
2. The system creates a client-specific Stripe payment link containing `payment_intent_data.metadata.onboarding_id` and emails it through Gmail after HubSpot synchronization.
3. Configure Stripe to send `payment_intent.succeeded` and `payment_intent.payment_failed` events to `/webhook/stripe-payment-event` on the public n8n URL.
4. A successful payment approves the deposit gate and automatically sends the configured DocuSign agreement. Retries reuse the existing envelope.
5. The DocuSign poller detects the completed signature. When both commercial gates are approved, provisioning starts automatically.
6. Provisioning creates a ClickUp folder/list/tasks, a Google Drive client folder tree, and an internal Slack channel. It then emails the secure intake form.
7. Submitting all intake fields moves the client to ready-for-kickoff and automatically emails the Calendly scheduling link.
8. The Calendly event or poller records the booking and creates the opening delivery tasks. The manager can then mark onboarding complete.

## ClickUp responsibilities

The automation creates a client folder, an `Onboarding Tasks` list, and three service-template tasks. The delivery lead should:

- assign each task to the responsible teammate;
- confirm due dates against the booked kickoff;
- attach or link the relevant Google Drive documents;
- complete the project charter, discovery, and stakeholder tasks;
- use ClickUp as the execution tracker after onboarding reaches 100%.

Google Drive stores documents and deliverables; ClickUp owns work, responsibility, deadlines, and task status.

## Demo controls

The dashboard's demo payment and signature buttons generate controlled provider-shaped events. They do not charge a card or create a real signature. The production path depends on real Stripe webhook metadata and the real DocuSign envelope-status poller.
