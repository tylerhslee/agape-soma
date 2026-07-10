#!/usr/bin/env bash
# Serve Agape Studio over the persistent Agape project dir (Cloud Run).
# --live enables real providers; ANTHROPIC_API_KEY arrives from Secret Manager.
#
# Access: IAP authenticates every request in the agape-app pattern, so Studio's
# own token gate (built for unauthenticated tunnels) is disabled by passing an
# explicitly empty --token. Set studio_require_token = true on the module to
# add it back as defense-in-depth — the URL then needs ?token=….
set -e
AGAPE_TS_HOME="${AGAPE_TS_HOME:-/app/vendor/agape-ts}"
cd "${AGAPE_PROJECT_DIR:-/app/agape}"

exec node /app/node_modules/tsx/dist/cli.mjs "$AGAPE_TS_HOME/src/cli.ts" \
  studio --port "${PORT:-8080}" --live --token "${STUDIO_ACCESS_TOKEN:-}"
