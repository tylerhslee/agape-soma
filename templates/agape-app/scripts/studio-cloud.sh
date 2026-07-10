#!/usr/bin/env bash
# Serve Agape Studio over the persistent Agape project dir (Cloud Run).
# --live enables real providers; ANTHROPIC_API_KEY arrives from Secret Manager.
# STUDIO_ACCESS_TOKEN (also from Secret Manager) keeps the token stable across
# restarts — without it Studio mints a random token per boot.
set -e
AGAPE_TS_HOME="${AGAPE_TS_HOME:-/app/vendor/agape-ts}"
cd "${AGAPE_PROJECT_DIR:-/app/agape}"

ARGS=(studio --port "${PORT:-8080}" --live)
if [ -n "${STUDIO_ACCESS_TOKEN:-}" ]; then
  ARGS+=(--token "$STUDIO_ACCESS_TOKEN")
fi
exec node /app/node_modules/tsx/dist/cli.mjs "$AGAPE_TS_HOME/src/cli.ts" "${ARGS[@]}"
