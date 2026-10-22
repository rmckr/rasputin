## Environment Secrets

Secrets live in a plaintext `.env` file (never committed) and are stored
encrypted in git as `.env.enc`, encrypted with
[SOPS](https://github.com/getsops/sops) using an
[age](https://github.com/FiloSottile/age) backend.

Creation rules (which age recipients encrypt which files) are defined in
`.sops.yaml` at the repository root. The same rules cover
`komodo/compose.env.enc`.

### Requirements

- `sops` — install from https://github.com/getsops/sops
  (e.g. `winget install SecretsOPerationS.SOPS` on Windows,
  or your package manager on Linux)
- An age key, default location `~/.config/age/key.txt`.
  Override with `SOPS_AGE_KEY_FILE=/path/to/key`
  (the systemd unit keeps its copy at `/root/.config/age/key.txt`)
- `envsubst` (package `gettext-base`) - renders `templates/`

### Decrypting .env.enc

```bash
export SOPS_AGE_KEY_FILE="$HOME/.config/age/key.txt"  # key.txt, not sops' default keys.txt
sops --decrypt --input-type dotenv --output-type dotenv .env.enc > .env
```

Or simply run `scripts/render.sh`, which decrypts `.env.enc` and renders the
templates into `.runtime/`. This also runs automatically: the systemd path unit
`scripts/systemd/homelab-render.path` re-renders when `.env.enc`, `templates/`, or
`.git/FETCH_HEAD` (any fetch/pull, catching nested template changes)
change (e.g. after Komodo pulls the repo), and the git hook
`scripts/hooks/post-merge` does the same after a manual `git pull`.

### Encrypting .env

After editing `.env`:

```bash
sops --encrypt --input-type dotenv --output-type dotenv .env > .env.enc
```

SOPS picks the recipients from `.sops.yaml` based on the file path, so no
`-R`/recipient flags are needed. Note that sops' dotenv parser stores values
one per line and strips blank lines — a decrypt→edit→encrypt roundtrip is
expected to drop them, which is why both `.env.enc` and
`komodo/compose.env.enc` are kept in sops' canonical form.

### Komodo bootstrap secrets

Komodo has its own env file with the same scheme:
`komodo/compose.env` (plaintext, gitignored) ↔
`komodo/compose.env.enc` (committed). See `komodo/compose.env.example`
for the template and [Komodo](komodo.md) for usage.

### Key management

The two age recipients in `.sops.yaml` are:

1. The primary age key (`~/.config/age/key.txt`) — keep a backup of this
   key somewhere safe and separate from the host. **Losing all keys means
   losing access to the secrets in this repo.**
2. An offline recovery recipient — store its private key off-site (e.g.
   printed in a safe or in a password manager).
