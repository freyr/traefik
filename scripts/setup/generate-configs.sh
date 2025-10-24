#!/bin/bash

# Generate configuration files from templates
# This script should be run after updating .env file

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../common/load-config.sh"

echo "Generating configuration files from templates..."

# Generate certs.toml
CERTS_TEMPLATE="${PROJECT_ROOT}/configs/certs.toml.template"
CERTS_OUTPUT="${PROJECT_ROOT}/configs/certs.toml"

if [ ! -f "$CERTS_TEMPLATE" ]; then
    echo "Error: Template not found: $CERTS_TEMPLATE"
    exit 1
fi

sed -e "s|{{CERT_FILE}}|${CERT_FILE}|g" \
    -e "s|{{KEY_FILE}}|${KEY_FILE}|g" \
    "$CERTS_TEMPLATE" > "$CERTS_OUTPUT"

echo "✓ Generated ${CERTS_OUTPUT}"

echo ""
echo "Configuration files generated successfully!"
echo ""
echo "Domain: ${DOMAIN}"
echo "Certificate: ${CERT_FILE}"
echo "Key: ${KEY_FILE}"
