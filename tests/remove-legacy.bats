#!/usr/bin/env bats
# shellcheck disable=SC2016 # stub bodies are literal text

load test_helper

setup() {
    make_project
    export LAUNCHD_DIR="${BATS_TEST_TMPDIR}/LaunchDaemons"
    export LEGACY_HOOK="${BATS_TEST_TMPDIR}/traefik-renew.sh"
    mkdir -p "${LAUNCHD_DIR}"
    stub id 'echo 0'
    stub uname 'echo Darwin'
    # launchctl print succeeds: every label counts as loaded.
    stub launchctl 'exit 0'
    stub ifconfig 'exit 0'
}

@test "macOS: removes the underscore and the dotted alias labels and certbot" {
    for l in com.runlevel1.lo0.172_16_123_1 com.runlevel1.lo0.172.16.123.1 com.certbot.renew; do
        touch "${LAUNCHD_DIR}/${l}.plist"
    done
    touch "${LEGACY_HOOK}"
    run bash "${PROJECT}/scripts/legacy/remove-legacy.sh"
    [ "$status" -eq 0 ]
    for l in com.runlevel1.lo0.172_16_123_1 com.runlevel1.lo0.172.16.123.1 com.certbot.renew; do
        [ ! -e "${LAUNCHD_DIR}/${l}.plist" ]
        grep -qx "launchctl bootout system/${l}" "${CALLS}"
    done
    [ ! -e "${LEGACY_HOOK}" ]
    grep -qx 'ifconfig lo0 -alias 172.16.123.1' "${CALLS}"
    [[ "$output" == *"Legacy cleanup complete"* ]]
}

@test "macOS: uses LOOPBACK_IP for both label forms" {
    touch "${LAUNCHD_DIR}/com.runlevel1.lo0.10.0.0.9.plist"
    LOOPBACK_IP=10.0.0.9 run bash "${PROJECT}/scripts/legacy/remove-legacy.sh"
    [ "$status" -eq 0 ]
    [ ! -e "${LAUNCHD_DIR}/com.runlevel1.lo0.10.0.0.9.plist" ]
    grep -qx 'launchctl bootout system/com.runlevel1.lo0.10_0_0_9' "${CALLS}"
    grep -qx 'ifconfig lo0 -alias 10.0.0.9' "${CALLS}"
}

@test "macOS: succeeds when nothing is installed" {
    stub launchctl 'exit 1'
    stub ifconfig 'exit 1'
    run bash "${PROJECT}/scripts/legacy/remove-legacy.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Legacy cleanup complete"* ]]
    run ! grep -q 'bootout' "${CALLS}"
}

@test "refuses to run without root" {
    stub id 'echo 501'
    touch "${LAUNCHD_DIR}/com.certbot.renew.plist"
    run bash "${PROJECT}/scripts/legacy/remove-legacy.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"run with sudo"* ]]
    [ -e "${LAUNCHD_DIR}/com.certbot.renew.plist" ]
}
