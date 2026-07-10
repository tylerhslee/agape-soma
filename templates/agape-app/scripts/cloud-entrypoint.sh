#!/usr/bin/env bash
# agape-app entrypoint: seed the persistent Agape project dir from the image,
# then exec the service. Seeding is copy-if-missing so Studio edits to programs
# and the manifest survive restarts and new revisions; delete a file on the
# mount to re-seed it from the image.
set -e

if [ -n "${AGAPE_SEED_DIR:-}" ] && [ -n "${AGAPE_PROJECT_DIR:-}" ] && [ -d "$AGAPE_SEED_DIR" ]; then
  mkdir -p "$AGAPE_PROJECT_DIR/programs"
  if [ ! -f "$AGAPE_PROJECT_DIR/agape.toml" ]; then
    cp "$AGAPE_SEED_DIR/agape.toml" "$AGAPE_PROJECT_DIR/agape.toml"
  fi
  for f in "$AGAPE_SEED_DIR"/programs/*.ag; do
    base="$(basename "$f")"
    if [ ! -f "$AGAPE_PROJECT_DIR/programs/$base" ]; then
      cp "$f" "$AGAPE_PROJECT_DIR/programs/$base"
    fi
  done
  echo "agape project ready at $AGAPE_PROJECT_DIR"
fi

exec "$@"
