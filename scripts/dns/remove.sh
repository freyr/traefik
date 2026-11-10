#!/usr/bin/env bash
# Removes the resolver configuration that setup.sh created.

set -euo pipefail
source "$(dirname "$0")/../common/load-config.sh"

case "$(uname)" in
Darwin)
    file="/etc/resolver/${DOMAIN}"
    if [ -f "$file" ]; then
        sudo rm -f "$file"
        sudo dscacheutil -flushcache
        sudo killall -HUP mDNSResponder 2>/dev/null || true
        echo "✓ Removed ${file}"
    else
        echo "Nothing to remove (${file} not found)"
    fi
    ;;
Linux)
    file="/etc/systemd/resolved.conf.d/traefik-${DOMAIN}.conf"
    if [ -f "$file" ]; then
        sudo rm -f "$file"
        sudo systemctl restart systemd-resolved
        echo "✓ Removed ${file}"
    else
        echo "Nothing to remove (${file} not found)"
    fi
    ;;
esac
