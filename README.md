# Rasputin

Personal homelab: one Debian host running Docker stacks (Traefik, Pi-hole +
Unbound, mail archival, metrics, apps), deployed from git by
[Komodo](https://komo.do), secrets sealed with SOPS/age.

- Docs: https://rmckr.github.io/rasputin/
- Bootstrap: `ansible/` provisions a fresh Debian host (see `ansible/README.md`)
- Secrets: `.env` (plaintext, local) ↔ `.env.enc` (committed) —
  `docs/environment-secrets.md`

## Layout

```
ansible/     host bootstrap playbook
komodo/      Komodo deployment (standalone) + stack declarations (resources/stacks.toml)
services/    one directory per service: compose.yaml + config
stacks/      stack entrypoints, `include:` the service compose files
templates/   *.tmpl rendered into .runtime/ by scripts/render.sh
scripts/     render.sh (SOPS + envsubst), renew-certs.sh, docs generator
data/        runtime state, gitignored
```
