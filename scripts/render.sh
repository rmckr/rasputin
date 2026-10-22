#!/usr/bin/env bash
set -euo pipefail

# Decrypts .env.enc (SOPS/age) to .env and renders templates/*.tmpl
# into .runtime/*. This is the only step Komodo cannot do natively.
# Auto-triggered by scripts/systemd/homelab-render.path and the
# post-merge git hook (scripts/hooks/post-merge); can be run manually.

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$REPO_ROOT/.env"
TEMPLATES_DIR="$REPO_ROOT/templates"
RUNTIME_DIR="$REPO_ROOT/.runtime"

if ! command -v sops &>/dev/null; then
  echo "Error: sops not found. Install it from https://github.com/getsops/sops" >&2
  exit 1
fi

if ! command -v envsubst &>/dev/null; then
  echo "Error: envsubst not found. Install it with: sudo apt install gettext-base" >&2
  exit 1
fi

# .env.enc is SOPS-encrypted (age backend), see .sops.yaml
export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/age/key.txt}"
sops --decrypt --input-type dotenv --output-type dotenv "$ENV_FILE.enc" > "$ENV_FILE"

if [[ ! -d "$TEMPLATES_DIR" ]]; then
  echo "Error: $TEMPLATES_DIR not found" >&2
  exit 1
fi

echo "==> Rendering templates"
# .env carries both shared config and secrets (see .sops.yaml for which
# keys are sealed); *.tmpl can reference either.
set -a; source "$ENV_FILE"; set +a
while IFS= read -r -d '' tmpl; do
  rel="${tmpl#"$TEMPLATES_DIR/"}"
  dst="$RUNTIME_DIR/${rel%.tmpl}"
  mkdir -p "$(dirname "$dst")"
  echo "  render  templates/$rel -> .runtime/${rel%.tmpl}"
  envsubst < "$tmpl" > "$dst"
done < <(find "$TEMPLATES_DIR" -name "*.tmpl" -print0)

echo "==> Done: $ENV_FILE decrypted, templates rendered to $RUNTIME_DIR"
