#!/usr/bin/env bats
# shellcheck disable=SC2016 # stub bodies and labels are literal text

load test_helper

setup() {
    make_project
    write_env "DOMAIN=example.test" "SSL_DIR=./ssl"
    SCRIPT="${PROJECT}/scripts/certs/generate.sh"
    CAROOT="${BATS_TEST_TMPDIR}/caroot"
    mkdir -p "${CAROOT}"
    echo "CA" >"${CAROOT}/rootCA.pem"
    export CAROOT
    # mkcert: -CAROOT prints the CA folder; -cert-file/-key-file write the two files.
    stub mkcert '
case "$1" in
-CAROOT) echo "${CAROOT}" ;;
-cert-file) echo cert >"$2"; echo key >"$4" ;;
esac'
}

@test "fails with a hint when mkcert is missing" {
    rm "${STUBS}/mkcert"
    run env PATH="${STUBS}:/usr/bin:/bin" "${BASH}" "${SCRIPT}"
    [ "$status" -eq 1 ]
    [[ "$output" == *"mkcert not found"* ]]
}

@test "creates the certificate, the key and the CA copy" {
    stub openssl 'echo notAfter=Jan  1 00:00:00 2030 GMT'
    run bash "${SCRIPT}"
    [ "$status" -eq 0 ]
    [ -f "${PROJECT}/ssl/local.crt" ]
    [ -f "${PROJECT}/ssl/local.key" ]
    [ "$(cat "${PROJECT}/ssl/rootCA.pem")" = "CA" ]
    grep -qx 'mkcert -install' "${CALLS}"
    grep -qF "mkcert -cert-file ${PROJECT}/ssl/local.crt -key-file ${PROJECT}/ssl/local.key example.test *.example.test" "${CALLS}"
    [ "$(stat -c %a "${PROJECT}/ssl/local.key" 2>/dev/null || stat -f %Lp "${PROJECT}/ssl/local.key")" = "600" ]
}

@test "adds CERT_EXTRA_NAMES to the certificate" {
    write_env "DOMAIN=example.test" "CERT_EXTRA_NAMES=\"localhost 127.0.0.1\""
    stub openssl 'echo notAfter=Jan  1 00:00:00 2030 GMT'
    run bash "${SCRIPT}"
    [ "$status" -eq 0 ]
    grep -qF "example.test *.example.test localhost 127.0.0.1" "${CALLS}"
}

@test "skips the work when a valid certificate for DOMAIN exists" {
    mkdir -p "${PROJECT}/ssl"
    echo cert >"${PROJECT}/ssl/local.crt"
    echo key >"${PROJECT}/ssl/local.key"
    stub openssl 'case "$*" in *-text*) echo "DNS:example.test, DNS:*.example.test" ;; esac'
    run bash "${SCRIPT}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"exists and is valid"* ]]
    run ! grep -q '^mkcert -install' "${CALLS}"
}

@test "replaces a valid certificate with --force" {
    mkdir -p "${PROJECT}/ssl"
    echo old >"${PROJECT}/ssl/local.crt"
    echo old >"${PROJECT}/ssl/local.key"
    stub openssl 'case "$*" in *-text*) echo "DNS:example.test, DNS:*.example.test" ;; esac'
    run bash "${SCRIPT}" --force
    [ "$status" -eq 0 ]
    [ "$(cat "${PROJECT}/ssl/local.crt")" = "cert" ]
}

@test "replaces a certificate for another DOMAIN" {
    mkdir -p "${PROJECT}/ssl"
    echo old >"${PROJECT}/ssl/local.crt"
    echo old >"${PROJECT}/ssl/local.key"
    stub openssl 'case "$*" in *-text*) echo "DNS:other.test, DNS:*.other.test" ;; esac'
    run bash "${SCRIPT}"
    [ "$status" -eq 0 ]
    [ "$(cat "${PROJECT}/ssl/local.crt")" = "cert" ]
}
