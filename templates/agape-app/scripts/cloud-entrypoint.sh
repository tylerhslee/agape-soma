#!/usr/bin/env bash
# agape-app entrypoint: seed the persistent Agape project dir from the image,
# then exec the service. Seeding is copy-if-missing so Studio edits to programs
# and the manifest survive restarts and new revisions; delete a file on the
# mount to re-seed it from the image.
set -e

# The app and studio containers boot concurrently against the same GCS mount;
# when both find a file missing, the slower cp loses GCS's write precondition
# (412 -> stale file handle). The winner's object is complete, so losing the
# race is success — only fail when the file truly did not materialize.
seed_file() {
  src="$1"; dst="$2"
  [ -f "$dst" ] && return 0
  if ! cp "$src" "$dst" 2>/dev/null; then
    if [ -f "$dst" ]; then
      echo "seed: $(basename "$dst") created concurrently by the peer service; keeping it"
    else
      echo "seed: failed to copy $(basename "$dst")" >&2
      return 1
    fi
  fi
}

if [ -n "${AGAPE_SEED_DIR:-}" ] && [ -n "${AGAPE_PROJECT_DIR:-}" ] && [ -d "$AGAPE_SEED_DIR" ]; then
  mkdir -p "$AGAPE_PROJECT_DIR/programs"
  seed_file "$AGAPE_SEED_DIR/agape.toml" "$AGAPE_PROJECT_DIR/agape.toml"
  for f in "$AGAPE_SEED_DIR"/programs/*.ag; do
    seed_file "$f" "$AGAPE_PROJECT_DIR/programs/$(basename "$f")"
  done
  echo "agape project ready at $AGAPE_PROJECT_DIR"
fi

exec "$@"
