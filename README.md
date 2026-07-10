# Soma

Soma is a small, app-neutral Terraform layer for deploying containerized apps to
GCP Cloud Run. It began as Whale's cloud body (Agape/Plaid-specific), and as of
**v0.2.0** the runtime is fully generic: an app declares the services, jobs,
topics, subscriptions, schedulers, and secrets it needs, and Soma builds them.

Nothing app-specific (Plaid, Agape, classifiers, a fixed set of topics) is baked
in anymore — those are just values a caller passes.

## Modules

- `modules/foundation`: project API enablement, Artifact Registry, a runtime
  service account + IAM, an optional GCS state bucket, and Secret Manager
  placeholders. Secrets, extra APIs, and IAM roles are all caller-supplied.
- `modules/runtime`: Cloud Run **services** and **jobs**, Pub/Sub **topics** and
  **subscriptions**, Cloud **scheduler** jobs, and optional Cloud SQL — every
  group is a map that defaults to empty.
- `modules/agape-app` (**v0.3.2**): THE standard deployment for an
  Agape-powered application — the whole point of Agape + Soma, extracted from
  league-analyzer's coach. One call provisions the app service (Agape runtime
  embedded in-process) and **Agape Studio as the admin surface** (editor,
  orchestration graph, ledger, provider menu), both IAP-gated, sharing one
  **persistent Agape project** on the state mount (Studio edits are what the
  app executes; the knowledge substrate survives redeploys), with
  `ANTHROPIC_API_KEY` and a stable Studio access token in Secret Manager.
  The app-side half (Dockerfile targets, entrypoint seeding, deploy script)
  lives in `templates/agape-app/` — see its README for the 6-step recipe to
  replicate on any app (Whale, agape-fact-checker, ...).

## Versioning

Consume via a pinned git ref:

```hcl
module "foundation" {
  source = "git::https://github.com/tylerhslee/agape-soma.git//modules/foundation?ref=v0.2.0"
  # ...
}
```

- `v0.1.0` — Whale-specific runtime (fixed api/ui/studio/workers, Plaid/Agape env, hardcoded topics). Whale currently pins this.
- `v0.2.0` — generalized, data-driven runtime (this README).

## Minimal example (single service + state + one secret)

```hcl
module "foundation" {
  source       = "git::https://github.com/tylerhslee/agape-soma.git//modules/foundation?ref=v0.2.0"
  project_id   = var.project_id
  region       = var.region
  name         = "league-dev"
  secret_names = ["riot-api-key"]
}

module "runtime" {
  source                = "git::https://github.com/tylerhslee/agape-soma.git//modules/runtime?ref=v0.2.0"
  project_id            = var.project_id
  region                = var.region
  name                  = "league-dev"
  service_account_email = module.foundation.runtime_service_account
  state_bucket_name     = module.foundation.state_bucket_name

  services = {
    api = {
      image                 = "${module.foundation.artifact_repository_url}/app:latest"
      port                  = 8787
      mount_state           = true            # SQLite at /data
      allow_unauthenticated = true
      secret_env            = { RIOT_API_KEY = module.foundation.secret_ids["riot-api-key"] }
    }
  }
}
```

See `examples/` for a runnable minimal config (`examples/league-analyzer`) and a
full config exercising every building block (`examples/full-featured`).

## Runtime building blocks

Each is a map keyed by a short name; the resource name becomes `<name>-<key>`.

- **`services`** — Cloud Run services. Per-service knobs: `image`, `port`, `env`,
  `secret_env`, `cpu`/`memory`, `min_instances`/`max_instances`, `ingress`,
  `allow_unauthenticated`, `invoker_members`, `mount_state` (+ `state_mount_path`),
  `enable_iap` (+ `iap_members`), `attach_cloud_sql`.
- **`jobs`** — Cloud Run jobs. `image`, `env`, `secret_env`, `mount_state`,
  `attach_cloud_sql`.
- **`pubsub_topics`** / **`pubsub_subscriptions`** — a topic set and subscriptions
  that reference topics by key. Set `inject_topic_env = true` to auto-inject each
  topic id into every container as `SOMA_TOPIC_<UPPER_SNAKE>` (prefix configurable).
- **`scheduler_jobs`** — Cloud Scheduler jobs that make an OIDC-authenticated HTTP
  call to one of the services (`target_service` + `path`).
- **Cloud SQL** — set `enable_cloud_sql = true`; containers that opt in with
  `attach_cloud_sql = true` get the socket mounted and standard libpq env
  (`PGHOST`/`PGDATABASE`/`PGUSER`) plus a `PGPASSWORD` secret.

## Foundation building blocks

- **`secret_names`** — short names to create as `<name>-<secret_name>`; read the
  ids back from the `secret_ids` output map.
- **`additional_gcp_services`** — APIs to enable beyond the base set (run,
  artifactregistry, cloudbuild, iam, secretmanager, storage). Add pubsub,
  cloudscheduler, sqladmin, iap, firestore, etc. as the app uses them.
- **`runtime_roles`** — project IAM roles for the runtime service account
  (defaults to `roles/logging.logWriter`).
- **`enable_state_bucket`** — create the GCS state bucket (default true).

## State posture

The GCS state bucket mounted at `/data` is for apps still using file-backed state
(e.g. a SQLite file). Apps with a real database can set `enable_state_bucket = false`
and drop `mount_state`, or use the optional Cloud SQL instance.
