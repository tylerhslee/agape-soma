# Soma

Soma is Whale's cloud body: Terraform modules that turn Agape runtime concepts into managed infrastructure.

The current target is GCP. This is not the final "Terraform replaces Rust runtime" design yet. It is the first deployable cloud runtime shape where managed services carry the runtime responsibilities that are currently local files, local processes, and the Rust Agape binary in Docker.

## Runtime Components

- Sensory gateway: Cloud Run API service. Receives UI calls, Plaid callbacks, and explicit sync requests.
- Interface: Cloud Run UI service.
- Sensor sync: Cloud Run job scaffold for pulling external inputs such as Plaid transactions.
- Classifier agent: Cloud Run job scaffold for running Agape classifier passes over observed transactions.
- Signal bus: Pub/Sub topics for sensory events, transaction observations, classification requests, decision events, and ledger events.
- Memory/state: GCS bucket mounted at `/data` for Cloud Run services that need the current file-backed state implementation.
- Secrets: Secret Manager placeholders for Plaid and future model provider credentials.
- Studio: optional Cloud Run service for Agape Studio once a Studio image is available.

## Modules

- `modules/foundation`: project APIs, Artifact Registry, runtime service account, IAM, state bucket, and secret placeholders.
- `modules/runtime`: Cloud Run services/jobs, Pub/Sub runtime topics/subscriptions, scheduled sync, and optional Cloud SQL.

## Current Persistence Posture

Whale currently persists state through `WHALE_STATE_PATH`. Soma mounts a GCS bucket into the API service at `/data`, so the app can run in cloud before the state layer is migrated to Firestore, Cloud SQL, or an event-sourced ledger.

The scheduled dev path calls the API service's `/plaid/sync` endpoint, so sync and classification use the durable mounted state. The worker jobs are present as separate runtime organs, but they should be wired to Firestore/SQL/event state before they become the primary scheduled path.

That is acceptable for a dev/demo runtime. It is not the final production memory layer.
