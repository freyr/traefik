#!/usr/bin/env bash
# Sends DNS queries for DOMAIN (and its subdomains) to the dnsmasq container
# on 127.0.0.1:DNS_PORT. All other names keep the normal resolver.
# Run as a normal user; the script calls sudo for the system files.

set -euo pipefail
source "$(dirname "$0")/../common/load-config.sh"

case "$(uname)" in
Darwin)
    file="/etc/resolver/${DOMAIN}"
    sudo mkdir -p /etc/resolver
    printf 'nameserver 127.0.0.1\nport %s\n' "$DNS_PORT" | sudo tee "$file" >/dev/null
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder 2>/dev/null || true
    echo "✓ ${file}: *.${DOMAIN} -> 127.0.0.1:${DNS_PORT}"
    ;;
Linux)
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        file="/etc/systemd/resolved.conf.d/traefik-${DOMAIN}.conf"
        sudo mkdir -p /etc/systemd/resolved.conf.d
        printf '[Resolve]\nDNS=127.0.0.1:%s\nDomains=~%s\n' "$DNS_PORT" "$DOMAIN" | sudo tee "$file" >/dev/null
        sudo systemctl restart systemd-resolved
        echo "✓ ${file}: *.${DOMAIN} -> 127.0.0.1:${DNS_PORT}"
    else
        echo "systemd-resolved is not active. Configure your resolver to send" >&2
        echo "queries for '${DOMAIN}' to 127.0.0.1:${DNS_PORT}." >&2
        exit 1
    fi
    ;;
*)
    echo "Unsupported OS: $(uname). Send queries for '${DOMAIN}' to 127.0.0.1:${DNS_PORT}." >&2
    exit 1
    ;;
esac
