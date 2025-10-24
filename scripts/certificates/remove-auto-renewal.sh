#!/bin/bash

# Remove automatic certbot renewal LaunchDaemon

set -e

PLIST_DEST="/Library/LaunchDaemons/com.certbot.renew.plist"
LABEL="com.certbot.renew"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo"
    exit 1
fi

echo "Removing automatic certbot renewal..."

# Check if loaded and unload
if launchctl print system/$LABEL &>/dev/null; then
    echo "Unloading LaunchDaemon..."
    launchctl bootout system/$LABEL 2>/dev/null
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

echo ""
echo "✓ Automatic renewal removed successfully"
echo ""
echo "Note: Log file /var/log/certbot-renew.log has been kept"
echo "      Remove manually if desired: sudo rm /var/log/certbot-renew.log"
