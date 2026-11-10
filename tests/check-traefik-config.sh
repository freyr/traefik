#!/usr/bin/env bash

# Start the traefik service of compose.yaml (with .env.example) and fail when its static
# configuration does not load. The static configuration is the list of CLI flags in
# compose.yaml. Traefik has no dry-run mode: an unknown flag or a wrong value stops the
# process at once, and a loaded configuration answers the ping endpoint. The file
# provider (configs/) loads too; missing certificates only log an error.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TIMEOUT="${TIMEOUT:-30}"
PROJECT="traefik-config-check-$$"
NAME="${PROJECT}-traefik"
COMPOSE=(docker compose --env-file .env.example -p "$PROJECT")

# shellcheck disable=SC2329 # called by the EXIT trap
cleanup() {
    docker rm -f "$NAME" >/dev/null 2>&1 || true
    "${COMPOSE[@]}" down --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Checking the Traefik static configuration of compose.yaml..."
"${COMPOSE[@]}" run -d --no-deps --name "$NAME" traefik >/dev/null

for _ in $(seq "$TIMEOUT"); do
    if [ "$(docker inspect -f '{{.State.Running}}' "$NAME")" != "true" ]; then
        echo "Error: Traefik stopped; the static configuration did not load:"
        docker logs "$NAME" 2>&1 | head -20
        exit 1
    fi
    if docker exec "$NAME" traefik healthcheck --ping >/dev/null 2>&1; then
        echo "✓ The static configuration loaded and Traefik answers the ping endpoint"
        exit 0
    fi
    sleep 1
done

echo "Error: Traefik did not answer the ping endpoint in ${TIMEOUT}s:"
docker logs "$NAME" 2>&1 | tail -20
exit 1
