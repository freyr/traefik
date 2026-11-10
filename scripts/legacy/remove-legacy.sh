#!/usr/bin/env bash
# Removes what the Let's Encrypt / loopback-alias version of this repo installed:
#   - the loopback alias (LaunchDaemon on macOS, systemd unit on Linux)
#   - the certbot renewal LaunchDaemon and the Traefik renewal hook
# Certbot itself, /etc/letsencrypt and the Cloudflare credentials stay; remove
# them by hand when nothing else uses them.
#
# Run with sudo. LOOPBACK_IP defaults to the old default 172.16.123.1.
# LAUNCHD_DIR and LEGACY_HOOK default to the system paths (the tests change them).

set -uo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: run with sudo (make remove-legacy)" >&2
    exit 1
fi

LOOPBACK_IP="${LOOPBACK_IP:-172.16.123.1}"
LAUNCHD_DIR="${LAUNCHD_DIR:-/Library/LaunchDaemons}"
LEGACY_HOOK="${LEGACY_HOOK:-/etc/letsencrypt/renewal-hooks/deploy/traefik-renew.sh}"

case "$(uname)" in
Darwin)
    # Older versions of the alias script named the label with dots, newer
    # ones with underscores; a machine can have both.
    for l in "com.runlevel1.lo0.$(echo "$LOOPBACK_IP" | tr '.' '_')" \
        "com.runlevel1.lo0.${LOOPBACK_IP}" \
        com.certbot.renew; do
        plist="${LAUNCHD_DIR}/${l}.plist"
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

[ -f "$LEGACY_HOOK" ] && rm -f "$LEGACY_HOOK" && echo "✓ Removed ${LEGACY_HOOK}"

echo "✓ Legacy cleanup complete"
