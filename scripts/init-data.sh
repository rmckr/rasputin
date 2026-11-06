#!/usr/bin/env bash
set -euo pipefail

# Creates the host paths the stacks bind-mount, so a fresh host works without
# rsyncing data/ from an old one.
#
# Two things Docker gets wrong on its own:
#   - it creates a missing bind-mount *source* as a root-owned directory, even
#     when the mount target is a file (traefik's acme.json, wg-easy's wg0.json);
#   - the root-owned directories it creates are unwritable by the images that
#     drop to ${HOMELAB_PUID}:${HOMELAB_PGID}.
#
# Idempotent: creates only what is missing, and repairs a directory that was
# created where a file belongs.
#
# Usage: bash scripts/init-data.sh   (after scripts/render.sh, needs .env)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$REPO_ROOT/data"
ENV_FILE="$REPO_ROOT/.env"

# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

PUID="${HOMELAB_PUID:?error - run scripts/render.sh first}"
PGID="${HOMELAB_PGID:?error - run scripts/render.sh first}"

# Images that run as ${HOMELAB_PUID}:${HOMELAB_PGID} (see the PUID/PGID env
# vars in services/*/*/compose.yaml) need to own their data directory.
PRIVILEGED=(code-server syncthing wireguard-client)
# Everything else runs as root or fixes up its own ownership (influxdb chowns
# /var/lib/influxdb2 on first boot), so a plain root-owned directory is fine.
PLAIN=(
  homeassistant dockhand matterjs-server
  influxdb traefik certs/internal certs/ca
  wireguard dovecot/mail dovecot/indexes
  rspamd rspamd-redis
)

echo "==> Directories"
for dir in "${PLAIN[@]}"; do
  mkdir -p "$DATA_DIR/$dir"
  echo "  dir   data/$dir"
done
for dir in "${PRIVILEGED[@]}"; do
  mkdir -p "$DATA_DIR/$dir"
  chown -R "$PUID:$PGID" "$DATA_DIR/$dir"
  echo "  dir   data/$dir (owned by $PUID:$PGID)"
done

echo "==> File bind-mount sources"
# Docker would create these as empty directories, which breaks the mount and
# (for wg0.json) then stops wg-easy from ever writing its config there.
for file in traefik/acme.json wireguard/wg0.json; do
  path="$DATA_DIR/$file"
  if [[ -d "$path" ]]; then
    # Fails if not empty - inspect by hand rather than rm -rf unknown data.
    rmdir "$path"
    echo "  fix   data/$file was a directory"
  fi
  if [[ ! -e "$path" ]]; then
    printf '{}\n' > "$path"
    echo "  file  data/$file"
  fi
done
chmod 600 "$DATA_DIR/traefik/acme.json"

echo "==> Done: data/ is ready for the first stack deploy"
