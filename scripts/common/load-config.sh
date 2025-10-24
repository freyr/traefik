#!/bin/bash

# Common configuration loader for all scripts
# Source this file at the beginning of scripts to load environment variables

# Determine project root (2 levels up from scripts/common/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load .env file if it exists
ENV_FILE="${PROJECT_ROOT}/.env"
if [ -f "$ENV_FILE" ]; then
    # Export all variables from .env file
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "Warning: .env file not found at $ENV_FILE"
    echo "Please copy .env.example to .env and configure it:"
    echo "  cp .env.example .env"
    echo ""
    exit 1
fi

# Validate required variables
required_vars=(
    "DOMAIN"
    "LOOPBACK_IP"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -gt 0 ]; then
    echo "Error: Missing required configuration variables in .env:"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    echo ""
    echo "Please update your .env file based on .env.example"
    exit 1
fi

# Set defaults for optional variables
export LOOPBACK_NETMASK="${LOOPBACK_NETMASK:-255.240.0.0}"
export SSL_DIR="${SSL_DIR:-./ssl}"
export CERT_FILE="${CERT_FILE:-${DOMAIN}.crt}"
export KEY_FILE="${KEY_FILE:-${DOMAIN}.key}"
export DOCKER_NETWORK_NAME="${DOCKER_NETWORK_NAME:-local}"
export TRAEFIK_LOG_LEVEL="${TRAEFIK_LOG_LEVEL:-INFO}"
export CLOUDFLARE_CREDENTIALS_FILE="${CLOUDFLARE_CREDENTIALS_FILE:-~/.secrets/cloudflare.ini}"
export LETSENCRYPT_CERT_DIR="${LETSENCRYPT_CERT_DIR:-/etc/letsencrypt/live/${DOMAIN}}"

# Expand relative paths to absolute paths
if [[ "${SSL_DIR}" != /* ]]; then
    export SSL_DIR="${PROJECT_ROOT}/${SSL_DIR}"
fi

# Expand tilde in paths
export CLOUDFLARE_CREDENTIALS_FILE="${CLOUDFLARE_CREDENTIALS_FILE/#\~/$HOME}"
