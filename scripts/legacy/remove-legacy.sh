#!/usr/bin/env bash
# Removes what the Let's Encrypt / loopback-alias version of this repo installed:
#   - the loopback alias (LaunchDaemon on macOS, systemd unit on Linux)
#   - the certbot renewal LaunchDaemon and the Traefik renewal hook
# Certbot itself, /etc/letsencrypt and the Cloudflare credentials stay; remove
# them by hand when nothing else uses them.
#
# Run with sudo. LOOPBACK_IP defaults to the old default 172.16.123.1.

set -uo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Error: run with sudo (make remove-legacy)" >&2
    exit 1
fi

LOOPBACK_IP="${LOOPBACK_IP:-172.16.123.1}"

case "$(uname)" in
Darwin)
    label="com.runlevel1.lo0.$(echo "$LOOPBACK_IP" | tr '.' '_')"
    for l in "$label" com.certbot.renew; do
        plist="/Library/LaunchDaemons/${l}.plist"
        if launchctl print "system/${l}" >/dev/null 2>&1; then
            launchctl bootout "system/${l}" 2>/dev/null && echo "✓ Unloaded ${l}"
        fi
        [ -f "$plist" ] && rm -f "$plist" && echo "✓ Removed ${plist}"
    done
    ifconfig lo0 -alias "$LOOPBACK_IP" 2>/dev/null && echo "✓ Removed loopback alias ${LOOPBACK_IP}"
    ;;
Linux)
    if [ -f /etc/systemd/system/loopback-alias.service ]; then
        systemctl disable --now loopback-alias 2>/dev/null
        rm -f /etc/systemd/system/loopback-alias.service
        systemctl daemon-reload
        echo "✓ Removed loopback-alias.service"
    fi
    ip addr del "${LOOPBACK_IP}/12" dev lo 2>/dev/null && echo "✓ Removed loopback alias ${LOOPBACK_IP}"
    ;;
esac

hook=/etc/letsencrypt/renewal-hooks/deploy/traefik-renew.sh
[ -f "$hook" ] && rm -f "$hook" && echo "✓ Removed ${hook}"

echo "✓ Legacy cleanup complete"
