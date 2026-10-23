# Architecture

One Debian host ("rasputin", e.g. a Proxmox VM guest) runs everything in
Docker. Services are grouped into stacks and joined through six shared
external networks, created once by a `networks` bootstrap stack.

```mermaid
flowchart TB
    Internet((Internet))
    Router[Router / Firewall]

    subgraph Docker["Docker host (rasputin)"]
        subgraph Core["core"]
            Proxy[Traefik]
            DNS[Pi-hole + Unbound]
            WG[WireGuard client + wg-easy server (currently off)]
        end
        subgraph Apps["apps"]
            Applications[Home Assistant, Homepage, Syncthing, ...]
        end
        subgraph Mail["mail"]
            Spam[rspamd + iscan]
            Archive[Dovecot archive]
        end
        subgraph Metrics["metrics"]
            Dashboards[Grafana / InfluxDB]
            Exporters[Exporters]
        end
    end

    Internet --> Router
    Router -- VPN --> WG
    WG --> Proxy
    Proxy --> Applications
    Proxy --> Spam
    Proxy --> Dashboards
    DNS --> Proxy
    Exporters -.-> DNS
    Exporters -.-> Dashboards
```

## Deployment model

- `services/<category>/<name>/compose.yaml` — one directory per service;
  `stacks/compose.<stack>.yaml` binds them into a stack via `include:`.
- `komodo/resources/stacks.toml` — the five stacks declared for Komodo's
  ResourceSync; Komodo deploys them from git, `networks` first.
- `scripts/render.sh` — decrypts `.env.enc` -> `.env` and renders
  `templates/*.tmpl` -> `.runtime/`; auto-triggered by a systemd path unit
  on every fetch/pull.
- Komodo itself is deployed standalone from `komodo/` — it cannot manage
  its own stack.

The wg-easy VPN server is temporarily disabled (its compose file stays in
`services/core/wireguard/` and is re-enabled by uncommenting it in the
core stack); the WireGuard *client* is always on.

Everything except `data/` and the age keys is reproducible from the repo.
