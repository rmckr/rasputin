# Ansible bootstrap

Automates bringing a fresh Debian host (e.g. a Proxmox VM guest) to the
state documented in `docs/komodo.md`: packages, secrets, the render
automation, the shared Docker networks, and Komodo itself.
Idempotent — safe to re-run any time.

## What it does

1. Installs packages: git, gettext-base (envsubst), age, Docker CE +
   compose plugin (official Docker apt repo)
2. Installs sops as the official binary, pinned and verified against the
   release checksums file (sops is not packaged in Debian)
3. Ensures the homelab user exists (in `sudo`/`docker`)
4. Enables IPv4/IPv6 forwarding and WireGuard policy routing via
   `/etc/sysctl.d/99-homelab.conf`
5. Clones this repo to `/etc/komodo/repos/rasputin` — the path Komodo's
   periphery pulls into
6. Places the age key for root *and* the user (copied from your machine;
   it never comes from git)
7. Runs `scripts/render.sh` → `.env` + `.runtime/`
8. Installs + enables the `homelab-render.path` systemd unit and the
   `post-merge` git hook
9. Brings up the `networks` bootstrap stack
10. Decrypts `komodo/compose.env`, deploys Komodo, waits for its API

## What it does NOT do

- **Migrate `data/`** from the old host — rsync it yourself.
  `data/certs/` holds the CA private key; losing it means re-trusting
  the CA on every device. The CA *cert* is committed instead, at
  `services/apps/cert-server/ca/rasputinCA.crt`, so a fresh host can
  serve it without `data/` being in place yet.
- **Create the Komodo stacks** — do that in the UI (`docs/komodo.md`).
  The mail stack stays down until you do.
- **Configure VM networking** — use a static DHCP lease in your router
  (ideally keeping `192.168.188.2`), Proxmox bridge/VLAN settings, etc.

## Prerequisites

- Debian guest, reachable via SSH (or run the playbook on it itself)
- `ansible-core` on the machine you run it from. The Ansible control
  node must be Linux/macOS/WSL — **not native Windows**. On this repo's
  usual Windows setup: WSL, the Proxmox shell, or the guest itself.
- The age key file on that machine: default `~/.config/age/key.txt`,
  override with `-e age_key_source=/path/to/key.txt`

## Run

Edit `inventory.yml` first (set the guest's IP). Then either:

```bash
# From a control node over SSH:
cd ansible
ansible-playbook site.yml

# ...or from the host itself:
scp ~/.config/age/key.txt root@<host>:/root/key.txt
# on the host: apt install ansible, then
ansible-playbook site.yml -i 'localhost,' -c local -e age_key_source=/root/key.txt
```

Useful switches: `--check` for a dry run (partial — `command` tasks are
skipped in check mode, so the networks/Komodo deploy steps aren't
previewed), `-e homelab_user=otheruser`.

## After it finishes

1. Open `http://<host>:9120`, log in with the credentials from
   `komodo/compose.env`, change the password
2. Create the 5 stacks per `docs/komodo.md` (`networks`, `core`,
   `metrics`, `mail`, `apps`); deploy `networks` first — its
   `networks-init` service goes into **Ignore Services** — the rest in
   any order
3. rsync `data/` from the old host, then cut over: old host down, new
   host on the same IP. Verify DNS → Traefik → WireGuard → mail sync
   before decommissioning anything.
