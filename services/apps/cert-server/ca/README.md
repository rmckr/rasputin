# ca/

Holds the **CA certificate only** — it is public config, so it is committed
here and served to LAN clients by `cert-server` at
`https://certs.<domain>/rasputinCA.crt`. Install it on a device once and that
device trusts every cert Traefik serves.

```bash
# On the host, from the repo root — copy the existing cert into git:
cp data/certs/ca/rasputinCA.crt services/apps/cert-server/ca/rasputinCA.crt
```

What deliberately is **not** here:

- `rasputinCA.key` — the CA private key. Stays under `data/certs/ca/` and is
  never committed (see `.gitignore`). Losing it means re-trusting the CA on
  every device; back it up off-host.
- `rasputinCA.srl` — the signing serial, written by `renew-certs.sh` into
  `data/certs/ca/`.
- `*.pem` — leaf cert bundles, which are per-host and contain the private key.

To rotate the CA: generate a new one, replace the cert here, re-encrypt the
key into `data/certs/ca/`, then re-trust on every device. Rarely worth it.
