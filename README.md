# Traefik Local Development Environment

Local HTTPS development environment using Traefik reverse proxy with Let's Encrypt wildcard certificates.

## Features

- ✅ **Wildcard HTTPS** for `*.example.dev` domains
- ✅ **Local routing** via loopback alias (configurable IP)
- ✅ **Automatic SSL** with Let's Encrypt certificates
- ✅ **Service discovery** via Docker labels
- ✅ **Automatic renewal** (optional)
- ✅ **Configurable** via `.env` file
- ✅ **Team-friendly** setup with admin/member roles

## Use Cases

### Personal Development
Set up your own domain, DNS, and certificates for local HTTPS development.

### Team Development
- **Admin**: Configure DNS and certificates once
- **Team Members**: Use shared domain and certificates

## Prerequisites

**All Users:**
- Docker & Docker Compose installed
- macOS 10.15+ or Linux with systemd

**Admin Only (for initial setup):**
- Domain with DNS management access (Cloudflare recommended)
- Certbot: `brew install certbot` (macOS) or `apt install certbot` (Linux)

## Quick Start

### For Personal Use or Team Admin

```bash
# 1. Clone and configure
git clone <repository-url>
cd traefik
cp .env.example .env
nano .env  # Edit DOMAIN, LOOPBACK_IP, LETSENCRYPT_EMAIL

# 2. Initialize
make init

# 3. Configure DNS (one-time)
# Add DNS A record: *.example.dev → 172.16.123.1

# 4. Generate SSL certificate (one-time)
make help-ssl  # Shows certificate generation instructions

# 5. Copy certificates
make setup-certs

# 6. Start Traefik
make create
```

### For Team Members

If your admin has already set up DNS and certificates:

```bash
# 1. Clone and configure
git clone <repository-url>
cd traefik
cp .env.example .env
nano .env  # Use DOMAIN provided by admin

# 2. Initialize
make init

# 3. Get certificates from admin
# Place .crt and .key files in ssl/ directory

# 4. Start Traefik
make create
```

**See [SETUP.md](SETUP.md) for detailed step-by-step instructions.**

## Configuration

All settings are configured via `.env` file:

```bash
cp .env.example .env
nano .env
```

**Key settings:**

| Variable | Description | Default |
|----------|-------------|---------|
| `DOMAIN` | Your domain name | `example.dev` |
| `LOOPBACK_IP` | Loopback IP address | `172.16.123.1` |
| `LETSENCRYPT_EMAIL` | Email for Let's Encrypt notifications | - |
| `CLOUDFLARE_API_TOKEN` | For automated renewals (optional) | - |

**See `.env.example` for all available options.**

## Common Commands

### Setup & Configuration
```bash
make init              # Initialize project (first time)
make check-env         # Verify .env and regenerate configs
make help-ssl          # Show SSL certificate generation help
```

### Traefik
```bash
make create            # Full setup (network + loopback + start)
make start             # Start Traefik
make stop              # Stop Traefik
make destroy           # Remove everything
```

### Network & Loopback
```bash
make create-network    # Create Docker network
make create-loopback   # Setup loopback alias (requires sudo)
make remove-loopback   # Remove loopback alias
```

### Certificates (Admin Only)
```bash
make setup-certs           # Copy certificates from Let's Encrypt
make install-renew-hook    # Install post-renewal hook
make setup-auto-renewal    # Setup automatic renewal (macOS)
make test-renewal          # Test renewal process
make check-renewal-status  # Check if auto-renewal is configured
```

## How It Works

### Architecture Overview

This setup creates a local HTTPS reverse proxy using Traefik and Docker:

```
Browser Request (https://myapp.example.dev)
    ↓
DNS Resolution (*.example.dev → 172.16.123.1)
    ↓
Loopback Alias (172.16.123.1 on lo0/lo interface)
    ↓
Traefik (listening on 172.16.123.1:443 with SSL)
    ↓
Docker Network (local)
    ↓
Your Application Container (via service discovery)
```

### Step-by-Step Flow

1. **Configuration** (`.env` file)
   - Defines your domain, loopback IP, and certificate paths
   - Generates Traefik configuration from templates

2. **DNS Resolution** (Wildcard DNS)
   - `*.example.dev` resolves to your loopback IP (e.g., `172.16.123.1`)
   - Configured once at your DNS provider (Cloudflare, etc.)
   - All subdomains automatically resolve to your local machine

3. **Loopback Alias** (Network Interface)
   - System-level network alias on loopback interface
   - Allows binding to private IP without actual network adapter
   - Persists across reboots (via LaunchDaemon/systemd)

4. **Traefik** (Reverse Proxy)
   - Listens on `172.16.123.1:80` (HTTP) and `172.16.123.1:443` (HTTPS)
   - Automatically redirects HTTP → HTTPS
   - Uses wildcard SSL certificate for all subdomains
   - Discovers services via Docker labels

5. **Service Discovery** (Docker Labels)
   - Traefik watches Docker for containers with `traefik.enable=true`
   - Reads routing rules from container labels
   - Automatically configures routes and SSL

6. **SSL Termination**
   - Traefik handles SSL/TLS with Let's Encrypt certificates
   - Services receive plain HTTP traffic internally
   - Automatic HTTPS for all configured services

### Key Components

**Traefik Configuration:**
- `traefik.toml` - Static configuration (entrypoints, providers)
- `configs/certs.toml` - TLS certificate configuration (generated)
- Docker provider - Automatic service discovery

**Docker Network:**
- `local` - External bridge network
- All services must connect to this network
- Traefik and your applications communicate here

**SSL Certificates:**
- Wildcard certificate (`*.example.dev`)
- Single certificate covers all subdomains
- Stored in `ssl/` directory

### Learn More

For detailed information about Traefik configuration:
- **[Traefik Documentation](https://doc.traefik.io/traefik/)** - Official docs
- **[Docker Provider](https://doc.traefik.io/traefik/providers/docker/)** - Docker integration
- **[Routing & Labels](https://doc.traefik.io/traefik/routing/providers/docker/)** - Label configuration
- **[TLS Configuration](https://doc.traefik.io/traefik/https/tls/)** - SSL/TLS setup
- **[Routers](https://doc.traefik.io/traefik/routing/routers/)** - HTTP/HTTPS routing rules

## Adding Services

### Basic Example

Add a service to your application's `docker-compose.yaml`:

```yaml
services:
  myapp:
    image: myapp:latest
    networks:
      - local
    labels:
      # Enable Traefik for this service
      traefik.enable: true

      # HTTP Router configuration
      traefik.http.routers.myapp.rule: "Host(`myapp.example.dev`)"
      traefik.http.routers.myapp.entrypoints: websecure
      traefik.http.routers.myapp.tls: true

      # Service configuration (tell Traefik which port to use)
      traefik.http.services.myapp.loadbalancer.server.port: 8080

networks:
  local:
    external: true
```

Access at: `https://myapp.example.dev`

### Label Explanation

| Label | Purpose | Example |
|-------|---------|---------|
| `traefik.enable` | Enable Traefik for this container | `true` |
| `traefik.http.routers.<name>.rule` | Routing rule (domain matching) | `"Host(\`app.example.dev\`)"` |
| `traefik.http.routers.<name>.entrypoints` | Which entrypoint to use | `websecure` (HTTPS) |
| `traefik.http.routers.<name>.tls` | Enable TLS/SSL | `true` |
| `traefik.http.services.<name>.loadbalancer.server.port` | Container's internal port | `8080`, `3000`, etc. |

**Note**: Replace `<name>` with your service name (e.g., `myapp`, `api`, `frontend`).

### Advanced Examples

#### Multiple Domains

Route multiple domains to the same service:

```yaml
labels:
  traefik.enable: true
  traefik.http.routers.myapp.rule: "Host(`app.example.dev`) || Host(`www.example.dev`)"
  traefik.http.routers.myapp.entrypoints: websecure
  traefik.http.routers.myapp.tls: true
  traefik.http.services.myapp.loadbalancer.server.port: 8080
```

#### Path-Based Routing

Route based on URL path:

```yaml
labels:
  traefik.enable: true
  traefik.http.routers.api.rule: "Host(`example.dev`) && PathPrefix(`/api`)"
  traefik.http.routers.api.entrypoints: websecure
  traefik.http.routers.api.tls: true
  traefik.http.services.api.loadbalancer.server.port: 3000

  # Strip /api prefix before forwarding
  traefik.http.routers.api.middlewares: api-stripprefix
  traefik.http.middlewares.api-stripprefix.stripprefix.prefixes: /api
```

#### Multiple Services (Frontend + Backend)

```yaml
services:
  frontend:
    image: my-frontend:latest
    networks:
      - local
    labels:
      traefik.enable: true
      traefik.http.routers.frontend.rule: "Host(`example.dev`)"
      traefik.http.routers.frontend.entrypoints: websecure
      traefik.http.routers.frontend.tls: true
      traefik.http.services.frontend.loadbalancer.server.port: 80

  backend:
    image: my-backend:latest
    networks:
      - local
    labels:
      traefik.enable: true
      traefik.http.routers.backend.rule: "Host(`api.example.dev`)"
      traefik.http.routers.backend.entrypoints: websecure
      traefik.http.routers.backend.tls: true
      traefik.http.services.backend.loadbalancer.server.port: 3000

networks:
  local:
    external: true
```

Access:
- Frontend: `https://example.dev`
- Backend: `https://api.example.dev`

### Traefik Labels Reference

For complete label documentation, see:
- **[Docker Labels](https://doc.traefik.io/traefik/routing/providers/docker/#routing-configuration-with-labels)** - All available labels
- **[Routers](https://doc.traefik.io/traefik/routing/routers/)** - Router configuration
- **[Services](https://doc.traefik.io/traefik/routing/services/)** - Service configuration
- **[Middlewares](https://doc.traefik.io/traefik/middlewares/overview/)** - Middleware options (auth, headers, etc.)

### Common Patterns

**API with CORS:**
```yaml
traefik.http.routers.api.middlewares: api-cors
traefik.http.middlewares.api-cors.headers.accesscontrolallowmethods: GET,POST,PUT,DELETE
traefik.http.middlewares.api-cors.headers.accesscontrolalloworigin: "*"
```

**Basic Auth:**
```yaml
traefik.http.routers.admin.middlewares: admin-auth
traefik.http.middlewares.admin-auth.basicauth.users: "admin:$$apr1$$..."
```

**Redirect www to non-www:**
```yaml
traefik.http.routers.www-redirect.rule: "Host(`www.example.dev`)"
traefik.http.routers.www-redirect.middlewares: redirect-www
traefik.http.middlewares.redirect-www.redirectregex.regex: "^https://www\\.(.+)"
traefik.http.middlewares.redirect-www.redirectregex.replacement: "https://$${1}"
```

## Project Structure

```
traefik/
├── .env.example           # Environment configuration template
├── .env                   # Your personal config (gitignored)
├── Makefile              # Development workflow automation
├── compose.yaml          # Docker Compose configuration
├── traefik.toml          # Traefik static configuration
├── scripts/              # Automation scripts
│   ├── common/          # Shared utilities
│   ├── loopback/        # Loopback alias management
│   ├── certificates/    # SSL certificate management
│   └── setup/           # Setup and config generation
├── configs/             # Traefik dynamic configuration
│   ├── certs.toml.template  # TLS template
│   └── certs.toml       # Generated TLS config (gitignored)
├── ssl/                 # SSL certificates (gitignored)
└── guides/              # Detailed guides
    ├── cloudflare-dns-plugin.md
    ├── certificate-distribution.md
    └── certificate-renewal-issues.md
```

## Documentation

- **[SETUP.md](SETUP.md)** - Detailed step-by-step setup guide
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - How to contribute to this project
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions
- **[CLAUDE.md](CLAUDE.md)** - Guide for Claude Code AI assistant

### Guides
- **[Cloudflare DNS Plugin](guides/cloudflare-dns-plugin.md)** - Automated certificate renewal
- **[Certificate Distribution](guides/certificate-distribution.md)** - Sharing certificates with team
- **[Certificate Renewal Issues](guides/certificate-renewal-issues.md)** - Troubleshooting renewal

## Troubleshooting

### Quick Checks

```bash
# DNS resolution
dig traefik.example.dev  # Should return your LOOPBACK_IP

# Loopback alias
ifconfig lo0 | grep 172.16.123.1  # macOS
ifconfig lo | grep 172.16.123.1   # Linux

# Traefik status
docker compose ps
docker compose logs traefik --tail=20

# Certificate validity
openssl x509 -in ssl/example.dev.crt -noout -dates
```

**See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions.**

## Platform Support

| Platform | Support | Notes |
|----------|---------|-------|
| macOS | ✅ Full | Automated scripts, LaunchDaemon |
| Linux | ✅ Full | Automated scripts, systemd |
| Windows | ⚠️ Not tested | Manual setup required |

## Security Notes

- **Development only** - Not for production use
- Private keys stored in `ssl/` (gitignored)
- Never commit certificates to version control
- See [guides/certificate-distribution.md](guides/certificate-distribution.md) for team sharing

## Requirements

- Docker 20.10+
- Docker Compose 2.0+
- Certbot (for certificate generation)
- Domain with DNS management access

## Support

- **Issues**: Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Setup Help**: See [SETUP.md](SETUP.md)
- **Contributing**: See [CONTRIBUTING.md](CONTRIBUTING.md)
