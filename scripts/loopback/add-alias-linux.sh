#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo"
    exit 1
fi

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../common/load-config.sh"

SERVICE_TEMPLATE="${SCRIPT_DIR}/loopback-alias.service.template"
SERVICE_TEMP="/tmp/loopback-alias.service"
SERVICE_DEST="/etc/systemd/system/loopback-alias.service"

# Check if template exists
if [ ! -f "$SERVICE_TEMPLATE" ]; then
    echo "Error: Template file not found: $SERVICE_TEMPLATE"
    exit 1
fi

# Generate systemd service from template
echo "Generating systemd service for ${LOOPBACK_IP}..."
sed -e "s|{{LOOPBACK_IP}}|${LOOPBACK_IP}|g" \
    -e "s|{{LOOPBACK_NETMASK}}|${LOOPBACK_NETMASK}|g" \
    "$SERVICE_TEMPLATE" > "$SERVICE_TEMP"

# Install the service
cp "$SERVICE_TEMP" "$SERVICE_DEST"
rm -f "$SERVICE_TEMP"

# Reload systemd and enable/start the service
systemctl daemon-reload
systemctl enable loopback-alias
systemctl start loopback-alias

echo "✓ Loopback alias ${LOOPBACK_IP} configured and started"
ifconfig lo | grep "${LOOPBACK_IP}" && echo "✓ Loopback alias is active"
