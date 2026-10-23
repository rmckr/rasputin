# Rasputin

A single Debian host running self-hosted infrastructure as code: Docker
Compose stacks deployed from git by Komodo, secrets encrypted with SOPS.

- [Initial Setup](initial-setup.md) — provisioning a new host
- [Architecture](architecture.md) — host, stacks, deployment model
- [Stacks & Services](generated/services.md) — generated from the compose files
- [Networking](generated/networking.md) — the shared Docker networks
- [Environment Secrets](environment-secrets.md) — `.env` / `.env.enc` workflow
- [Komodo](komodo.md) — bootstrap and day-2 operation
- [Testing](testing.md) — validating changes and migrations before they hit the host
- [Local Debugging](generated/local-debugging.md) — hosts-file entries for local access

Source: [github.com/rmckr/rasputin](https://github.com/rmckr/rasputin)
