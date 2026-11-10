# shellcheck disable=SC2016 # the stub body is literal text
# Shared setup for the bats tests.
# Each test gets a copy of the scripts and .env.example in a temporary folder,
# so the scripts never read or write the real .env or ssl/ of the checkout.
# Commands that change the machine (mkcert, sudo, docker, ...) are stubs in
# ${STUBS}, which is first on PATH.

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"

make_project() {
    PROJECT="${BATS_TEST_TMPDIR}/project"
    mkdir -p "${PROJECT}"
    cp -R "${REPO_ROOT}/scripts" "${PROJECT}/"
    cp "${REPO_ROOT}/.env.example" "${PROJECT}/"
    STUBS="${BATS_TEST_TMPDIR}/stubs"
    mkdir -p "${STUBS}"
    CALLS="${BATS_TEST_TMPDIR}/calls"
    : >"${CALLS}"
    export PATH="${STUBS}:${PATH}" CALLS
}

write_env() {
    printf '%s\n' "$@" >"${PROJECT}/.env"
}

# stub NAME [BODY]: a command that logs "NAME args" to ${CALLS}, then runs BODY.
stub() {
    printf '#!/usr/bin/env bash\necho "%s $*" >>"${CALLS}"\n%s\n' "$1" "${2:-}" >"${STUBS}/$1"
    chmod +x "${STUBS}/$1"
}
