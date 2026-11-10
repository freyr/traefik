#!/usr/bin/env bash
# Loads .env and sets defaults. Source this at the start of every script.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
export PROJECT_ROOT

ENV_FILE="${PROJECT_ROOT}/.env"
if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
else
    echo "Error: .env not found at $ENV_FILE (run: make check-env)" >&2
    exit 1
fi

if [ -z "${DOMAIN:-}" ]; then
    echo "Error: DOMAIN is not set in .env" >&2
    exit 1
fi

export SSL_DIR="${SSL_DIR:-./ssl}"
export DNS_PORT="${DNS_PORT:-53}"
export PROXY_CONTAINER="${PROXY_CONTAINER:-traefik}"
export CERT_EXTRA_NAMES="${CERT_EXTRA_NAMES:-}"

if [[ "${SSL_DIR}" != /* ]]; then
    export SSL_DIR="${PROJECT_ROOT}/${SSL_DIR#./}"
fi
