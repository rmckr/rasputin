#!/bin/bash
# renew-certs.sh
# Auto-renews the homelab wildcard certificate for ${HOMELAB_DOMAIN},
# signed by the local CA (rasputinCA).
# Usage: ./renew-certs.sh [--force]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Shared config (HOMELAB_DOMAIN) lives in the decrypted .env next to the
# repo root; render.sh produces it.
# shellcheck disable=SC1091
set -a; source "$SCRIPT_DIR/../.env"; set +a

ROOT_DIR="$SCRIPT_DIR/../data/certs"
CERT_DIR="$ROOT_DIR/internal"
DOMAIN="${HOMELAB_DOMAIN:?error}"
CERT="$CERT_DIR/$DOMAIN.crt"
KEY="$CERT_DIR/$DOMAIN.key"
CSR="$CERT_DIR/$DOMAIN.csr"
SAN_CONF="$CERT_DIR/rasputin_san.cnf"
# The CA cert is public config and lives in git (served by cert-server);
# the CA key is a secret and stays under data/certs/ca, never committed.
CA_CERT="$SCRIPT_DIR/../services/apps/cert-server/ca/rasputinCA.crt"
CA_KEY="$ROOT_DIR/ca/rasputinCA.key"
# -CAcreateserial writes the serial next to the CA cert, so pin it into
# data/ rather than letting it appear in the repo.
CA_SERIAL="$ROOT_DIR/ca/rasputinCA.srl"
PEM="$CERT_DIR/$DOMAIN.pem"
DAYS_LEFT=30   # Renew if less than 30 days left
VALIDITY=825   # TLS certificate validity in days
FORCE=0

# Check for --force option
if [ "$1" == "--force" ]; then
    FORCE=1
    echo "Force renewal enabled."
fi

mkdir -p "$CERT_DIR" "$ROOT_DIR/ca"

# Fail early and legibly rather than mid-openssl.
if [ ! -f "$CA_CERT" ]; then
    echo "error: CA cert not found at $CA_CERT" >&2
    echo "Copy the existing one into place: services/apps/cert-server/ca/rasputinCA.crt" >&2
    exit 1
fi
if [ ! -f "$CA_KEY" ]; then
    echo "error: CA key not found at $CA_KEY" >&2
    echo "The CA key is not in git - migrate it from the old host (see ansible/README.md)." >&2
    exit 1
fi

# Check if certificate exists and days left
if [ -f "$CERT" ] && [ "$FORCE" -eq 0 ]; then
    REMAINING=$(openssl x509 -enddate -noout -in "$CERT" | cut -d= -f2)
    REMAINING_SECONDS=$(date -d "$REMAINING" +%s)
    NOW_SECONDS=$(date +%s)
    DIFF_DAYS=$(( (REMAINING_SECONDS - NOW_SECONDS) / 86400 ))
    if [ "$DIFF_DAYS" -gt "$DAYS_LEFT" ]; then
        echo "Certificate is still valid for $DIFF_DAYS days. No renewal needed."
        exit 0
    fi
    echo "Certificate expires in $DIFF_DAYS days. Renewing..."
else
    echo "Certificate not found or force renewal requested. Generating new one..."
fi

# Generate server key
openssl genrsa -out "$KEY" 2048

# Generate CSR
openssl req -new -key "$KEY" -out "$CSR" -subj "/C=DE/O=Rasputin Inc./CN=$DOMAIN"

# Generate SAN config
cat > "$SAN_CONF" <<EOL
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = DE
O = Rasputin Inc.
CN = $DOMAIN

[v3_req]
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = *.$DOMAIN
EOL

# Sign CSR with CA
openssl x509 -req -in "$CSR" \
  -CA "$CA_CERT" -CAkey "$CA_KEY" -CAserial "$CA_SERIAL" -CAcreateserial \
  -out "$CERT" -days $VALIDITY -sha256 \
  -extfile "$SAN_CONF" -extensions v3_req

# Combine server cert + CA cert for Traefik / Chromium
cat "$CERT" "$CA_CERT" > "$PEM"

echo "Certificate renewed successfully!"
echo "Server key: $KEY"
echo "Server cert: $CERT"
echo "Combined PEM: $PEM"
