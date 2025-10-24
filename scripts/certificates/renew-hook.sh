#!/bin/bash

# Let's Encrypt renewal hook for Traefik
# This script is called by certbot after successful certificate renewal
#
# Installation:
#   1. Update TRAEFIK_DIR below to point to your Traefik installation
#   2. Copy this script to: /etc/letsencrypt/renewal-hooks/deploy/traefik-renew.sh
#   3. Make it executable: sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/traefik-renew.sh
#
# Certbot will automatically run this script after renewing certificates

set -e

# IMPORTANT: Update this path to your Traefik installation
TRAEFIK_DIR="/path/to/your/traefik"

# Load configuration from the Traefik installation
if [ ! -f "${TRAEFIK_DIR}/.env" ]; then
    echo "Error: .env file not found at ${TRAEFIK_DIR}/.env"
    echo "Please update TRAEFIK_DIR in this script to point to your Traefik installation"
    exit 1
fi

# Load environment variables
set -a
source "${TRAEFIK_DIR}/.env"
set +a

CERT_DIR="${LETSENCRYPT_CERT_DIR:-/etc/letsencrypt/live/${DOMAIN}}"
TARGET_DIR="${TRAEFIK_DIR}/${SSL_DIR#./}"
CERT_FILE="${CERT_FILE:-${DOMAIN}.crt}"
KEY_FILE="${KEY_FILE:-${DOMAIN}.key}"

echo "[$(date)] Let's Encrypt renewal hook triggered"

# Check if certificate was renewed
if [ ! -f "${CERT_DIR}/fullchain.pem" ]; then
    echo "Error: Certificate not found at ${CERT_DIR}/fullchain.pem"
    exit 1
fi

echo "Copying renewed certificates..."

# Copy certificate files
cp "${CERT_DIR}/fullchain.pem" "${TARGET_DIR}/${CERT_FILE}"
cp "${CERT_DIR}/privkey.pem" "${TARGET_DIR}/${KEY_FILE}"

# Set correct permissions
chmod 644 "${TARGET_DIR}/${CERT_FILE}"
chmod 644 "${TARGET_DIR}/${KEY_FILE}"

# Get the original user (the one who owns the Traefik directory)
OWNER=$(stat -f '%Su' "${TRAEFIK_DIR}")
OWNER_GROUP=$(stat -f '%Sg' "${TRAEFIK_DIR}")
chown "${OWNER}:${OWNER_GROUP}" "${TARGET_DIR}/${CERT_FILE}"
chown "${OWNER}:${OWNER_GROUP}" "${TARGET_DIR}/${KEY_FILE}"

echo "✓ Certificates copied successfully"

# Restart Traefik if running
if command -v docker &> /dev/null; then
    cd "${TRAEFIK_DIR}"
    if docker compose ps | grep -q "traefik.*Up"; then
        echo "Restarting Traefik..."
        docker compose restart traefik
        echo "✓ Traefik restarted"
    else
        echo "Note: Traefik is not running, skipping restart"
    fi
fi

echo "[$(date)] Certificate renewal completed successfully"
