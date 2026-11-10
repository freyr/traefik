# Troubleshooting

Start with:

```bash
make status                       # containers + networks and aliases of Traefik
docker compose logs network-sync  # connect / disconnect decisions
docker compose logs traefik
```

## The name does not resolve

- Is the dns container up? `make status`.
- Does the container answer? `nslookup shop.freyr.test 127.0.0.1` must give `127.0.0.1`.
- Is the resolver configured? macOS: `cat /etc/resolver/<DOMAIN>`; Linux:
  `resolvectl status` must show `~<DOMAIN>`. If not, run `make dns`.
- macOS: test with `dscacheutil -q host -a name shop.freyr.test`. `dig` and
  `nslookup` without a server do not read `/etc/resolver`.
- `DOMAIN` changed? The resolver file has the old name: `make remove-dns`
  with the old value, then `make dns`.
- Port 53 is in use (`make start` fails on the dns container): set
  `DNS_PORT=5353` in `.env`, then `make start dns`.

## Certificate warning in the browser

- Restart the browser after the first `mkcert -install`.
- Firefox: install nss (`brew install nss`) and run `make certs` again.
- The host has two levels under the wildcard (`api.shop.freyr.test`): add
  `*.shop.freyr.test` to `CERT_EXTRA_NAMES`, then `make renew-certs`.
- `make cert-info` shows the names of the certificate. They must include
  `*.<DOMAIN>`. After a `DOMAIN` change, run `make certs`.
- The browser shows "TRAEFIK DEFAULT CERT": Traefik did not load
  `ssl/local.crt`. Run `make certs` and `make restart`.

## 404 page not found

Traefik has no router for that host.

- The container has `traefik.enable=true`, and the `Host()` rule has the exact name.
- The dashboard (`https://traefik.<DOMAIN>`) lists the routers and their errors.
- Two containers define a router with the same name: rename one.

## 504 Gateway Timeout or 502 Bad Gateway

Traefik has the router but cannot reach the container.

- The `traefik.docker.network` label is missing or wrong. It must be the full
  network name: `docker network ls` shows it (`<project>_edge`).
- Traefik is not on that network: `make status`. If it is missing, see the
  network-sync log, or run `make sync-networks`.
- The service listens on a port other than the one Traefik uses: set
  `traefik.http.services.<name>.loadbalancer.server.port`.

## A container cannot call https://<host>

- It must be on the same edge network as the routed service. Aliases exist
  only there.
- It must trust the CA: mount `ssl/rootCA.pem` (see README). For a test:
  `curl --cacert /path/rootCA.pem https://shop.freyr.test`.

## "Network <project>_edge Resource is still in use" at docker compose down

Compose removed the network before network-sync disconnected Traefik. This
message is harmless: network-sync removes the network a moment later, when the
stack has no containers. Check with `docker network ls`.

## Traefik is on no edge network after a restart

network-sync connects all networks again when Traefik starts. If the
network-sync container is down: `make start`. To force a sync: `make sync-networks`.
