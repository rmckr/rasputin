# Architecture

Rasputin runs a self-hosted infrastructure environment on a single Raspberry Pi 4B acting as the Docker host.

The environment is organized into separate Docker Compose stacks based on responsibility. Traffic, services, and shared networking are managed through these stacks to keep the deployment modular and maintainable.

## Overview

```mermaid
flowchart TB
    Internet((Internet))

    Router[Router / Firewall]

    subgraph Docker["Docker Host"]
        subgraph Core["core"]
            Proxy[Traefik Reverse Proxy]
            WireGuard[WireGuard VPN]
            DNS[DNS]
        end

        subgraph Apps["apps"]
            Applications[Self-hosted Applications]
        end

        subgraph Mail["mail"]
            Archive[Mail archival]
            Spam[Spam filtering]
        end

        subgraph Metrics["metrics"]
            Dashboards[Dashboards / Databases]
            Exporters[Exporters]
        end
    end

    Internet --> Router
    Router -- Ingress --> WireGuard

    Proxy -- Routing --> Apps
    Proxy -- Routing --> Spam
    Proxy -- Routing --> Dashboards

    WireGuard -- Internal access --> Proxy

    DNS -- Domains --> Proxy

    Exporters -. Observing .-> DNS
    Exporters -. Observing .-> WireGuard
    Exporters -- Data --> Dashboards
```

## Hardware

The complete Docker environment runs on a single Raspberry Pi 4B.

The host is responsible for:

- Running Docker and Docker Compose
- Hosting all application stacks
- Providing shared networking between services
- Executing infrastructure management commands through Komodo

The infrastructure is designed to be reproducible through configuration files and automation rather than relying on manual host configuration.


## Deployment Model

The infrastructure is defined as code:

- Docker Compose files define running services
- A `networks` bootstrap stack creates the shared external Docker networks
- Templates provide generated configuration
- SOPS-encrypted environment files provide secrets
- Komodo deploys the stacks from git; `scripts/render.sh` (auto-triggered by a
  systemd path unit and a git hook) decrypts secrets and renders templates

The complete environment can be recreated from the repository contents and required secrets.

## Design Goals

The architecture prioritizes:

- **Reproducibility** — infrastructure is defined through version-controlled configuration
- **Modularity** — services are grouped into independent stacks
- **Maintainability** — common operations are handled through Komodo
- **Isolation** — services communicate through controlled networks
- **Simplicity** — a single host keeps the environment easy to understand and operate