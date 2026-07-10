#!/usr/bin/env bash
# agape-app standard deploy. Copy into your repo's scripts/ and set APP_NAME.
#
# Flow: foundation (APIs/registry/SA/bucket/secrets) -> secret versions
# (Anthropic key from the project .env, generated Studio token) -> IAP
# prerequisites -> seed bucket state (no-clobber) -> Cloud Build both images ->
# runtime apply -> URLs.
set -euo pipefail

APP_NAME="${APP_NAME:-myapp}"                # <-- set me (e.g. league, whale, factcheck)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ID="${PROJECT_ID:?set PROJECT_ID}"
REGION="${REGION:-us-west1}"
NAME="${NAME:-$APP_NAME-dev}"
SUPPORT_EMAIL="${SUPPORT_EMAIL:?set SUPPORT_EMAIL for the IAP consent screen}"
IAP_MEMBER="${IAP_MEMBER:?set IAP_MEMBER, e.g. user:me@example.com}"

GCLOUD="${GCLOUD:-gcloud}"
GSUTIL="${GSUTIL:-gsutil}"
TERRAFORM="${TERRAFORM:-terraform}"
DEPLOY_DIR="${DEPLOY_DIR:-$ROOT_DIR/deployments/gcp/dev}"

"$GCLOUD" config set project "$PROJECT_ID" >/dev/null
cd "$DEPLOY_DIR"

TAG="${IMAGE_TAG:-$(date +%Y%m%d-%H%M%S)}"
APP_IMAGE="$REGION-docker.pkg.dev/$PROJECT_ID/$NAME-containers/$APP_NAME-app:$TAG"
STUDIO_IMAGE="$REGION-docker.pkg.dev/$PROJECT_ID/$NAME-containers/$APP_NAME-studio:$TAG"

cat > terraform.local.auto.tfvars <<EOF
project_id   = "$PROJECT_ID"
region       = "$REGION"
name         = "$NAME"
app_image    = "$APP_IMAGE"
studio_image = "$STUDIO_IMAGE"
iap_members  = ["$IAP_MEMBER"]
EOF

# 1. Foundation (secrets exist after this).
"$TERRAFORM" init
"$TERRAFORM" apply -target=module.agape_app.module.foundation -auto-approve

# 2. Secret versions. The Anthropic key comes from the project's .env — a
# project concern, never part of the Agape deployment; never echoed.
ENV_FILE=""
for candidate in "$ROOT_DIR/.env" "$ROOT_DIR/../../../.env"; do
  if [[ -f "$candidate" ]]; then ENV_FILE="$candidate"; break; fi
done
if [[ -n "$ENV_FILE" ]] && grep -q '^ANTHROPIC_API_KEY=' "$ENV_FILE"; then
  grep '^ANTHROPIC_API_KEY=' "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d '"' | tr -d "'" | tr -d '[:space:]' |
    "$GCLOUD" secrets versions add "$NAME-anthropic-api-key" --data-file=- >/dev/null
  echo "Secret $NAME-anthropic-api-key: version added from $ENV_FILE"
else
  echo "WARNING: no ANTHROPIC_API_KEY in a project .env; Agape cognition will fail closed." >&2
fi
if ! "$GCLOUD" secrets versions list "$NAME-studio-access-token" --filter="state=ENABLED" --format="value(name)" 2>/dev/null | grep -q .; then
  head -c 24 /dev/urandom | base64 | tr -d '+/=' |
    "$GCLOUD" secrets versions add "$NAME-studio-access-token" --data-file=- >/dev/null
  echo "Generated Studio token (fetch: $GCLOUD secrets versions access latest --secret $NAME-studio-access-token)"
fi

# 3. IAP prerequisites (idempotent).
"$GCLOUD" iap oauth-brands create --application_title="$APP_NAME" \
  --support_email="$SUPPORT_EMAIL" --project="$PROJECT_ID" 2>/dev/null || true
CLOUDSDK_CORE_DISABLE_PROMPTS=1 "$GCLOUD" beta services identity create \
  --service=iap.googleapis.com --project="$PROJECT_ID" >/dev/null

# 4. Seed shared runtime state (no-clobber: cloud-evolved knowledge wins).
BUCKET="gs://$PROJECT_ID-$NAME-runtime-state"
if [[ -d "$ROOT_DIR/agape/.agape" ]]; then
  "$GSUTIL" -m cp -n -r "$ROOT_DIR/agape/.agape" "$BUCKET/agape/" >/dev/null 2>&1 || true
  echo "Seeded knowledge substrate to $BUCKET/agape/.agape"
fi

# 5. Build both images, then roll out.
"$GCLOUD" builds submit "$ROOT_DIR" \
  --config "$DEPLOY_DIR/cloudbuild.yaml" \
  --substitutions "_REGION=$REGION,_REPO=$NAME-containers,_APP=$APP_NAME,_IMAGE_TAG=$TAG"

"$TERRAFORM" apply -auto-approve
"$TERRAFORM" output

echo ""
echo "Open app_uri and studio_uri (Studio needs ?token=<studio-access-token>)."
