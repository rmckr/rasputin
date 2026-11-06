# Initial setup

## With Ansible (recommended)

`ansible/` provisions a fresh Debian host end to end: packages, Docker,
sops + age keys, repo clone, secret rendering, the `homelab-render` path
unit, the `networks` stack, and Komodo itself. See `ansible/README.md`.

## What the playbook does not cover

- **Addressing** — a static DHCP lease for the host in the router is
  enough; during bootstrap the host's own resolver must not depend on the
  Pi-hole it is about to provide (point it at the router).
- **TLS trust** — a host without the old `data/certs/ca/` has no CA key, so
  the playbook generates a new CA and overwrites
  `services/apps/cert-server/ca/rasputinCA.crt`. Commit that file and install
  the cert on every device (`https://certs.<domain>/rasputinCA.crt`), or
  devices will reject every Traefik host.
- **`data/` migration** — rsync from the previous host. `data/certs/ca/`
  holds the CA private key; losing it means re-trusting the CA on every
  device.
- **Komodo stacks** — created once via ResourceSync, see
  [Komodo](komodo.md).
- **Router** — forward `UDP/47111` to the host while the wg-easy VPN
  server is enabled (currently disabled).

## Raspberry Pi specifics

Only relevant when running on a Pi instead of a VM:

- Static addressing in `/etc/dhcpcd.conf`, then `sudo service dhcpcd restart`:

  ```
  interface eth0
      static routers=192.168.188.1
      static domain_name_servers=192.168.188.1
      static ip_address=192.168.188.2/24
      static ip6_address=fdff:150a:4884::2/64
  ```

- USB-to-SATA bridge: add `usb-storage.quirks=abcd:1234:u` to
  `/boot/cmdline.txt` (`lsusb` shows the id).
