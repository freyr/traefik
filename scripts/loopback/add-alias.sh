#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo"
    exit 1
fi

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# When running with sudo, we need to source the config in the context of the original user
if [ -n "$SUDO_USER" ]; then
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
    ENV_FILE="${PROJECT_ROOT}/.env"
    if [ ! -f "$ENV_FILE" ]; then
        echo "Error: .env file not found at $ENV_FILE"
        echo "Please copy .env.example to .env and configure it:"
        echo "  cp .env.example .env"
        exit 1
    fi
    source "$ENV_FILE"
else
    source "${SCRIPT_DIR}/../common/load-config.sh"
fi

# Generate plist name from loopback IP
SAFE_IP=$(echo "${LOOPBACK_IP}" | tr '.' '_')
PLIST_NAME="com.runlevel1.lo0.${SAFE_IP}.plist"
PLIST_DEST="/Library/LaunchDaemons/$PLIST_NAME"
LABEL="com.runlevel1.lo0.${SAFE_IP}"
PLIST_TEMPLATE="${SCRIPT_DIR}/loopback-alias.plist.template"
PLIST_TEMP="/tmp/${PLIST_NAME}"

# Check if template file exists
if [ ! -f "$PLIST_TEMPLATE" ]; then
    echo "Error: Template file not found: $PLIST_TEMPLATE"
    exit 1
fi

# Check if already loaded
if launchctl print system/$LABEL &>/dev/null; then
    echo "✓ LaunchDaemon '$LABEL' is already loaded and running"
    ifconfig lo0 | grep "${LOOPBACK_IP}" && echo "✓ Loopback alias ${LOOPBACK_IP} is active"
    exit 0
fi

# Generate plist from template
echo "Generating LaunchDaemon configuration for ${LOOPBACK_IP}..."
sed -e "s|{{LABEL}}|${LABEL}|g" \
    -e "s|{{LOOPBACK_IP}}|${LOOPBACK_IP}|g" \
    "$PLIST_TEMPLATE" > "$PLIST_TEMP"

# Check if plist file exists but not loaded
if [ -f "$PLIST_DEST" ]; then
    echo "Found existing plist file, loading it..."
    launchctl bootstrap system "$PLIST_DEST" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✓ LaunchDaemon loaded successfully"
        ifconfig lo0 | grep "${LOOPBACK_IP}" && echo "✓ Loopback alias ${LOOPBACK_IP} is now active"
        rm -f "$PLIST_TEMP"
        exit 0
    else
        echo "Warning: Failed to load existing plist, reinstalling..."
        rm -f "$PLIST_DEST"
    fi
fi

# Install new LaunchDaemon
echo "Installing LaunchDaemon..."
mv "$PLIST_TEMP" "$PLIST_DEST"
chmod 0644 "$PLIST_DEST"
chown root:wheel "$PLIST_DEST"

# Load the LaunchDaemon
launchctl bootstrap system "$PLIST_DEST"
if [ $? -eq 0 ]; then
    echo "✓ LaunchDaemon installed and loaded successfully"
    sleep 1
    ifconfig lo0 | grep "${LOOPBACK_IP}" && echo "✓ Loopback alias ${LOOPBACK_IP} is now active"
else
    echo "Error: Failed to load LaunchDaemon"
    exit 1
fi
