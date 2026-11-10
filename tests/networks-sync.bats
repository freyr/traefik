#!/usr/bin/env bats
# shellcheck disable=SC2016 # stub bodies and labels are literal text

load test_helper

# The docker stub answers from files in ${FAKE}:
#   proxy       exists when the proxy container exists
#   ps          output of `docker ps` (running routed containers)
#   labels      output of `docker inspect` for the container labels
#   networks    networks of the proxy, one per line
setup() {
    make_project
    SCRIPT="${PROJECT}/scripts/networks/sync.sh"
    FAKE="${BATS_TEST_TMPDIR}/fake"
    mkdir -p "${FAKE}"
    : >"${FAKE}/ps"
    : >"${FAKE}/labels"
    : >"${FAKE}/networks"
    export FAKE TMPDIR="${BATS_TEST_TMPDIR}"
    stub docker '
case "$1 $2" in
"inspect traefik") [ -f "${FAKE}/proxy" ] || exit 1 ;;
"inspect --format")
    case "$3" in
    *Config.Labels*com.docker.compose.project*) echo traefik ;;
    *Config.Labels*) cat "${FAKE}/labels" ;;
    *NetworkSettings.Networks*Aliases*) : ;;
    *NetworkSettings.Networks*) cat "${FAKE}/networks" ;;
    esac ;;
"ps --no-trunc") cat "${FAKE}/ps" ;;
"network inspect")
    [ "$3" = "--format" ] || exit 0
    case "$4:$5" in
    *len*) echo 1 ;;
    *:traefik_*) echo traefik ;;
    *) echo other ;;
    esac ;;
"network connect") exit 0 ;;
"network disconnect") exit 0 ;;
esac'
}

@test "prints the usage and exits 2 for an unknown command" {
    run sh "${SCRIPT}" bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "status fails when the proxy container does not exist" {
    run sh "${SCRIPT}" status
    [ "$status" -eq 1 ]
    [[ "$output" == *"proxy container 'traefik' not found"* ]]
}

@test "once waits when the proxy container does not exist" {
    run sh "${SCRIPT}" once
    [[ "$output" == *"not found, waiting"* ]]
    run ! grep -q '^docker network connect' "${CALLS}"
}

@test "once connects the proxy to the edge network with the router hostnames as aliases" {
    touch "${FAKE}/proxy"
    echo "abc123 shop_edge" >"${FAKE}/ps"
    printf '%s\n' 'traefik.enable=true' 'traefik.http.routers.shop.rule=Host(`shop.example.test`) || Host(`api.example.test`)' >"${FAKE}/labels"
    echo "traefik_default" >"${FAKE}/networks"
    run sh "${SCRIPT}" once
    [ "$status" -eq 0 ]
    grep -qx 'docker network connect --alias api.example.test --alias shop.example.test shop_edge traefik' "${CALLS}"
    [[ "$output" == *"connected traefik to shop_edge"* ]]
}

@test "once disconnects the proxy from a network with no routed container" {
    touch "${FAKE}/proxy"
    printf '%s\n' traefik_default old_edge >"${FAKE}/networks"
    run sh "${SCRIPT}" once
    [ "$status" -eq 0 ]
    grep -qx 'docker network disconnect old_edge traefik' "${CALLS}"
    run ! grep -q 'docker network disconnect traefik_default' "${CALLS}"
}
