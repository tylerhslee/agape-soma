# The agape-app kit — app-side files

Terraform provisions the infrastructure (`modules/agape-app`); these files are
the app-side half of the pattern. Copy them into your repo and adapt the
marked spots. The reference implementation is league-analyzer's coach.

## Replicating the pattern for a new app (e.g. Whale, agape-fact-checker)

1. **Vendor the Agape runtime** into your repo:

   ```sh
   rsync -a --exclude node_modules --exclude .git --exclude conformance --exclude test \
     ~/_projects/agape/agape-ts/ vendor/agape-ts/
   ```

2. **Add your Agape project** at `agape/`: `agape.toml` (provider, host tool
   bindings, ingress screening attestations, markdown memory) and
   `programs/*.ag`. Your server embeds agape-ts in-process
   (`parse`/`createSession`/`sendPrompt`) and registers only NON-COGNITIVE
   `toolHandlers` — league-analyzer's `src/server/agapeHost.ts` is the model.
   Read the Agape project dir from `AGAPE_PROJECT_DIR` (fall back to
   `./agape` locally) so cloud and local resolve the same way.

3. **Copy this kit** into your repo: `Dockerfile` (adapt the build/start
   commands), `scripts/cloud-entrypoint.sh`, `scripts/studio-cloud.sh`,
   `cloudbuild.yaml`, `scripts/deploy-gcp.sh` (set `APP_NAME`). Add
   `vendor/agape-ts/node_modules`, `.env`, and `agape/.agape` to
   `.dockerignore` / `.gcloudignore`.

4. **Terraform root** (`deployments/gcp/dev/main.tf`):

   ```hcl
   module "agape_app" {
     source     = "git::https://github.com/tylerhslee/agape-soma.git//modules/agape-app?ref=v0.3.0"
     project_id = var.project_id
     region     = var.region
     name       = var.name

     app_image    = var.app_image
     studio_image = var.studio_image
     iap_members  = var.iap_members

     # enable_cloud_sql = true            # if your app needs Postgres
     # extra_secret_names = ["plaid-secret"]
     # app_secret_env = { PLAID_SECRET = "plaid-secret" }
     # agape_dir_env_var = "WHALE_AGAPE_DIR"   # if your host reads a custom name
   }
   ```

5. **Secrets are a project concern**: put `ANTHROPIC_API_KEY=...` in your
   project's `.env` (gitignored). The deploy script versions it into Secret
   Manager; in cloud it arrives as an env var — no `.env` ships anywhere.

6. **Deploy**: `PROJECT_ID=... SUPPORT_EMAIL=... IAP_MEMBER=user:... bash scripts/deploy-gcp.sh`

## What you get

- `<name>-app` — your application, IAP-gated, Agape runtime embedded.
- `<name>-studio` — Agape Studio (editor, orchestration graph, ledger,
  provider menu, `--live`), IAP-gated. Open `studio_uri` directly — IAP is the
  auth; Studio's own token gate is off by default. Set
  `studio_require_token = true` on the module for defense-in-depth (then
  append `?token=` from
  `gcloud secrets versions access latest --secret <name>-studio-access-token`).
- One persistent Agape project at `/data/agape` shared by both services:
  **Studio edits are what the app executes**, and the knowledge substrate
  survives restarts and redeploys (entrypoint seeding is copy-if-missing).
