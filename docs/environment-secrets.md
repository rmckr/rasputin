# Environment Secrets

One env-file pair: plaintext `.env` (never committed) <-> `.env.enc`
(committed), encrypted with [SOPS](https://github.com/getsops/sops) on an
[age](https://github.com/FiloSottile/age) backend. It carries the shared
config (`HOMELAB_*`), every service secret, and the `KOMODO_*` bootstrap
secrets. Recipients are defined in `.sops.yaml`; only `HOMELAB_*` keys stay
readable, everything else is sealed by default — including keys added later.

Needs: `sops`, `envsubst` (package `gettext-base`), and an age key at
`~/.config/sops/age/keys.txt` (sops' default location; override with
`SOPS_AGE_KEY_FILE`; the systemd unit keeps its copy at
`/root/.config/sops/age/keys.txt`).

## Workflow

```bash
# decrypt - or just run scripts/render.sh, which also renders templates/
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"  # sops' default location
sops --decrypt --input-type dotenv --output-type dotenv .env.enc > .env

# after editing .env
sops --encrypt --input-type dotenv --output-type dotenv .env > .env.enc
```

- Recipients come from `.sops.yaml` via the filename; no `-R` flags needed.
- sops' dotenv parser strips blank lines, so a decrypt->edit->encrypt
  roundtrip drops them. Harmless.
- `.env` must stay LF-only (sops output is); a Windows editor may write
  CRLF, which bash cannot `source` — strip it before encrypting.
- Rendering on the host is automatic: `homelab-render.path` re-runs
  `scripts/render.sh` when `.env.enc`, `templates/` or `.git/FETCH_HEAD`
  change.

## Key management

The two recipients in `.sops.yaml`:

1. Primary age key (`~/.config/sops/age/keys.txt`) — back it up off this machine.
   **Losing all keys means losing the secrets in this repo.**
2. Offline recovery recipient — private key stored off-site (password
   manager, printed, ...).
