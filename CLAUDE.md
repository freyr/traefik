# Traefik

Local development reverse proxy: HTTPS for `*.DOMAIN` (default `freyr.test`) with a mkcert wildcard certificate, a dnsmasq container for DNS, and one isolated edge network per routed stack.

## Critical Rules

- **TFK001**: First-time setup is `make create` (asks for sudo for `mkcert -install` and the resolver file). Never run make with sudo.
- **TFK002**: Services opt in with `traefik.enable=true`; `exposedByDefault` is false.
- **TFK003**: Every routed container needs `traefik.docker.network: <full network name>`. Traefik uses it to choose the network, and network-sync uses it to connect Traefik.
- **TFK004**: Stacks never share a network with each other. No shared `local` network: Traefik joins each stack's edge network instead.
- **TFK005**: Static Traefik config lives in `command:` in `compose.yaml` (so `.env` values apply). Dynamic config goes in `configs/`.

## Commands

```bash
make create        # first-time: mkcert, CA + cert, start, DNS
make start|stop|restart|destroy|logs|status
make certs         # create cert if missing/invalid; make renew-certs to force
make dns           # resolver for DOMAIN -> dns container
make sync-networks # force network-sync pass
make demo-up && make demo-test && make demo-down   # end-to-end check
make remove-legacy # remove loopback alias + certbot renewal of the old setup
```

## Architecture

- `compose.yaml`: `traefik` (127.0.0.1:80/443, docker socket read-only), `dns` (dnsmasq on 127.0.0.1:53, answers only `DOMAIN`), `network-sync` (docker CLI watching events, runs `scripts/networks/sync.sh watch`).
- network-sync connects Traefik to each network named by `traefik.docker.network` on running routed containers, with the `Host()` names as aliases; disconnects on `kill`; removes leftover edge networks after `compose down`.
- Certificate files: `ssl/local.crt`, `ssl/local.key`, `ssl/rootCA.pem` (fixed names, loaded by `configs/certs.toml`).
- Verify any change with `make demo-up && make demo-test && make demo-down`.

## Boundaries

**NEVER:**
- Commit `ssl/*` key or certificate files, or `.env`
- Copy or reference `$(mkcert -CAROOT)/rootCA-key.pem`
- Mount the docker socket read-write into Traefik (only network-sync needs write)
