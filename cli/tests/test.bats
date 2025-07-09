#!/usr/bin/env bats

TEST_DIR="$(realpath "$(dirname "$BATS_TEST_FILENAME")")"
source "$TEST_DIR/mocks"
source "$TEST_DIR/../test"

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    setup_mocks

    uname() { log_mock_call uname "$@" ;echo $(get_mock_state os); }
    pwd() { log_mock_call pwd "$@"; echo $(get_mock_state project_root); }
    cygpath() {
        log_mock_call cygpath "$@";
        echo $(get_mock_state windows_project_root);
    }

    mock docker
    mock status

    set_mock_state os "Linux"
    set_mock_state project_root "/c/"
    set_mock_state windows_project_root "C:\\"

    export FOLIO_GH_TOKEN="gh_token"
}

teardown() {
    teardown_mocks
}

@test "does not require GitHub token" {
    unset FOLIO_GH_TOKEN
    run test
    assert_success
}

@test "requires GitHub token to update commit status" {
    unset FOLIO_GH_TOKEN
    run test --set-status
    assert_failure
    assert_output --partial "GitHub token required to set commit status."
}

@test "does not set commit status" {
    run test
    assert_success
    assert_mock_not_called status set
}

@test "refuses to run tests if commit status already set" {
    status() { log_mock_call status "$@"; echo "pending"; }
    run test --set-status
    assert_failure
    assert_output --partial "Commit already tested: pending."
    assert_mock_not_called docker run
}

@test "forces tests (--force) if commit status already set" {
    status() { log_mock_call status "$@"; echo "pending"; }
    run test --set-status --force
    assert_success
    assert_mock_called_once status set pending
}

@test "forces tests (-f) if commit status already set" {
    status() { log_mock_call status "$@"; echo "pending"; }
    export -f status
    run test --set-status -f
    assert_success
    assert_mock_called_once status set pending
}

@test "sets commit status to 'pending'" {
    run test --set-status
    assert_success
    assert_mock_called_once status set --self pending \
        --description "Automated tests started."
}

@test "sets commit status to 'pending' before running tests" {
    run test --set-status
    assert_success
    assert_mocks_called_in_order \
        status set --self pending \
            --description "Automated tests started." -- \
        docker run
}

@test "runs BATS tests in Docker container" {
    run test
    assert_success
    assert_mock_called_once docker run -it \
        --name folio-tests-bats \
        bats/bats:latest \
        cli/tests/
}

@test "mounts Unix project root in Docker container" {
    set_mock_state project_root "/c/code"
    run test
    assert_success
    assert_mock_called_once docker run -it \
        -v "/c/code:/code"
}

@test "converts Unix project root to MinGW path" {
    set_mock_state os "MINGW64_NT-10.0"
    set_mock_state project_root "/c/code"
    run test
    assert_success
    assert_mock_called_once cygpath -w
}

@test "mounts MinGW project root in Docker container" {
    set_mock_state os "MINGW64_NT-10.0"
    set_mock_state windows_project_root "C:\\code"
    run test
    assert_success
    assert_mock_called_once docker run -it \
        -v "C:\\code:/code"
}

@test "converts Unix project root to MSYS path" {
    set_mock_state os "MSYS_NT-10.0"
    set_mock_state project_root "/c/code"
    run test
    assert_success
    assert_mock_called_once cygpath -w
}

@test "mounts MSYS project root in Docker container" {
    set_mock_state os "MSYS_NT-10.0"
    set_mock_state windows_project_root "C:\\code"
    run test
    assert_success
    assert_mock_called_once docker run -it \
        -v "C:\code:/code"
}

@test "converts Unix project root to Cygwin path" {
    set_mock_state os "CYGWIN_NT-10.0"
    set_mock_state project_root "/c/code"
    run test
    assert_success
    assert_mock_called_once cygpath -w
}

@test "mounts Cygwin project root in Docker container" {
    set_mock_state os "CYGWIN_NT-10.0"
    set_mock_state windows_project_root "C:\\code"
    run test
    assert_success
    assert_mock_called_once cygpath -w
    assert_mock_called_once docker run -it \
        -v "C:\code:/code"
}

@test "runs BATS tests with specified test path" {
    run test test
    assert_success
    assert_mock_called_once docker run -it \
        bats/bats:latest \
        cli/tests/test.bats
}

@test "runs BATS tests with specified test filter (--filter)" {
    run test --filter "test_filter"
    assert_success
    assert_mock_called_once docker run -it \
        bats/bats:latest \
        -f "test_filter" \
        cli/tests/
}

@test "runs BATS tests with specified test filter (-e)" {
    run test -e "test_filter"
    assert_success
    assert_mock_called_once docker run -it \
        bats/bats:latest \
        -f "test_filter" \
        cli/tests/
}

@test "sets commit status to 'failure' after failing tests" {
    docker() { log_mock_call docker "$@"; return 1; }
    run test --set-status
    assert_failure
    assert_mock_called_once status set --self failure \
        --description "Automated tests failed."
}

@test "sets commit status to 'success' after passing tests" {
    run test --set-status
    assert_success
    assert_mock_called_once status set --self success \
        --description "Automated tests completed successfully."
}

@test "stops docker container" {
    run test
    assert_success
    assert_mock_called_once docker stop folio-tests-bats
}

@test "stops docker container after tests" {
    run test
    assert_success
    assert_mocks_called_in_order \
        docker run -- \
        docker stop folio-tests-bats
}

@test "removes docker container" {
    run test
    assert_success
    assert_mock_called_once docker rm folio-tests-bats
}

@test "removes docker container after stopped" {
    run test
    assert_success
    assert_mocks_called_in_order \
        docker stop folio-tests-bats -- \
        docker rm folio-tests-bats
}
