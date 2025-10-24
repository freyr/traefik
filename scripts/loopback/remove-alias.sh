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

# Check if loaded and unload
if launchctl print system/$LABEL &>/dev/null; then
    echo "Unloading LaunchDaemon..."
    launchctl bootout system/$LABEL 2>/dev/null || launchctl unload "$PLIST_DEST" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✓ LaunchDaemon unloaded"
    else
        echo "Warning: Failed to unload LaunchDaemon"
    fi
else
    echo "LaunchDaemon is not loaded"
fi

# Remove plist file
if [ -f "$PLIST_DEST" ]; then
    rm -f "$PLIST_DEST"
    echo "✓ Removed $PLIST_DEST"
else
    echo "Plist file not found (already removed)"
fi

# Remove the alias manually (it will be removed after reboot anyway)
ifconfig lo0 -alias ${LOOPBACK_IP} 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✓ Removed loopback alias ${LOOPBACK_IP}"
else
    echo "Loopback alias was not configured"
fi

echo "✓ Cleanup complete"
