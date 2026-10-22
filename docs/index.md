# Rasputin

Rasputin is a personal homelab repository for managing, deploying, and documenting self-hosted infrastructure and services.

This documentation covers the setup, architecture, and operation of the environment.

## Documentation

### Initial Setup

Getting started with the homelab environment:

- [Initial Setup](initial-setup.md) — Initial system preparation and installation notes

### Infrastructure

Understanding the environment and deployed components:

- [Architecture](architecture.md) — High-level overview of the homelab design and component relationships
- [Stacks & Services](generated/services.md) — Docker Compose stacks and deployed services
- [Networking](generated/networking.md) — Network architecture and connectivity between services

### Operations

Managing and maintaining the environment:

- [Environment Secrets](environment-secrets.md) — Managing encrypted environment configuration
- [Komodo](komodo.md) — GitOps deployment layer and command reference (git is the authoritative config)
- [Local Debugging](generated/local-debugging.md) — Local testing and debugging workflows

## Repository

All source code, configuration files, and automation scripts are maintained in the GitHub repository:

[github.com/rmckr/rasputin](https://github.com/rmckr/rasputin)