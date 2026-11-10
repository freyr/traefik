#!/usr/bin/env bash
# Checks the demo stacks (make demo-up): DNS, HTTPS through Traefik,
# hostname aliases inside a stack, and isolation between stacks.

set -uo pipefail
source "$(dirname "$0")/../common/load-config.sh"

STACKS=(alpha beta gamma)
CA="${SSL_DIR}/rootCA.pem"
fails=0

pass() { echo "  ✓ $*"; }
fail() {
    echo "  ✗ $*"
    fails=$((fails + 1))
}

# Retries a command for up to 10 s (network-sync reacts to events asynchronously).
retry() {
    for _ in $(seq 1 20); do
        "$@" >/dev/null 2>&1 && return 0
        sleep 0.5
    done
    return 1
}

expect_body() { # expected, curl args...
    local want="$1"
    shift
    [ "$(curl -fsS --max-time 3 "$@" 2>/dev/null)" = "$want" ]
}

echo "DNS"
for s in "${STACKS[@]}"; do
    if nslookup -port="$DNS_PORT" "$s.$DOMAIN" 127.0.0.1 2>/dev/null | grep -q 'Address: 127.0.0.1'; then
        pass "dns container answers $s.$DOMAIN -> 127.0.0.1"
    else
        fail "dns container does not answer $s.$DOMAIN"
    fi
done
if [ "$(uname)" = "Darwin" ] && [ -f "/etc/resolver/$DOMAIN" ]; then
    if dscacheutil -q host -a name "alpha.$DOMAIN" | grep -q '127.0.0.1'; then
        pass "macOS resolver sends *.$DOMAIN to the dns container"
    else
        fail "macOS resolver does not resolve alpha.$DOMAIN"
    fi
else
    echo "  - host resolver not configured (make dns); host checks use --resolve"
fi

echo "HTTPS from the host"
for s in "${STACKS[@]}"; do
    if retry expect_body "$s" --cacert "$CA" --resolve "$s.$DOMAIN:443:127.0.0.1" "https://$s.$DOMAIN"; then
        pass "https://$s.$DOMAIN -> $s (certificate trusted)"
    else
        fail "https://$s.$DOMAIN does not return '$s'"
    fi
done
code=$(curl -s -o /dev/null -w '%{http_code}' --resolve "alpha.$DOMAIN:80:127.0.0.1" "http://alpha.$DOMAIN")
case "$code" in 301 | 308) pass "http:// redirects to https:// ($code)" ;; *) fail "http:// returned $code, expected 301 or 308" ;; esac

echo "Inside a stack"
if retry docker exec alpha-web-1 curl -fsS --max-time 3 --cacert /certs/rootCA.pem "https://alpha.$DOMAIN"; then
    pass "alpha web -> https://alpha.$DOMAIN (alias on alpha_edge)"
else
    fail "alpha web cannot call https://alpha.$DOMAIN"
fi
if docker exec alpha-web-1 curl -fsS --max-time 3 http://backend >/dev/null 2>&1; then
    pass "alpha web -> alpha backend"
else
    fail "alpha web cannot reach its own backend"
fi

echo "Isolation between stacks"
for target in beta-web-1 beta-backend-1 gamma-web-1; do
    if docker exec alpha-web-1 curl -fsS --max-time 2 "http://$target" >/dev/null 2>&1; then
        fail "alpha web reaches $target"
    else
        pass "alpha web cannot reach $target"
    fi
done
if docker exec alpha-web-1 curl -fsS --max-time 2 --cacert /certs/rootCA.pem "https://beta.$DOMAIN" >/dev/null 2>&1; then
    fail "alpha web reaches https://beta.$DOMAIN"
else
    pass "alpha web cannot reach https://beta.$DOMAIN"
fi

echo
if [ "$fails" -eq 0 ]; then
    echo "✓ All checks passed"
else
    echo "✗ $fails check(s) failed"
    exit 1
fi
