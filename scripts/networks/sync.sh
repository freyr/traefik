#!/bin/sh
# Keeps the proxy container attached to the edge network of each routed stack.
#
# A routed container declares its edge network with the label
#   traefik.docker.network: <network name>
# For each such network that has a running routed container, the proxy is
# connected to it, with the Host(`...`) names of the routers on that network
# as network aliases. Containers on that network can then call
# https://<host> and reach the proxy, and nothing else from other stacks.
#
# When no routed container runs on a network any more, the proxy disconnects.
# This starts on the "kill" event (before the container exits), so that
# `docker compose down` of the stack can remove the network. If compose was
# faster, the sweep removes the leftover edge network once the stack has no
# containers at all (what `down` intended). A stopped stack keeps its network.
#
# Usage: sync.sh once|watch|status
# POSIX sh: runs in the docker:cli image (busybox).

PROXY="${PROXY_CONTAINER:-traefik}"
KNOWN="${TMPDIR:-/tmp}/network-sync.known"   # edge networks this process connected

log() { echo "[network-sync] $*"; }

proxy_exists() { docker inspect "$PROXY" >/dev/null 2>&1; }

# One snapshot of "<id> <network>" for running routed containers, except id $1.
routed_snapshot() {
  docker ps --no-trunc --filter label=traefik.enable=true \
    --format '{{.ID}} {{.Label "traefik.docker.network"}}' |
    awk -v skip="$1" 'NF == 2 && $1 != skip'
}

# Sorted, space-separated hostnames from Host() rules of the given containers.
hosts_of() {
  [ $# -eq 0 ] && return
  docker inspect --format '{{range $k, $v := .Config.Labels}}{{$k}}={{$v}}{{"\n"}}{{end}}' "$@" 2>/dev/null |
    grep -E '^traefik\.http\.routers\.[^.=]+\.rule=' |
    grep -oE 'Host\([^)]*\)' |
    grep -oE '`[^`]+`' |
    tr -d '`' | sort -u | tr '\n' ' ' | sed 's/ $//'
}

# Sorted, space-separated hostname aliases (names with a dot) of the proxy on a network.
proxy_aliases() {
  docker inspect --format "{{with index .NetworkSettings.Networks \"$1\"}}{{range .Aliases}}{{.}}{{\"\\n\"}}{{end}}{{end}}" "$PROXY" |
    grep '\.' | sort -u | tr '\n' ' ' | sed 's/ $//'
}

proxy_networks() {
  docker inspect --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{"\n"}}{{end}}' "$PROXY" | grep -v '^$'
}

is_connected() { proxy_networks | grep -qx "$1"; }

remember() { grep -qx "$1" "$KNOWN" 2>/dev/null || echo "$1" >>"$KNOWN"; }
forget() { [ -f "$KNOWN" ] && grep -vx "$1" "$KNOWN" >"$KNOWN.tmp"; mv -f "$KNOWN.tmp" "$KNOWN" 2>/dev/null; }

connect() {
  net="$1"; hosts="$2"; args=""
  for h in $hosts; do args="$args --alias $h"; done
  # shellcheck disable=SC2086
  if docker network connect $args "$net" "$PROXY"; then
    remember "$net"
    log "connected $PROXY to $net (aliases: ${hosts:-none})"
  else
    log "ERROR: cannot connect $PROXY to $net"
  fi
}

# $1: optional ID of a container that is stopping; it counts as gone.
sync_once() {
  if ! proxy_exists; then
    log "proxy container '$PROXY' not found, waiting"
    return
  fi

  snapshot=$(routed_snapshot "${1:-}")
  wanted_networks=$(echo "$snapshot" | awk 'NF == 2 {print $2}' | sort -u)

  # A stopping container ($1) can only remove networks: skip the connect pass
  # so the detach happens before compose tries to remove the network.
  [ -n "${1:-}" ] || for net in $wanted_networks; do
    if ! docker network inspect "$net" >/dev/null 2>&1; then
      log "WARN: network '$net' from a traefik.docker.network label does not exist (use the full name, e.g. <project>_edge)"
      continue
    fi
    # shellcheck disable=SC2046
    want=$(hosts_of $(echo "$snapshot" | awk -v n="$net" '$2 == n {print $1}'))
    if is_connected "$net"; then
      [ "$(proxy_aliases "$net")" = "$want" ] && continue
      log "aliases on $net changed, reconnecting"
      docker network disconnect "$net" "$PROXY" >/dev/null
    fi
    connect "$net" "$want"
  done

  # Leave networks that no longer have a routed container.
  own_project=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$PROXY")
  for net in $(proxy_networks); do
    echo "$wanted_networks" | grep -qx "$net" && continue
    [ "$net" = "bridge" ] && continue
    net_project=$(docker network inspect --format '{{index .Labels "com.docker.compose.project"}}' "$net" 2>/dev/null)
    [ -n "$own_project" ] && [ "$net_project" = "$own_project" ] && continue
    if docker network disconnect "$net" "$PROXY" >/dev/null 2>&1; then
      remember "$net"
      log "disconnected $PROXY from $net (no routed container left)"
    fi
  done
}

# Removes edge networks that compose could not remove because the proxy was
# still attached: empty, and the compose project has no containers left.
sweep() {
  [ -s "$KNOWN" ] || return
  for net in $(sort -u "$KNOWN"); do
    if ! docker network inspect "$net" >/dev/null 2>&1; then
      forget "$net"; continue
    fi
    is_connected "$net" && continue
    [ "$(docker network inspect --format '{{len .Containers}}' "$net" 2>/dev/null)" = "0" ] || continue
    project=$(docker network inspect --format '{{index .Labels "com.docker.compose.project"}}' "$net" 2>/dev/null)
    [ -n "$project" ] || continue
    [ -z "$(docker ps -aq --filter "label=com.docker.compose.project=$project")" ] || continue
    if docker network rm "$net" >/dev/null 2>&1; then
      log "removed $net (stack '$project' is down)"
    fi
    forget "$net"
  done
}

status() {
  proxy_exists || { echo "proxy container '$PROXY' not found"; return 1; }
  echo "Networks of $PROXY:"
  for net in $(proxy_networks); do
    echo "  $net  aliases: $(proxy_aliases "$net")"
  done
}

case "${1:-once}" in
  once) sync_once; sweep ;;
  status) status ;;
  watch)
    log "watching Docker events (proxy: $PROXY)"
    sync_once
    docker events --filter type=container \
      --filter event=start --filter event=kill --filter event=die --filter event=destroy \
      --format '{{.Action}} {{.Actor.ID}}' |
      while read -r action id; do
        case "$action" in
          kill) sync_once "$id" ;;   # stopping: detach before it exits
          *) sync_once ;;
        esac
        sweep
      done
    log "Docker event stream ended"
    exit 1
    ;;
  *) echo "Usage: $0 once|watch|status" >&2; exit 2 ;;
esac
