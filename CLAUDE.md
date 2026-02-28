# Traefik

Local development reverse proxy routing HTTPS for `*.example.dev` via loopback alias `172.16.123.1`.

## Critical Rules

- **TFK001**: First-time setup requires `sudo make create` — installs loopback alias LaunchDaemon on macOS.
- **TFK002**: Services must opt in with `traefik.enable=true` label — `exposedByDefault` is false.
- **TFK003**: SSL key must have `644` permissions — Docker container needs read access.
- **TFK004**: Use `fullchain.pem` (not `cert.pem`) — includes intermediate certificates.

## Quick Start

```bash
# One-time setup (requires sudo on macOS)
sudo make create           # Loopback alias + network + start Traefik

# Daily operations
make start                 # Start Traefik
make stop                  # Stop Traefik
make destroy               # Remove everything
make                       # Show help
```

## Certificate Management

```bash
make setup-certs           # Copy Let's Encrypt certs to Traefik
make install-renew-hook    # Post-renewal hook
make setup-auto-renewal    # Automatic renewal (macOS LaunchDaemon)
make test-renewal          # Dry-run renewal test
```

## Service Discovery

Add these Docker labels to expose a service:

```yaml
labels:
  traefik.enable: true
  traefik.http.routers.<service>.tls: true
  traefik.http.routers.<service>.entrypoints: websecure
  traefik.http.routers.<service>.rule: "Host(`subdomain.example.dev`)"
```

## Architecture

- Traffic flow: Client → 172.16.123.1:443 → Traefik → containers on `local` Docker network
- Static config: `traefik.toml` (entrypoints, providers)
- TLS config: `configs/certs.toml` + `ssl/` directory
- Auto HTTP→HTTPS redirect; dashboard at `https://traefik.example.dev`
- Platform setup: macOS (LaunchDaemon), Linux (systemd), Windows (manual)

## References

- [SETUP.md](SETUP.md) — Complete first-time setup (DNS, certificates, loopback)
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — Common issues and solutions

## Boundaries

**NEVER:**
- Commit SSL private keys to git
- Modify loopback alias config without testing connectivity afterward

**ASK FIRST:**
- Changes to Traefik entrypoints or providers
- New wildcard domains or certificate changes
