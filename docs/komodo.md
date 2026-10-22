# Komodo

[Komodo](https://komo.do) is the deployment layer for this repo: git stays
the authoritative source of configuration, and Komodo pulls and redeploys
the stacks from it. It replaces the manual stack lifecycle workflow entirely.

Komodo is deployed **standalone** from `komodo/` — it is *not* one of the
managed stacks, because Komodo cannot reliably manage its own stack, and it
has to exist before it can manage anything else.

## Components

- `core` — web UI / API on port 9120, reachable via
  `https://komodo.rasputin.pi` (Traefik, internal cert)
- `periphery` — agent on the host that runs `docker compose` through the
  docker socket; sees this repo under `/etc/komodo/repos/rasputin`
- `mongo` — Komodo's database (small wiredTiger cache)

Periphery sees the repository at the **same path inside and outside the
container** (`/etc/komodo/repos/rasputin`), so relative volume paths in the
service compose files (`../../../data/...`) resolve identically for the
host docker daemon. If you clone the repo elsewhere on the host, change
the repo mount path in `komodo/compose.yaml` (and the matching hardcoded
paths in `scripts/systemd/` and `ansible/`) accordingly.

## Initial deployment (bootstrap)

Komodo is deployed with plain docker compose, before and independently of
Komodo itself:

```bash
# 1. Clone the repo on the host (path must match the mount in komodo/compose.yaml)
sudo mkdir -p /etc/komodo/repos
sudo chown "$USER" /etc/komodo/repos
# HTTPS, not SSH: Komodo cannot clone via SSH (it reuses this clone)
git clone https://github.com/rmckr/rasputin.git /etc/komodo/repos/rasputin

# 2. Render secrets (decrypts .env.enc -> .env, fills .runtime/)
bash /etc/komodo/repos/rasputin/scripts/render.sh

# 3. Decrypt the Komodo bootstrap env
cd /etc/komodo/repos/rasputin
export SOPS_AGE_KEY_FILE=~/.config/age/key.txt
sops --decrypt --input-type dotenv --output-type dotenv komodo/compose.env.enc > komodo/compose.env

# 4. Create the shared networks FIRST - Komodo's core joins `proxy`
docker compose -f /etc/komodo/repos/rasputin/stacks/compose.networks.yaml up -d

# 5. Deploy Komodo
cd /etc/komodo/repos/rasputin && docker compose -p komodo -f komodo/compose.yaml --env-file komodo/compose.env up -d
```

The `ansible/` directory in the repo automates this whole sequence
(packages, age keys, units, networks, Komodo) — see `ansible/README.md`.

Signups are disabled; log in with the initial admin credentials from
`komodo/compose.env` and change the password immediately.

The `networks` stack is created in step 4 above (before Komodo starts).
Register it in Komodo as well so it stays re-deployable, and add its
`networks-init` service to **Ignore Services** - the one-shot container
exits right after creating the networks. If the six networks already
exist on this host but were created outside compose, `up` fails with an
"incorrect label" error; remove them first while nothing is running:
`docker network rm proxy dns pihole mail_filter mail_archive metrics`.

## Connecting the stacks

For each entry in `stacks/` create a **Stack** resource in Komodo:

- **Git** (recommended): repo `rmckr/rasputin`, branch `main`, clone
  path `rasputin` so Periphery clones it to `/etc/komodo/repos/rasputin`
  (the mount path in `komodo/compose.yaml`). Komodo pulls on webhook/push; it cannot clone
  via SSH, so add a GitHub account + token for private repos. Komodo's
  pulls don't run git hooks - the systemd path unit is what re-renders
  secrets afterwards (it watches that directory). Use **Files on Host**
  pointing at the same path if you'd rather pull manually.
- **Compose file** (`file_paths`): `stacks/compose.<name>.yaml`, run
  directory = the repo root.
- **Env files** (`additional_env_files`): `.env` - the SOPS-rendered file
  at the repo root, attached as `--env-file`; this is what `${VAR:?error}`
  interpolates from. Leave the stack's own **Environment** field empty:
  Komodo writes it to `env_file_path` (default `.env`) and would clobber
  the rendered secrets.

Komodo has no inter-stack dependency feature to configure - the only hard
requirement is `networks` first (the rest just need the external networks
to pre-exist). Deploy in this order:

1. `networks` - set **Ignore Services** to `networks-init`
2. `core`
3. `metrics`
4. `mail`
5. `apps`

## Secrets workflow with Komodo

Git stays authoritative for config; secrets stay encrypted:

1. `git pull` (or let Komodo pull via the repo integration)
2. Secrets render automatically on the host: the systemd path unit
   `homelab-render.path` (see `scripts/systemd/`) watches `.env.enc`,
   `templates/`, and `.git/FETCH_HEAD` (rewritten on every fetch/pull, so
   template changes are caught at any depth) and runs `scripts/render.sh`
   (SOPS decrypt + envsubst into `.runtime/`). The `post-merge` git hook
   covers manual pulls.
3. Komodo redeploys the affected stacks (webhook, schedule, or button)

Install both once during bootstrap (the unit runs as root, so root needs
the age key as well):

```bash
cd /etc/komodo/repos/rasputin
sudo chmod +x scripts/render.sh scripts/hooks/post-merge
sudo mkdir -p /root/.config/age
sudo install -m 600 ~/.config/age/key.txt /root/.config/age/key.txt
sudo ln -s "$PWD/scripts/systemd/homelab-render.path" /etc/systemd/system/
sudo ln -s "$PWD/scripts/systemd/homelab-render.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now homelab-render.path
ln -s ../../scripts/hooks/post-merge .git/hooks/post-merge
```

Komodo's own secrets are managed the same way — see
[Environment Secrets](environment-secrets.md).

## Updating Komodo itself

Bump the image tags in `komodo/compose.yaml` (`komodo-core:2` /
`komodo-periphery:2`), then:

```bash
docker compose -p komodo -f komodo/compose.yaml --env-file komodo/compose.env pull
docker compose -p komodo -f komodo/compose.yaml --env-file komodo/compose.env up -d
```

Do not import `komodo/` into Komodo as a stack — self-management breaks on
redeploy (the `komodo.skip` label only guards against `StopAllContainers`).
