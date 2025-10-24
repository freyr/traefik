#!/bin/bash

# Setup automatic certificate renewal for macOS
# This script installs a LaunchDaemon that runs certbot renew twice daily

set -e

PLIST_NAME="com.certbot.renew.plist"
PLIST_SRC="$(cd "$(dirname "$0")" && pwd)/$PLIST_NAME"
PLIST_DEST="/Library/LaunchDaemons/$PLIST_NAME"
LABEL="com.certbot.renew"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo"
    exit 1
fi

# Check if certbot is installed
if ! command -v certbot &> /dev/null; then
    echo "Error: certbot is not installed"
    echo "Install with: brew install certbot"
    exit 1
fi

# Check if plist source file exists
if [ ! -f "$PLIST_SRC" ]; then
    echo "Error: $PLIST_NAME not found in script directory"
    exit 1
fi

echo "Setting up automatic certbot renewal..."

# Check if already loaded
if launchctl print system/$LABEL &>/dev/null; then
    echo "LaunchDaemon is already loaded, unloading first..."
    launchctl bootout system/$LABEL 2>/dev/null || true
    sleep 1
fi

# Copy plist file
cp "$PLIST_SRC" "$PLIST_DEST"
chmod 644 "$PLIST_DEST"
chown root:wheel "$PLIST_DEST"
echo "✓ Copied LaunchDaemon configuration"

# Create log file with proper permissions
touch /var/log/certbot-renew.log
chmod 644 /var/log/certbot-renew.log
echo "✓ Created log file: /var/log/certbot-renew.log"

# Load the LaunchDaemon
launchctl bootstrap system "$PLIST_DEST"
if [ $? -eq 0 ]; then
    echo "✓ LaunchDaemon loaded successfully"
else
    echo "Error: Failed to load LaunchDaemon"
    exit 1
fi

# Verify it's loaded
if launchctl print system/$LABEL &>/dev/null; then
    echo "✓ Verified LaunchDaemon is running"
else
    echo "Warning: LaunchDaemon may not be running correctly"
fi

echo ""
echo "=========================================="
echo "Automatic renewal configured successfully!"
echo "=========================================="
echo ""
echo "Renewal Schedule:"
echo "  - Runs twice daily at 00:00 and 12:00"
echo "  - Checks all certificates"
echo "  - Renews if expiring within 30 days"
echo ""
echo "Monitoring:"
echo "  - View logs: tail -f /var/log/certbot-renew.log"
echo "  - Check status: sudo launchctl list | grep certbot"
echo "  - Manual test: sudo certbot renew --dry-run"
echo ""
echo "Uninstall:"
echo "  - Run: sudo ./remove-auto-renewal.sh"
echo ""
