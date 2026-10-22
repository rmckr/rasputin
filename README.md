# Rasputin

A personal homelab repository for managing and documenting home infrastructure and services.

## Full documentation
[Documentation](https://rmckr.github.io/rasputin/)

## Project structure
File structure
```
homelab/
├── ansible/
│   ├── site.yml
│   └── ...
├── data/
│   ├── influxdb/
│   │   └── ...
│   └── ...
├── services/
│   ├── apps/
│   │   ├── cert-server/
│   │   │   └── compose.yaml
│   │   └── ...
│   ├── core/
│   │   └── ...
│   ├── mail/
│   │   └── ...
│   └── metrics/
│       └── ...
├── stacks/
│   ├── compose.apps.yaml
│   ├── compose.core.yaml
│   └── ...
├── templates/
│   ├── grafana/
│   │   └── datasources.yml.tmpl
│   └── ...
├── .runtime/
│   ├── grafana/
│   │   └── datasources.yml
│   └── ...
└── .env
```
[Tree](https://tree.nathanfriend.com/?s=(%27options!(%27fancy!true~fullPath!fal9~trailingSlash!true~rootDot!fal9)~6!(%276!%27homelab7B*influxdb429rvices*appsAcert-9rverA0584core4mail4metricsA2stacks*5apps.8*5core.8*2templates3.tmpl*2.runtime3*2.env%27)~version!%271%27)*700%20%202...73*grafanaAB6s.yml4A...*5compo9.6source7%5Cn08yaml9seA*0Bdata%01BA987654320*)
