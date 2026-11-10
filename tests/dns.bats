#!/usr/bin/env bats
# shellcheck disable=SC2016 # stub bodies and labels are literal text

load test_helper

setup() {
    make_project
    write_env "DOMAIN=example.test" "DNS_PORT=5353"
    # sudo only logs the command and reads stdin, so no system file changes.
    stub sudo 'cat >/dev/null 2>&1 || true'
    stub dscacheutil
    stub killall
}

@test "setup on macOS writes /etc/resolver/DOMAIN with the DNS port" {
    stub uname 'echo Darwin'
    run bash "${PROJECT}/scripts/dns/setup.sh"
    [ "$status" -eq 0 ]
    grep -qx 'sudo mkdir -p /etc/resolver' "${CALLS}"
    grep -qx 'sudo tee /etc/resolver/example.test' "${CALLS}"
    [[ "$output" == *"*.example.test -> 127.0.0.1:5353"* ]]
}

@test "setup on Linux with systemd-resolved writes a resolved drop-in" {
    stub uname 'echo Linux'
    stub systemctl 'exit 0'
    run bash "${PROJECT}/scripts/dns/setup.sh"
    [ "$status" -eq 0 ]
    grep -qx 'sudo tee /etc/systemd/resolved.conf.d/traefik-example.test.conf' "${CALLS}"
    grep -qx 'sudo systemctl restart systemd-resolved' "${CALLS}"
}

@test "setup on Linux without systemd-resolved fails with a hint" {
    stub uname 'echo Linux'
    stub systemctl 'exit 3'
    run bash "${PROJECT}/scripts/dns/setup.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"systemd-resolved is not active"* ]]
    run ! grep -q '^sudo' "${CALLS}"
}

@test "setup on an unsupported OS fails" {
    stub uname 'echo FreeBSD'
    run bash "${PROJECT}/scripts/dns/setup.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unsupported OS: FreeBSD"* ]]
}

@test "remove does nothing when the resolver file is missing" {
    stub uname 'echo Darwin'
    run bash "${PROJECT}/scripts/dns/remove.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Nothing to remove (/etc/resolver/example.test not found)"* ]]
    run ! grep -q '^sudo' "${CALLS}"
}

@test "setup fails when .env is missing" {
    rm "${PROJECT}/.env"
    stub uname 'echo Darwin'
    run bash "${PROJECT}/scripts/dns/setup.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *".env not found"* ]]
}
