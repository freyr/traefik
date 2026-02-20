# Docker Networking — Multi-Stack Local Development Guide
---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Fundamentals](#fundamentals)
3. [Patterns](#patterns)
4. [DNS and Service Discovery](#dns-and-service-discovery)
5. [Debugging and Troubleshooting](#debugging-and-troubleshooting)
6. [macOS Parity with OrbStack](#macos-parity-with-orbstack)
7. [Tips and Best Practices](#tips-and-best-practices)
8. [Quick Reference](#quick-reference)

---

## Running Example

This guide uses a consistent 3-stack architecture throughout. Every pattern, DNS example, and debugging recipe references these same stacks:

| Stack | Compose file | Services | Purpose |
|---|---|---|---|
| `infra` | `infra/docker-compose.yml` | `mysql`, `rabbitmq`, `redis` | Shared infrastructure |
| `api` | `api/docker-compose.yml` | `php-api`, `php-worker` | Backend API and queue worker |
| `frontend` | `frontend/docker-compose.yml` | `nginx`, `node-app` | Frontend application |

All three stacks share a pre-created external network called `microservices`.

```
┌─────────────────────────────────────────────────────────┐
│                  microservices network                  │
│                                                         │
│  ┌─────────┐  ┌──────────┐  ┌───────┐  ┌───────────┐    │
│  │  mysql  │  │ rabbitmq │  │ redis │  │  php-api  │    │
│  │ (infra) │  │ (infra)  │  │(infra)│  │   (api)   │    │
│  └─────────┘  └──────────┘  └───────┘  └───────────┘    │
│                                                         │
│  ┌────────────┐  ┌───────┐  ┌──────────┐                │
│  │ php-worker │  │ nginx │  │ node-app │                │
│  │   (api)    │  │(front)│  │ (front)  │                │
│  └────────────┘  └───────┘  └──────────┘                │
└─────────────────────────────────────────────────────────┘
```

---

## Prerequisites

- **Docker Engine:** 24.0+
- **Docker Compose:** v2.19.1+ (earlier versions have a bug where containers joining multiple networks silently attach to only one — no error, no warning)

Verify:

```bash
docker --version
docker compose version
```

---

## Fundamentals

### Network Types

Docker supports several network drivers. For local development, only two matter:

| Driver | What it does | When to use |
|---|---|---|
| **bridge** | Creates an isolated virtual network. Containers on the same bridge can talk to each other. | Default for all local development. |
| **host** | Container shares the host's network namespace directly. No isolation. | Rare. Linux only. See warning below. |
| **none** | No networking at all. | Almost never. |
| **overlay** | Multi-host networking for Docker Swarm. | Out of scope for local development. |

### Default Compose Behaviour

When you run `docker compose up`, Compose automatically creates a bridge network named `<project>_default`. All services in that Compose file join this network.

Services within the same Compose file can reach each other by service name:

```yaml
# api/docker-compose.yml
services:
  php-api:
    image: php:8.3-fpm
  php-worker:
    image: php:8.3-cli
```

Here `php-api` can reach `php-worker` by name, and vice versa. They are on the `api_default` bridge network.

**Services in different Compose files cannot reach each other by default.** They are on separate, isolated bridge networks. This is the central problem that the patterns in this guide solve.

### Port Mapping vs Container Networking

There are two ways for services to communicate:

**Port mapping** exposes a container's port to the host machine:

```yaml
ports:
  - "8080:80"    # host:container
```

Now `localhost:8080` on the host reaches the container's port 80. Other containers do **not** need port mapping to communicate — they use the internal network directly.

**Container-to-container** communication uses service names on shared networks. No port mapping needed:

```yaml
environment:
  DB_HOST: mysql       # just use the service name
  DB_PORT: 3306        # the container's internal port
```

### Host Network Mode — Linux Only

> `network_mode: host` makes the container share the host's network stack directly. On **macOS** (including OrbStack), "host" actually means the Linux VM's namespace, not the Mac's — services will not be reachable from the Mac as expected. **Never use host networking in Compose files shared across platforms.**

---

## Patterns

Each pattern follows the structure: **When to use → Compose snippets → How it works → Gotchas.**

All examples use the running example stacks (infra, api, frontend) and the `microservices` external network.

### Pattern A: Shared External Network

**When to use:** Multiple stacks need direct container-to-container communication. This is the most common and recommended pattern.

**How it works:** A network is created outside of any Compose project. Each stack declares it as `external: true` and joins it. All services on this network can resolve each other by name.

**infra/docker-compose.yml:**

```yaml
services:
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: secret
    ports:
      - "127.0.0.1:3306:3306"
    networks:
      - microservices

  rabbitmq:
    image: rabbitmq:3-management
    ports:
      - "127.0.0.1:15672:15672"
    networks:
      - microservices

  redis:
    image: redis:7-alpine
    networks:
      - microservices

networks:
  microservices:
    external: true
```

**api/docker-compose.yml:**

```yaml
services:
  php-api:
    build: .
    environment:
      DB_HOST: mysql
      DB_PORT: 3306
      RABBITMQ_HOST: rabbitmq
      REDIS_HOST: redis
    ports:
      - "127.0.0.1:8080:80"
    networks:
      - microservices

  php-worker:
    build: .
    command: php artisan queue:work
    environment:
      DB_HOST: mysql
      RABBITMQ_HOST: rabbitmq
    networks:
      - microservices

networks:
  microservices:
    external: true
```

**frontend/docker-compose.yml:**

```yaml
services:
  nginx:
    image: nginx:alpine
    ports:
      - "127.0.0.1:80:80"
    networks:
      - microservices

  node-app:
    build: .
    environment:
      API_URL: http://php-api:80
    networks:
      - microservices

networks:
  microservices:
    external: true
```

**Gotchas:**

- The `microservices` network must exist before running `docker compose up`. See the [Bootstrap Script](#bootstrap-script-for-new-developers) in Tips and Best Practices.
- **Service name collisions:** If two stacks both define a service called `redis`, one shadows the other on the shared network. Always use unique service names, or use network aliases (see DNS section).

---

### Pattern B: Shared Infrastructure Stack

**When to use:** You want one "always-on" stack that owns databases and message brokers. Application stacks connect to its network.

This is a variation of Pattern A where the infrastructure stack *creates* the network instead of it being pre-created externally:

```yaml
# infra/docker-compose.yml
services:
  mysql:
    image: mysql:8.0
    networks:
      - microservices

networks:
  microservices:
    name: microservices    # explicit name, prevents project-name prefixing
```

Other stacks reference it with `external: true` exactly as in Pattern A.

**Gotchas:**

- The infra stack **must** be started first. Other stacks will fail if the network does not exist yet.
- `docker compose down` on the infra stack removes the network and **breaks all connected stacks**. Use `docker compose stop` instead if you only want to stop the services.
- Pattern A (pre-created external network) is generally more robust because the network's lifecycle is independent of any stack.

---

### Pattern C: Gateway/Proxy with Traefik

**When to use:** You want browser-accessible hostnames like `api.localhost` and `app.localhost` instead of remembering port numbers. Useful when you have many stacks and run out of mental port-mapping capacity.

**gateway/docker-compose.yml:**

```yaml
services:
  traefik:
    image: traefik:v3.0
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=microservices"
      - "--entrypoints.web.address=:80"
    ports:
      - "80:80"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - microservices

networks:
  microservices:
    external: true
```

Then add labels to services in other stacks:

```yaml
# api/docker-compose.yml
services:
  php-api:
    build: .
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.api.rule=Host(`api.localhost`)"
      - "traefik.http.services.api.loadbalancer.server.port=80"
    networks:
      - microservices
```

Now `http://api.localhost` in a browser routes to the `php-api` container.

**How it works:** Traefik watches the Docker socket, discovers containers with `traefik.enable=true` labels, and routes requests based on the `Host()` rule to the correct container.

**Gotchas:**

- Requires Docker socket access. The `:ro` (read-only) mount is sufficient and recommended.
- `*.localhost` resolves to `127.0.0.1` on most systems without `/etc/hosts` entries.
- On OrbStack, `*.orb.local` domains work automatically for host→container access without Traefik. However, Traefik still provides consistent URLs across platforms.
- Port 80 must be free on the host. Stop any local web servers first.
- In this scenario, there is no SSL support and no custom domain support

---

## DNS and Service Discovery

### How Docker DNS Works

Every user-defined bridge network (including external networks) gets a built-in DNS resolver at `127.0.0.11`. When a container tries to resolve a hostname, Docker's resolver checks whether any container on the same network matches that name.

Resolution order:
1. **Service name** — the name defined in `docker-compose.yml` under `services:`
2. **Container name** — the full container name (e.g. `api-php-api-1`)
3. **Network aliases** — custom names assigned in the network configuration

This only works on **user-defined** networks. The legacy default `bridge` network does not support DNS resolution.

### Cross-Stack Resolution

Services on the same external network resolve each other by service name, regardless of which Compose project they belong to.

In our running example, `php-api` (from the `api` stack) can reach `mysql` (from the `infra` stack) simply by using `mysql` as the hostname:

```bash
# From inside the php-api container:
nslookup mysql
# Server:    127.0.0.11
# Address:   127.0.0.11#53
# Name:      mysql
# Address:   172.17.0.5
```

### Network Aliases

Aliases let you give services additional DNS names on specific networks. This is useful for stable, intention-revealing names or for avoiding collisions:

```yaml
services:
  php-api:
    build: .
    networks:
      microservices:
        aliases:
          - api
          - backend-api
```

Now other services can use `api` or `backend-api` as hostnames in addition to `php-api`.

**When to use aliases:**

- Two stacks have services with the same name (e.g. both have `app`). Give each an alias to disambiguate.
- You want a stable hostname that does not change if you rename the service.
- You want a shorter or more descriptive name (`db` instead of `mysql`).

### Avoid `container_name`

It is tempting to set `container_name` in Compose files to give containers predictable names. Do not do this:

```yaml
# Bad — do not use container_name for networking
services:
  php-api:
    container_name: my-api
```

Problems with `container_name`:
- **Breaks scaling.** `docker compose up --scale php-api=3` fails because container names must be unique.
- **Causes collisions across stacks.** Two stacks cannot both define `container_name: redis`.
- **Couples config to a single machine.** The name is global to the Docker daemon, not scoped to a project.

Instead, rely on the service name (which is the DNS name on shared networks by default) and use **network aliases** or the **`hostname`** option when you need a different name:

```yaml
services:
  php-api:
    build: .
    hostname: api            # sets the container's internal hostname
    networks:
      microservices:
        aliases:
          - api              # other containers resolve "api" to this service
          - backend
```

- **Service name** (`php-api`) — always resolvable on shared networks, scoped to the project.
- **`hostname`** — sets the container's own hostname (visible inside the container via `hostname` command). Does not affect DNS resolution for other containers.
- **Network aliases** — adds extra DNS names that other containers can use to reach this service.

Use aliases for cross-stack discovery and `hostname` for the container's internal identity. Never `container_name`.

### Avoid `links` and `external_links`

Both are legacy features from Docker Compose v1. Network aliases replace them entirely. If you encounter `links` or `external_links` in old Compose files, remove them and use shared networks with aliases instead.

### Name Collision Prevention

If two services on the same network have the same service name, behaviour is unpredictable — Docker may round-robin between them or one may shadow the other. There is no error or warning.

**Prevention:**
- Use unique, descriptive service names across all stacks (e.g. `auth-api` not just `api`)
- Use network aliases for shorter convenience names
- Run `docker network inspect microservices` to check for duplicate names

---

## Debugging and Troubleshooting

### Diagnostic Commands

When something is not connecting, run these commands in order:

```bash
# 1. List all networks — check your expected network exists
docker network ls

# 2. Inspect the shared network — shows connected containers and their IPs
docker network inspect microservices

# 3. Check which networks a specific container is on
docker inspect api-php-api-1 --format '{{json .NetworkSettings.Networks}}' | python3 -m json.tool

# 4. Test DNS resolution from inside a container
docker exec -it api-php-api-1 nslookup mysql

# 5. Test HTTP connectivity
docker exec -it api-php-api-1 curl -v http://mysql:3306

# 6. Test basic reachability
docker exec -it api-php-api-1 ping -c 3 rabbitmq
```

**If diagnostic tools are not available** in the container image (common with slim images), use a temporary debug container:

```bash
docker run --rm -it --network microservices alpine sh
# Inside the container:
apk add --no-cache curl bind-tools
nslookup mysql
curl -v http://php-api:80
ping -c 3 rabbitmq
```

### Common Pitfalls

| Symptom | Likely cause | Fix |
|---|---|---|
| `network foo declared as external, but could not be found` | Network not pre-created | Run `docker network create foo` or the bootstrap script |
| Service name resolves but connection refused | Target service not running, or not on the same network | Check `docker network inspect` for both containers |
| Intermittent DNS failures | Docker DNS resolver overloaded (rare, very large stacks) | Restart Docker daemon |
| Service A reaches B but not vice versa | Services on different networks | Verify both services join the same network in their Compose files |
| Container starts but cannot reach the internet | Network created with `internal: true` | Remove `internal: true` or add a second non-internal network |
| Can reach services by IP but not by name | Container on the legacy default `bridge` network | Docker DNS only works on user-defined networks; add a named network |
| `down` vs `stop` confusion: network disappears | `docker compose down` removes project networks; `stop` does not | Use `stop` for quick restarts, `down` for full cleanup |

### Default Address Pool Exhaustion

This problem appears when you run many Compose stacks over time. Docker's default configuration allocates enormous subnets (`/16` — 65,536 addresses) to each bridge network. The available address space only fits **~16 networks total**.

Each Compose project creates at least one network. If you accumulate 15+ stacks (including stopped ones whose networks were never cleaned up), you will exhaust the pool.

**Two failure modes:**

1. **Explicit failure** — Docker refuses to start a new stack with: `"could not find an available, non-overlapping IPv4 address pool among the defaults to assign to the network"`
2. **Silent routing failure** — Docker falls back to the `192.168.0.0/16` range, which overlaps with most home and office LANs. Containers start without error, but traffic gets misrouted between Docker and the real network. This causes mysterious connectivity failures with no clear error message.

**How to diagnose:**

```bash
# List all networks and their subnets
docker network ls -q | xargs docker network inspect --format '{{.Name}}: {{range .IPAM.Config}}{{.Subnet}}{{end}}'
```

If you see subnets in the `192.168.x.x` range, Docker has fallen back from its primary pool and may be overlapping with your LAN.

**The fix** — configure Docker to allocate `/24` subnets (254 addresses each) instead of `/16`. This gives ~256 available networks, more than enough for any local setup.

**Linux** — edit `/etc/docker/daemon.json`:

```json
{
  "default-address-pools": [
    { "base": "172.17.0.0/12", "size": 24 }
  ]
}
```

**macOS (OrbStack)** — run `orb config docker` or edit `~/.orbstack/config/docker.json` with the same JSON.

**Then clean up and restart:**

```bash
# Stop all stacks
docker compose -f infra/docker-compose.yml down
docker compose -f api/docker-compose.yml down
docker compose -f frontend/docker-compose.yml down

# Remove all unused networks (old oversized subnets)
docker network prune -f

# Restart Docker to pick up the new config
sudo systemctl restart docker    # Linux
orb restart docker               # macOS (OrbStack)

# Recreate networks and bring stacks back up
./init-networks.sh
docker compose -f infra/docker-compose.yml up -d
docker compose -f api/docker-compose.yml up -d
docker compose -f frontend/docker-compose.yml up -d
```

### VPN Interaction

Corporate VPNs (especially WireGuard, Cisco AnyConnect, GlobalProtect) frequently claim subnet ranges that overlap with Docker's defaults. This is the most common *trigger* for hitting address pool exhaustion — the VPN reserves subnets, leaving Docker with fewer to allocate.

**Symptoms:** Connectivity breaks when VPN connects. Containers that were working fine suddenly cannot reach each other or the internet.

**Diagnosis:**

```bash
# Check routing table for conflicts
ip route | grep -E '172\.(1[6-9]|2[0-9]|3[01])\.'
```

If you see VPN routes in the `172.16–172.31` range, they overlap with Docker's default pool.

**Fix:** Ensure Docker's `base` in `daemon.json` does not overlap with your VPN's assigned ranges. If your VPN uses `172.16.0.0/12`, consider an alternative base like `10.200.0.0/16`:

```json
{
  "default-address-pools": [
    { "base": "10.200.0.0/16", "size": 24 }
  ]
}
```

### Compose Multi-Network Race Condition

Docker Compose versions before **v2.19.1** had a bug where containers joining multiple networks would silently attach to only one. No error or warning is logged — the container simply cannot reach services on the missed network.

**Fix:** Upgrade Compose.

```bash
docker compose version
# Must be v2.19.1 or later
```

---

## macOS Parity with OrbStack

This guide is Linux-primary. macOS developers should use **OrbStack** — not Docker Desktop — for the best networking experience.

### Why OrbStack

| Aspect | Docker Desktop | OrbStack |
|---|---|---|
| Container start speed | Baseline | Up to 60% faster |
| Resource usage | Heavy (CPU, memory, disc) | Minimal footprint |
| Networking | Standard Docker bridge | Custom stack, up to 45 Gbps host↔container |
| VPN compatibility | Frequent conflicts | Seamless, follows macOS DNS/proxy settings |
| Service discovery | Port mapping or manual DNS | Automatic `container-name.orb.local` domains |
| x86 emulation (Apple Silicon) | QEMU | Rosetta (significantly faster) |
| Bind mount performance | Slow (gRPC-FUSE) | Fast (VirtioFS) |

### Installation

Install from [orbstack.dev](https://orbstack.dev). OrbStack replaces the Docker CLI automatically and creates an `orbstack` Docker context. Existing Compose files and Docker commands work without changes.

If you previously used Docker Desktop, re-login to any private container registries — OrbStack uses the `osxkeychain` credential store (Docker Desktop uses `desktop`).

### Network Configuration

If you hit the default address pool exhaustion problem (see [Debugging and Troubleshooting](#default-address-pool-exhaustion)), the `default-address-pools` fix is configured via:

```bash
orb config docker
```

Or edit `~/.orbstack/config/docker.json` directly. Then restart:

```bash
orb restart docker
```

### `*.orb.local` Domains

OrbStack automatically gives every container a DNS name accessible from the Mac:

```
container-name.orb.local
```

For example, with our running example:

```bash
curl http://mysql.orb.local:3306
curl http://php-api.orb.local:80
curl http://nginx.orb.local:80
```

No port mapping needed for host→container access during development.

> **Portability warning:** Do **not** hardcode `.orb.local` hostnames into application configuration, environment files, or Compose files. These names only work on OrbStack and will break on Linux and in CI pipelines. Use Docker service names for container-to-container communication (works everywhere). Reserve `.orb.local` for browser access from the Mac only.

### Volume Mount Permissions (Linux vs macOS)

When developing locally, you typically bind-mount your cloned repository into the container:

```yaml
services:
  php-api:
    build: .
    volumes:
      - ./:/app
```

**On macOS (OrbStack and Docker Desktop),** file permissions are handled transparently. The virtualisation layer maps host user permissions to the container automatically — files created inside the container appear owned by your Mac user, and vice versa. You do not need to think about UIDs or GIDs.

**On Linux, there is no such magic.** Docker runs natively, and the container process's UID/GID must match the host user's UID/GID, or you will hit permission problems:

- Files created inside the container (e.g. by `composer install`, `npm install`, or a build process) are owned by the container's user (often `root` — UID 0). On the host, these files appear as owned by root, and your editor or `git` may not be able to modify them.
- Conversely, if the container process runs as a non-root user (e.g. `www-data` — UID 33), it may not have permission to read or write files owned by your host user (typically UID 1000).

**Symptoms:**
- `Permission denied` errors when the container tries to write to `/app`
- `git` on the host shows unexpected file ownership changes
- Build artefacts (e.g. `vendor/`, `node_modules/`) created inside the container are unwritable on the host

**Solutions for Linux:**

**Option A: Match UID/GID in the Dockerfile** (recommended)

Build your development image so the application user's UID/GID matches the host user's (usually 1000:1000 on single-user Linux systems):

```dockerfile
FROM php:8.3-fpm

ARG UID=1000
ARG GID=1000

RUN groupmod -g ${GID} www-data \
    && usermod -u ${UID} -g ${GID} www-data

USER www-data
WORKDIR /app
```

Pass the values at build time if they differ per developer:

```yaml
services:
  php-api:
    build:
      context: .
      args:
        UID: ${UID:-1000}
        GID: ${GID:-1000}
    volumes:
      - ./:/app
```

Each developer sets `UID` and `GID` in their `.env` file:

```env
UID=1000
GID=1000
```

**Option B: Use `user` in Compose**

If the image does not need a custom Dockerfile, pass the host user's UID/GID directly:

```yaml
services:
  node-app:
    image: node:20-alpine
    user: "${UID:-1000}:${GID:-1000}"
    volumes:
      - ./:/app
    working_dir: /app
```

This is simpler but some images expect a specific user and may not work correctly with an arbitrary UID.

**Option C: `fixuid` or entrypoint script**

For images where you cannot easily change the UID at build time, use an entrypoint script that adjusts permissions at startup:

```bash
#!/bin/bash
# docker-entrypoint.sh
usermod -u ${HOST_UID:-1000} www-data 2>/dev/null
groupmod -g ${HOST_GID:-1000} www-data 2>/dev/null
exec gosu www-data "$@"
```

This adds startup overhead and complexity — prefer Option A when possible.

> **Key takeaway:** macOS developers will never encounter this problem. If your team works across both platforms, include the UID/GID build args in your Dockerfiles by default — it costs nothing on macOS and prevents hours of debugging on Linux.

### Cross-Platform Parity Matrix

| Feature | Linux (Docker Engine) | macOS (OrbStack) | Notes |
|---|---|---|---|
| Bridge networks | Yes | Yes | Identical behaviour |
| External shared networks | Yes | Yes | Identical |
| DNS service discovery | Yes | Yes | Identical |
| `default-address-pools` | Yes | Yes | Different config file path |
| Host network mode | Yes | **No** | Linux only — do not use in shared Compose files |
| `*.orb.local` domains | No | Yes | OrbStack-specific, host access only |
| Port binding `127.0.0.1:` | Yes | Yes | Identical |
| VPN compatibility | Manual config | Automatic | OrbStack handles VPN integration |
| Traefik gateway | Yes | Yes | Identical |
| Bind mount performance | Native | VirtioFS (fast) | OrbStack significantly faster than Docker Desktop |
| Volume mount permissions | **Manual UID/GID mapping** | Automatic | Linux requires explicit UID/GID matching |

---

## Tips and Best Practices

### Bootstrap Script for New Developers

When using the Shared External Network pattern (Pattern A), external networks must exist before `docker compose up` can reference them. Without this, new developers will see:

```
network microservices declared as external, but could not be found
```

Create an idempotent bootstrap script that everyone runs once after cloning the repositories:

```bash
#!/bin/bash
# init-networks.sh — run once per machine
# Safe to run multiple times

docker network create microservices 2>/dev/null || true

echo "Networks ready. You can now run docker compose up in each stack."
```

Add a `Makefile` target for convenience:

```makefile
init:
	@./init-networks.sh
```

New developers: clone repos → `make init` → `docker compose up` in each stack.

### Naming Conventions

Use consistent, descriptive names for external networks and services:

- **Networks:** `microservices`, `shared-infra`, `monitoring`. Avoid generic names like `default` or `net`.
- **Services:** Prefix with domain context: `auth-api`, `order-worker`, `billing-db`. Avoid bare names like `api` or `db` that collide across stacks.

### Environment Variables for Network Names

Store network names in `.env` files to keep Compose files consistent across stacks:

```env
# .env (shared across stacks or copied to each)
NETWORK_NAME=microservices
```

```yaml
networks:
  app-network:
    name: ${NETWORK_NAME}
    external: true
```

### `docker compose down` vs `stop`

| Command | Stops containers | Removes containers | Removes project networks |
|---|---|---|---|
| `docker compose stop` | Yes | No | No |
| `docker compose down` | Yes | Yes | Yes |
| `docker compose down -v` | Yes | Yes | Yes + named volumes |

Use `stop` for quick restart cycles during development. Use `down` for full cleanup. Be careful with `down` on stacks that own shared networks (Pattern B) — it will break other stacks.

### Startup Ordering with Health Checks

Within a single stack, use `depends_on` with `condition: service_healthy`:

```yaml
services:
  php-api:
    depends_on:
      mysql:
        condition: service_healthy

  mysql:
    image: mysql:8.0
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 5s
      timeout: 3s
      retries: 10
```

For **cross-stack** dependencies (e.g. the `api` stack needs `mysql` from the `infra` stack), there is no built-in ordering. Instead:

1. The bootstrap script ensures the network exists.
2. Start the infra stack first.
3. Application code should retry connections on startup (standard practice for microservices).

### Compose Profiles for Optional Services

Use `profiles` to keep debugging and monitoring tools available without starting them by default:

```yaml
services:
  mailhog:
    image: mailhog/mailhog
    profiles: ["debug"]
    ports:
      - "127.0.0.1:8025:8025"
    networks:
      - microservices

  phpmyadmin:
    image: phpmyadmin:latest
    profiles: ["debug"]
    environment:
      PMA_HOST: mysql
    ports:
      - "127.0.0.1:8081:80"
    networks:
      - microservices
```

```bash
# Normal startup — debug tools are not started
docker compose up -d

# Start with debug tools
docker compose --profile debug up -d
```

### Network Isolation for Databases

For better security, put databases on both a shared network (for application access) and an `internal` network (for tools that should not reach the internet):

```yaml
services:
  mysql:
    image: mysql:8.0
    networks:
      - microservices
      - db-internal

  mysql-backup:
    image: databack/mysql-backup
    networks:
      - db-internal    # can reach mysql, but not the internet

networks:
  microservices:
    external: true
  db-internal:
    internal: true     # no external routing
```

### Cleanup Routine

Networks accumulate over time. Periodically clean up:

```bash
# Review existing networks
docker network ls

# Remove all networks not currently used by any container
docker network prune

# For a full reset (removes containers, networks, and dangling images):
docker system prune
```

`docker network prune` only removes networks with zero attached containers. It is safe when all stacks are stopped, but will remove networks that idle stacks expect to exist. Re-run the bootstrap script after pruning.

---

## Quick Reference

```bash
# ── First-Time Setup ──────────────────────────────────
./init-networks.sh                       # create shared networks

# ── Daily Commands ────────────────────────────────────
docker compose up -d                     # start a stack (detached)
docker compose stop                      # stop without removing networks
docker compose down                      # stop + remove project networks
docker compose --profile debug up -d     # start with optional services

# ── Debugging ─────────────────────────────────────────
docker network ls                        # list all networks
docker network inspect microservices     # show containers and IPs on network
docker exec -it <ctr> nslookup <svc>     # test DNS resolution
docker exec -it <ctr> curl <svc>:80      # test HTTP connectivity
docker exec -it <ctr> ping -c3 <svc>     # test basic reachability

# Quick debug container (when tools missing in target image):
docker run --rm -it --network microservices alpine sh
# then: apk add curl bind-tools

# ── Diagnostics ───────────────────────────────────────
docker compose version                   # must be v2.19.1+
docker network ls -q | xargs docker network inspect \
  --format '{{.Name}}: {{range .IPAM.Config}}{{.Subnet}}{{end}}'
                                         # show all network subnets
ip route | grep 172                      # check for VPN conflicts

# ── Address Pool Exhaustion Fix (if needed) ──────────
sudo nano /etc/docker/daemon.json        # add default-address-pools
sudo systemctl restart docker            # then: docker network prune -f

# ── Cleanup ───────────────────────────────────────────
docker network prune                     # remove unused networks
docker system prune                      # remove unused everything (careful)
```
