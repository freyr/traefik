# Setup Scripts

Scripts for initial project setup and configuration generation.

## Files

### generate-configs.sh
Generates configuration files from templates using environment variables from `.env`.

**Usage:**
```bash
./scripts/setup/generate-configs.sh
# OR
make check-env
```

**What it generates:**
- `configs/certs.toml` - TLS certificate configuration for Traefik

**When to run:**
- After copying `.env.example` to `.env`
- After modifying domain or certificate settings in `.env`
- Before starting Traefik for the first time

**Example:**
```bash
# 1. Copy and configure .env
cp .env.example .env
nano .env  # Edit DOMAIN, LOOPBACK_IP, etc.

# 2. Generate configurations
./scripts/setup/generate-configs.sh

# Output:
# ✓ Generated /path/to/traefik/configs/certs.toml
#
# Domain: example.dev
# Certificate: example.dev.crt
# Key: example.dev.key
```

## Templates

Configuration templates are located in their respective directories:
- `configs/certs.toml.template` - TLS certificate configuration template

Templates use `{{VARIABLE}}` syntax for substitution.

## Integration with Makefile

The `make check-env` target automatically runs `generate-configs.sh`:

```bash
make check-env  # Verifies .env and generates configs
make init       # First-time setup (includes check-env)
make create     # Start Traefik (includes check-env)
```

## Error Handling

If `.env` file is missing or required variables are not set, the script will exit with an error message and instructions.
