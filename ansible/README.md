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
8. Installs + enables the `homelab-render.path` systemd unit
9. Brings up the `networks` bootstrap stack
10. Deploys Komodo (single `.env` env file), waits for its API

## What it does NOT do

- **Migrate `data/`** from the old host — rsync it yourself.
  `data/certs/` holds the CA private key; losing it means re-trusting
  the CA on every device. The CA *cert* is committed instead, at
  `services/apps/cert-server/ca/rasputinCA.crt`, so a fresh host can
  serve it without `data/` being in place yet.
- **Create the Komodo stacks** — they are declared in
  `komodo/resources/stacks.toml` and applied by a ResourceSync, which you
  configure once (`docs/komodo.md`). The mail stack stays down until the
  sync has run.
- **Configure VM networking** — use a static DHCP lease in your router
  (ideally keeping `192.168.188.2`), Proxmox bridge/VLAN settings, etc.

## Prerequisites

- Debian guest, reachable via SSH (or run the playbook on it itself).
  The SSH account must have sudo (the play runs with `become: true`);
  set `ansible_user` in `inventory.yml` if it differs from your
  control-node username. This is *not* `homelab_user` — the account the
  playbook creates on the host (default `rasputin`), used for the repo,
  age key and render.
- `ansible-core` on the machine you run it from. The Ansible control
  node must be Linux/macOS/WSL — **not native Windows**. On this repo's
  usual Windows setup: WSL, the Proxmox shell, or the guest itself.
- The `community.docker` collection:
  `ansible-galaxy collection install -r requirements.yml`
- The age key file on that machine: default `~/.config/age/key.txt`,
  override with `-e age_key_source=/path/to/key.txt`
- `sshpass` for password auth (`-k`): `sudo apt install sshpass`.
  Not needed with key-based SSH; Ansible's `ssh` connection cannot
  prompt for a password itself.

## Run

Edit `inventory.yml` first (set the guest's IP). Then either:

```bash
# From a control node over SSH:
cd ansible
ansible-playbook site.yml -i inventory.yml -K

# ...or from the host itself (as root - become then needs no password,
# hence no -K):
scp ~/.config/age/key.txt root@<host>:/root/key.txt
# on the host: apt install ansible, then
ansible-playbook site.yml -i 'localhost,' -c local -e age_key_source=/root/key.txt
```

`-K` passes `ansible_user`'s sudo password: Debian's default sudoers
asks for one and Ansible does not prompt unless told to. To drop the
password on later runs, make the account passwordless on the host:
`echo 'rasputin ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/rasputin`.

`-i inventory.yml` is redundant on a real Linux control node (it comes
from `ansible.cfg`), but mandatory when the repo sits on a Windows-mounted
path: WSL's `/mnt/c` is world-writable, so Ansible ignores `ansible.cfg`
there and silently loses the inventory - passing it explicitly is
harmless everywhere. On WSL, point `age_key_source` at the Windows-side
key too (WSL's `~` is a different home):
`-e age_key_source=/mnt/c/Users/<you>/.config/age/key.txt`.

Useful switches: `--check` works (the networks/Komodo steps use
`docker_compose_v2`, which supports check mode),
`-e homelab_user=otheruser`,
`-e repo_version=otherbranch` (bootstrap clone branch; can also be set
as an inventory var, unlike `homelab_user`).

## After it finishes

1. Open `http://<host>:9120`, log in with the credentials from `.env`
   (`KOMODO_INIT_ADMIN_*`), change the password
2. Create the ResourceSync per `docs/komodo.md` (repo `rmckr/rasputin`,
   branch `main`, resource path `komodo/resources`) and confirm it: the
   5 stacks from `komodo/resources/stacks.toml` are then created and
   deployed, `networks` first
3. rsync `data/` from the old host, then cut over: old host down, new
   host on the same IP. Verify DNS → Traefik → WireGuard → mail sync
   before decommissioning anything.
