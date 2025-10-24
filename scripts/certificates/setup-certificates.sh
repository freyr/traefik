#!/bin/bash

# Setup script for copying Let's Encrypt certificates to Traefik
# This script should be run after obtaining certificates from certbot

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../common/load-config.sh"

# Check if running as root (needed to access Let's Encrypt certs)
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo to access Let's Encrypt certificates"
    exit 1
fi

CERT_DIR="${LETSENCRYPT_CERT_DIR}"
TARGET_DIR="${SSL_DIR}"

# Check if certificate exists
if [ ! -d "$CERT_DIR" ]; then
    echo "Error: Certificate directory not found: $CERT_DIR"
    echo ""
    echo "Please generate the certificate first using:"
    echo "  sudo certbot certonly --manual --preferred-challenges dns -d '*.${DOMAIN}' -d '${DOMAIN}'"
    exit 1
fi

echo "Copying certificates from Let's Encrypt to Traefik..."

# Copy certificate (fullchain includes intermediate certs)
cp "${CERT_DIR}/fullchain.pem" "${TARGET_DIR}/${CERT_FILE}"
echo "✓ Copied certificate: ${TARGET_DIR}/${CERT_FILE}"

# Copy private key
cp "${CERT_DIR}/privkey.pem" "${TARGET_DIR}/${KEY_FILE}"
echo "✓ Copied private key: ${TARGET_DIR}/${KEY_FILE}"

# Set correct permissions (readable by Docker)
chmod 644 "${TARGET_DIR}/${CERT_FILE}"
chmod 644 "${TARGET_DIR}/${KEY_FILE}"
echo "✓ Set permissions to 644"

# Change ownership to the user who invoked sudo
if [ -n "$SUDO_USER" ]; then
    chown "$SUDO_USER:$(id -gn "$SUDO_USER")" "${TARGET_DIR}/${CERT_FILE}"
    chown "$SUDO_USER:$(id -gn "$SUDO_USER")" "${TARGET_DIR}/${KEY_FILE}"
    echo "✓ Changed ownership to $SUDO_USER"
fi

echo ""
echo "✓ Certificates successfully copied!"
echo ""
echo "Certificate details:"
openssl x509 -in "${TARGET_DIR}/${CERT_FILE}" -noout -dates -subject
echo ""
echo "Next steps:"
echo "  1. Restart Traefik: docker compose restart traefik"
echo "  2. Test access: curl -k https://${TRAEFIK_DASHBOARD_SUBDOMAIN}.${DOMAIN}"
