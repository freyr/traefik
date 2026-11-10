#!/usr/bin/env bash
# Creates the local CA (once per machine) and a wildcard certificate for
# DOMAIN and *.DOMAIN with mkcert. Skips the work when a valid certificate
# for the current DOMAIN exists, unless --force is given.
#
# Output in SSL_DIR:
#   local.crt / local.key  certificate and key that Traefik serves
#   rootCA.pem             public CA certificate, to mount into containers

set -euo pipefail
source "$(dirname "$0")/../common/load-config.sh"

FORCE="${1:-}"
CERT="${SSL_DIR}/local.crt"
KEY="${SSL_DIR}/local.key"

if ! command -v mkcert >/dev/null 2>&1; then
    echo "Error: mkcert not found (run: make install-deps)" >&2
    exit 1
fi

mkdir -p "$SSL_DIR"

if [[ "$FORCE" != "--force" && -f "$CERT" && -f "$KEY" ]] &&
    openssl x509 -in "$CERT" -noout -text | grep -qF "DNS:*.${DOMAIN}" &&
    openssl x509 -in "$CERT" -noout -checkend $((30 * 86400)) >/dev/null; then
    echo "✓ Certificate for *.${DOMAIN} exists and is valid for 30+ days (use make renew-certs to replace it)"
    exit 0
fi

# Installs the CA into the system trust store (and Firefox when nss is
# installed). It is a no-op when the CA is already trusted.
mkcert -install

# shellcheck disable=SC2086
mkcert -cert-file "$CERT" -key-file "$KEY" "$DOMAIN" "*.${DOMAIN}" ${CERT_EXTRA_NAMES}

cp "$(mkcert -CAROOT)/rootCA.pem" "${SSL_DIR}/rootCA.pem"
chmod 644 "$CERT" "${SSL_DIR}/rootCA.pem"
chmod 600 "$KEY"

echo "✓ Certificate for ${DOMAIN}, *.${DOMAIN} written to ${SSL_DIR}"
openssl x509 -in "$CERT" -noout -enddate
