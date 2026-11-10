# Scripts

The make targets call these scripts. Each Bash script loads `.env` through
`common/load-config.sh`; run them from any directory.

| Script | Make target | Purpose |
|---|---|---|
| `common/load-config.sh` | — | Loads `.env`, checks `DOMAIN`, sets defaults, makes `SSL_DIR` absolute. Source it first in every new script. |
| `certs/generate.sh [--force]` | `certs`, `renew-certs` | `mkcert -install`, then the `DOMAIN` + `*.DOMAIN` certificate into `SSL_DIR`. |
| `dns/setup.sh` | `dns` | Resolver for `DOMAIN` → `127.0.0.1:DNS_PORT` (macOS `/etc/resolver`, Linux systemd-resolved). Calls sudo. |
| `dns/remove.sh` | `remove-dns` | Removes that resolver file. |
| `networks/sync.sh once\|watch\|status` | `sync-networks`, `status` | POSIX sh, runs in the network-sync container. Connects Traefik to edge networks with `Host()` aliases, disconnects, sweeps leftover networks. |
| `demo/test.sh` | `demo-test` | End-to-end checks of the demo stacks. |
| `legacy/remove-legacy.sh` | `remove-legacy` | Removes the loopback alias and certbot renewal of the Let's Encrypt version. Needs sudo. |

New user-facing script: add a make target with a `##` description so it
appears in `make help`.
