#!/usr/bin/env bash
set -euo pipefail

# Creates the local CA and the wildcard certificate when bootstrapping a host
# WITHOUT migrating data/ from the old one - i.e. when the CA private key
# (data/certs/ca/rasputinCA.key, never committed) is gone. The committed
# rasputinCA.crt can then no longer sign anything, because a cert without its
# key is useless.
#
# With the old key in place this is a no-op: use scripts/renew-certs.sh for
# the leaf certificate and leave the CA alone.
#
# Usage: bash scripts/init-ca.sh   (after scripts/render.sh, needs .env)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CA_DIR="$REPO_ROOT/data/certs/ca"
CA_KEY="$CA_DIR/rasputinCA.key"
CA_CRT="$CA_DIR/rasputinCA.crt"
# The CA cert is public config: committed, and served to LAN clients by
# cert-server. Keep it in sync with the key or trust breaks.
COMMITTED_CRT="$REPO_ROOT/services/apps/cert-server/ca/rasputinCA.crt"
DAYS=3650

if [[ -f "$CA_KEY" ]]; then
  echo "Local CA already present: data/certs/ca/rasputinCA.key"
  echo "Issue or renew the wildcard leaf with: bash scripts/renew-certs.sh"
  exit 0
fi

if [[ -f "$CA_CRT" ]]; then
  echo "warning: found data/certs/ca/rasputinCA.crt without its key." >&2
  echo "         The key is not in git, so that CA cannot sign anything." >&2
  echo "         Generating a new CA; every device must trust it again." >&2
fi

mkdir -p "$CA_DIR"

echo "==> Generating a new $DAYS-day local CA"
openssl req -x509 -newkey rsa:4096 -sha256 -days "$DAYS" -nodes \
  -keyout "$CA_KEY" -out "$CA_CRT" \
  -subj "/C=DE/O=Rasputin Inc./CN=Rasputin Internal CA" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign"
chmod 600 "$CA_KEY"

install -m 644 "$CA_CRT" "$COMMITTED_CRT"

# renew-certs.sh signs against the committed CA cert, hence the copy above.
echo "==> Issuing the wildcard leaf certificate"
bash "$SCRIPT_DIR/renew-certs.sh" --force

echo
echo "==> Action required: commit the new CA cert"
echo "      git add services/apps/cert-server/ca/rasputinCA.crt"
echo "    The clone is force-checked out on every playbook run, so an"
echo "    uncommitted cert is reverted while the leaf stays signed by this CA."
echo
echo "    Install this cert on each device (served at https://certs.<domain>):"
openssl x509 -in "$CA_CRT" -noout -fingerprint -sha256 | sed 's/^/      /'
