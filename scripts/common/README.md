# Common Scripts

Shared utilities used by other scripts in the project.

## Files

### load-config.sh
Configuration loader that reads `.env` file and exports environment variables.

**Usage:**
```bash
# Source this file at the beginning of your script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../common/load-config.sh"

# Now you can use environment variables
echo "Domain: ${DOMAIN}"
echo "Loopback IP: ${LOOPBACK_IP}"
```

**Features:**
- Automatically locates and loads `.env` file from project root
- Validates required configuration variables
- Sets defaults for optional variables
- Expands relative paths to absolute paths
- Handles tilde (`~`) expansion in paths

**Validated Variables:**
- `DOMAIN` - Required
- `LOOPBACK_IP` - Required

**Default Values:**
- `LOOPBACK_NETMASK` - Defaults to `255.240.0.0`
- `SSL_DIR` - Defaults to `./ssl`
- `CERT_FILE` - Defaults to `${DOMAIN}.crt`
- `KEY_FILE` - Defaults to `${DOMAIN}.key`
- `DOCKER_NETWORK_NAME` - Defaults to `local`
- `TRAEFIK_LOG_LEVEL` - Defaults to `INFO`
- `CLOUDFLARE_CREDENTIALS_FILE` - Defaults to `~/.secrets/cloudflare.ini`
- `LETSENCRYPT_CERT_DIR` - Defaults to `/etc/letsencrypt/live/${DOMAIN}`

## Error Handling

If `.env` file is not found or required variables are missing, the script will:
1. Display an error message
2. Show instructions for creating/updating `.env`
3. Exit with status code 1

## Example

```bash
#!/bin/bash

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../common/load-config.sh"

# Use configuration variables
echo "Setting up for domain: ${DOMAIN}"
echo "Loopback IP: ${LOOPBACK_IP}"
```
