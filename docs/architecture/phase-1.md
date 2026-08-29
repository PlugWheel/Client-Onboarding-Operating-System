# Phase 1 architecture

## Responsibilities

| Component | Responsibility |
| --- | --- |
| Next.js dashboard | Manager-facing operational views and, later, controlled manual actions |
| PostgreSQL `app` schema | Canonical onboarding state, requirements, resources, and audit history |
| PostgreSQL `n8n` schema | n8n's internal execution and credential metadata |
| n8n | Event ingestion, orchestration, reminders, retries, and provider calls |
| External providers | Systems of record for CRM, payments, contracts, delivery, files, and messaging |

The dashboard and n8n share the database server but use separate schemas. The `app` schema is authoritative for orchestration state; workflow execution history is not.

## Lifecycle

`RECEIVED → VALIDATING → BLOCKED_COMMERCIAL | READY_TO_PROVISION → PROVISIONING → AWAITING_CLIENT → READY_FOR_KICKOFF → KICKOFF_SCHEDULED → COMPLETE`

Exceptional states are `PROVISIONING_PARTIAL`, `NEEDS_REVIEW`, `INTEGRATION_FAILED`, and `CANCELLED`.

## Phase 1 boundary

Phase 1 intentionally uses deterministic data in the dashboard. Phase 2 will add a dashboard data-access layer and the first closed-won event workflow without requiring the interface to be redesigned.

