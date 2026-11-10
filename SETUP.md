# Setup

`make create` does all of the steps below. This page explains each step and
the migration from the Let's Encrypt version of this repo.

## 1. Configuration

```bash
make check-env        # copies .env.example to .env when .env is missing
```

Set `DOMAIN` in `.env`. Use a reserved TLD that never resolves publicly:

| TLD | Use |
|---|---|
| `.test` | Recommended (RFC 6761). |
| `.internal` | Reserved by ICANN for private use. |
| `.local` | Do not use: macOS sends it to mDNS (Bonjour). |
| `.dev`, `.app`, other real TLDs | Do not use: they are public. |

Use a name with two labels (`freyr.test`), so the certificate is `*.freyr.test`.
Browsers reject a wildcard directly under a TLD (`*.test`).

## 2. mkcert

```bash
make install-deps     # macOS: brew install mkcert nss
```

On Linux, install mkcert from your package manager or from
<https://github.com/FiloSottile/mkcert#installation>, and `libnss3-tools` for
Firefox and Chrome.

## 3. CA and certificate

```bash
make certs
```

- `mkcert -install` creates the local CA (once per machine) and adds it to the
  system trust store. macOS asks for your password. With nss installed, Firefox
  trusts it too.
- mkcert writes `ssl/local.crt` and `ssl/local.key` for `DOMAIN` and `*.DOMAIN`.
- `ssl/rootCA.pem` is a copy of the public CA certificate, to mount into containers.

Restart the browser after the first `mkcert -install`.

## 4. Containers

```bash
make start            # docker compose up -d --build --wait
make status           # containers, and the networks Traefik is on
```

## 5. DNS

```bash
make dns
```

| OS | What it does |
|---|---|
| macOS | Writes `/etc/resolver/<DOMAIN>` (`nameserver 127.0.0.1`, `port <DNS_PORT>`) and flushes the DNS cache. |
| Linux | Writes `/etc/systemd/resolved.conf.d/traefik-<DOMAIN>.conf` (`DNS=127.0.0.1:<DNS_PORT>`, `Domains=~<DOMAIN>`) and restarts systemd-resolved. |

The dns container must run for the names to resolve. Check:

```bash
dscacheutil -q host -a name shop.freyr.test     # macOS (dig ignores /etc/resolver)
resolvectl query shop.freyr.test                # Linux
```

## 6. Check

```bash
make demo-up && make demo-test && make demo-down
```

## Migration from the Let's Encrypt version

The old version used a public domain, a certbot wildcard certificate through
Cloudflare DNS, a loopback alias `172.16.123.1`, and the shared network `local`.

1. Stop the old proxy: `docker compose down` in the old checkout.
2. Remove the old system changes (loopback LaunchDaemon or systemd unit,
   certbot renewal LaunchDaemon, renewal hook):
   ```bash
   make remove-legacy            # LOOPBACK_IP=... make remove-legacy for a custom IP
   ```
3. Edit `.env`: set `DOMAIN` to a local domain and remove `LOOPBACK_*`,
   `CLOUDFLARE_*`, `LETSENCRYPT_*`, `CERT_FILE`, `KEY_FILE`, `WILDCARD_DOMAIN`,
   `DOCKER_NETWORK_NAME`. Compare with `.env.example`.
4. Delete the old certificate files in `ssl/` (`<domain>.crt`, `<domain>.key`).
5. `make create`.
6. In each stack, replace the external `local` network with an own edge network
   and the `traefik.docker.network` label (see README, "Route a stack"). The
   `traefik.http.routers.*.tls` and `entrypoints` labels can go. Change the
   hostnames to the new domain.
7. When nothing else uses them: delete the public DNS record, the Cloudflare
   token (`~/.secrets/cloudflare.ini`), the certbot certificate
   (`sudo certbot delete --cert-name <domain>`) and the network
   (`docker network rm local`).
