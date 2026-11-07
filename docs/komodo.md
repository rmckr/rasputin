# Komodo

[Komodo](https://komo.do) deploys the stacks from this repo: git stays the
source of truth, Komodo pulls and runs `docker compose`. It runs standalone
from `komodo/` — it cannot manage its own stack and must exist before it can
manage anything else.

Components: `core` (UI/API on 9120, `https://komodo.<domain>` via Traefik),
`periphery` (agent, runs compose through the docker socket), `mongo`.

Periphery mounts the repo at the same path inside and outside the container
(`/etc/komodo/repos/rasputin`), so the relative `../../../data/...` paths in
the service compose files resolve for the host docker daemon. If you clone
elsewhere, update the mount in `komodo/compose.yaml` plus the paths in
`scripts/systemd/` (hardcoded) and `repo_dir` in `ansible/site.yml`.

Periphery runs as root but the clone belongs to the homelab user, which git
>= 2.35 rejects as "detected dubious ownership". `komodo/compose.yaml` pins
`safe.directory` for that path through `GIT_CONFIG_*` environment variables, so
the exception survives container recreation - a `git config --global` inside
the container does not.

## Bootstrap

`ansible/` does all of this automatically. Manually:

```bash
# 1. Clone where periphery expects it (HTTPS - Komodo cannot clone via SSH,
#    it reuses this clone)
sudo mkdir -p /etc/komodo/repos && sudo chown "$USER" /etc/komodo/repos
git clone https://github.com/rmckr/rasputin.git /etc/komodo/repos/rasputin

# 2. Render secrets (.env.enc -> .env, templates -> .runtime/)
bash /etc/komodo/repos/rasputin/scripts/render.sh

# 3. Shared networks FIRST - Komodo's core joins `proxy`
docker compose -f /etc/komodo/repos/rasputin/stacks/compose.networks.yaml up -d

# 4. Deploy Komodo
cd /etc/komodo/repos/rasputin && docker compose -p komodo -f komodo/compose.yaml --env-file .env up -d
```

Log in with the initial credentials from `.env` (`KOMODO_INIT_ADMIN_*`) and
change the password. If the six networks already exist but were created
outside compose, `up` fails with "incorrect label" — remove them first while
nothing runs: `docker network rm proxy dns pihole mail_filter mail_archive metrics`.

## Stacks via ResourceSync

The five stacks are declared in `komodo/resources/stacks.toml` and applied
once via Komodo -> Automate -> Sync Resources (repo `rmckr/rasputin`, branch
`main`, resource path `komodo/resources`). Afterwards the file is the source
of truth: adding a stack is an edit and a push, and the sync applies on
confirmation or automatically once the git webhook exists.

Notes on the declarations:

- `after = ["networks"]` is what orders the deploys.
- `additional_env_files = [{ path = ".env", track = false }]` passes the
  rendered `.env` to compose without Komodo reading or diffing it. Leave
  each stack's **Environment** field empty — Komodo writes it to `.env`
  and would clobber the rendered secrets.
- `ignore_services = ["networks-init"]`: one-shot container that exits
  right after creating the networks.
- The project name defaults to the stack name (`-p core`, ...). Set
  `project_name` if a stack was previously brought up by hand under a
  different name, or the ports collide.

## Secrets re-render on pull

The systemd path unit `homelab-render.path` watches `.env.enc`,
`templates/` and `.git/FETCH_HEAD` (rewritten on every fetch/pull) and runs
`scripts/render.sh`. Skip this section when you bootstrapped with
`ansible/` — it places root's age key and installs + enables the unit
automatically. Otherwise install once; the unit runs as root, so root
needs the age key too:

```bash
cd /etc/komodo/repos/rasputin
sudo mkdir -p /root/.config/sops/age
sudo install -m 600 ~/.config/sops/age/keys.txt /root/.config/sops/age/keys.txt
sudo ln -s "$PWD"/scripts/systemd/homelab-render.path /etc/systemd/system/
sudo ln -s "$PWD"/scripts/systemd/homelab-render.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now homelab-render.path
```

## Updating Komodo

Bump the image tags in `komodo/compose.yaml` (`komodo-core:2` /
`komodo-periphery:2`), then:

```bash
docker compose -p komodo -f komodo/compose.yaml --env-file .env pull
docker compose -p komodo -f komodo/compose.yaml --env-file .env up -d
```

Never import `komodo/` as a Komodo stack — self-management breaks on
redeploy (`komodo.skip` only guards against StopAllContainers).
