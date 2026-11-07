# Testing before deploy

How to validate changes before they touch the production host — for a
significant change to an existing stack, or a full migration to a new host.

## 1. Local checks (before pushing)

Runs against your working copy with your rendered `.env`. CI
(`.github/workflows/ci.yml`) runs the same checks on every push to `main`
— minus the secrets check, which needs your age key.

```bash
# Fully interpolated config for every stack - catches broken includes, bad
# relative paths, missing networks and unset ${VAR:?error} vars. This is
# exactly what compose will run on the host.
for f in stacks/compose.*.yaml; do docker compose -f "$f" --env-file .env config --quiet && echo "OK $f"; done
docker compose -p komodo -f komodo/compose.yaml --env-file .env config --quiet && echo "OK komodo"

# Secrets still decrypt (age key + MAC intact):
SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt \
  sops --decrypt --input-type dotenv --output-type dotenv .env.enc > /dev/null && echo "env OK"

# Templates render; the diff shows exactly what a deploy would pick up:
bash scripts/render.sh && git status --short .runtime/

# Scripts and playbook parse:
for s in scripts/*.sh scripts/docs/generate.sh; do bash -n "$s" && echo "OK $s"; done
(cd ansible && ansible-playbook site.yml --syntax-check)   # needs ansible: WSL on this setup

# stacks.toml parses; docs templates render (both also run in CI):
python -c "import tomllib; d = tomllib.load(open('komodo/resources/stacks.toml', 'rb')); assert len(d['stack']) == 5, d"   # python3 on Linux
bash scripts/docs/generate.sh   # creates scripts/docs/.venv; needs a POSIX venv - WSL on this setup

# Every ${VAR} referenced by compose files and templates exists in .env:
comm -23 \
  <(grep -rhoE --include='compose*.yaml' --include='*.tmpl' '\$\{?[A-Z_][A-Z0-9_]+' services stacks komodo templates | tr -d '${' | sort -u) \
  <(grep -oE '^[A-Z_][A-Z0-9_]*' .env | sort -u)
```

## 2. Dry-run the bootstrap (migration / host rebuild)

- Take a Proxmox snapshot of the target VM before anything.
- Fresh Debian VM, any IP — it is disposable.
- `ansible-playbook site.yml -i inventory.yml -K` end to end (WSL flags
  and `age_key_source` in `ansible/README.md`). It is idempotent; re-run
  until clean, and read the first failure properly instead of patching
  around it.
- Deploy one low-risk stack by hand and check it in isolation, before
  DNS/Traefik are involved. Use the same project name Komodo will use,
  or you end up with two copies and colliding ports:
  `docker compose -p metrics -f stacks/compose.metrics.yaml --env-file .env up -d`,
  then `docker compose -p metrics ps`, `docker compose -p metrics logs --tail 50`,
  and open the services via `IP:port`.

## 3. Rolling out a change to the running host

One stack at a time, in dependency order (`networks` -> `core` -> rest):

1. **Backup first**: Proxmox snapshot + `data/` rsync. `data/` has no
   automatic backup and cannot be rebuilt.
2. Merge to `main`. Komodo pulls; the path unit re-renders secrets.
3. Deploy the affected stack in Komodo and watch its logs.
4. Verify before moving on:
   - `docker compose -p <stack> ps` — running, not restarting
   - DNS: `nslookup grafana.<domain> <host-ip>` — Pi-hole answers
   - Routing: `curl -kI https://<service>.<domain>` — 200/302 via Traefik
   - The service itself: log in, do the thing it exists for
   - `docker compose -p <stack> logs --tail 100` — no restart loops
5. Rollback: `git revert` + push (Komodo redeploys the old state).
   Host-level damage: restore the Proxmox snapshot.

## 4. Big migration (old host -> new host)

1. Stand up the new host under a **different IP** first, run the whole
   sequence (playbook -> ResourceSync -> all stacks), and exercise
   everything there while the old host keeps serving.
2. rsync `data/` over while the old host is idle; re-rsync right before
   cutover (mail archives and certs change rarely).
3. Cutover: stop the old host, final rsync, move the new host onto the
   old IP (static lease). Leave the old VM powered off — not deleted —
   until mail sync, DNS and VPN have been watched for a few days.
4. Verify from a real client device: DNS resolution, every Traefik host,
   mail delivery (imapsync log), VPN handshake.

## What has no safety net

- **`data/`** — only the backups you arrange (Proxmox snapshot, rsync).
- **Both age keys** — losing them means losing every secret in this repo.
  Keep them off-site ([Environment Secrets](environment-secrets.md)).
- **The CA private key** (`data/certs/ca/`) — losing it means re-trusting
  the CA on every device.
