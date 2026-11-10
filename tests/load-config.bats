#!/usr/bin/env bats

load test_helper

setup() {
    make_project
    LOADER="${PROJECT}/scripts/common/load-config.sh"
}

# Source the loader in a new shell and print the named variables as NAME=value lines.
load_and_print() {
    run bash -c 'source "$1"; shift; for n in "$@"; do echo "$n=${!n}"; done' _ "${LOADER}" "$@"
}

@test "fails with a hint when .env is missing" {
    load_and_print DOMAIN
    [ "$status" -eq 1 ]
    [[ "$output" == *".env not found at ${PROJECT}/.env"* ]]
    [[ "$output" == *"make check-env"* ]]
}

@test "fails when DOMAIN is not set" {
    write_env "SSL_DIR=./ssl"
    load_and_print DOMAIN
    [ "$status" -eq 1 ]
    [[ "$output" == *"DOMAIN is not set"* ]]
}

@test "sets PROJECT_ROOT to the folder two levels above scripts/common" {
    write_env "DOMAIN=example.test"
    load_and_print PROJECT_ROOT
    [ "$status" -eq 0 ]
    [ "$output" = "PROJECT_ROOT=${PROJECT}" ]
}

@test "sets the defaults of the optional variables" {
    write_env "DOMAIN=example.test"
    load_and_print SSL_DIR DNS_PORT PROXY_CONTAINER CERT_EXTRA_NAMES
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "SSL_DIR=${PROJECT}/ssl" ]
    [ "${lines[1]}" = "DNS_PORT=53" ]
    [ "${lines[2]}" = "PROXY_CONTAINER=traefik" ]
    [ "${lines[3]}" = "CERT_EXTRA_NAMES=" ]
}

@test "keeps the values that .env sets" {
    write_env "DOMAIN=example.test" "DNS_PORT=5353" "PROXY_CONTAINER=proxy" "CERT_EXTRA_NAMES=localhost"
    load_and_print DNS_PORT PROXY_CONTAINER CERT_EXTRA_NAMES
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "DNS_PORT=5353" ]
    [ "${lines[1]}" = "PROXY_CONTAINER=proxy" ]
    [ "${lines[2]}" = "CERT_EXTRA_NAMES=localhost" ]
}

@test "makes a relative SSL_DIR absolute under PROJECT_ROOT" {
    write_env "DOMAIN=example.test" "SSL_DIR=certs"
    load_and_print SSL_DIR
    [ "$status" -eq 0 ]
    [ "$output" = "SSL_DIR=${PROJECT}/certs" ]
}

@test "keeps an absolute SSL_DIR" {
    write_env "DOMAIN=example.test" "SSL_DIR=/srv/ssl"
    load_and_print SSL_DIR
    [ "$status" -eq 0 ]
    [ "$output" = "SSL_DIR=/srv/ssl" ]
}

@test "exports the variables to child processes" {
    write_env "DOMAIN=example.test"
    run bash -c 'source "$1"; bash -c "echo \$DOMAIN \$DNS_PORT"' _ "${LOADER}"
    [ "$status" -eq 0 ]
    [ "$output" = "example.test 53" ]
}

@test "loads .env.example without errors" {
    cp "${PROJECT}/.env.example" "${PROJECT}/.env"
    load_and_print DOMAIN SSL_DIR DNS_PORT
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "DOMAIN=freyr.test" ]
    [ "${lines[1]}" = "SSL_DIR=${PROJECT}/ssl" ]
    [ "${lines[2]}" = "DNS_PORT=53" ]
}
