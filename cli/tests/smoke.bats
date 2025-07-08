#!/usr/bin/env bats

TEST_DIR="$(realpath "$(dirname "$BATS_TEST_FILENAME")")"
source "$TEST_DIR/mocks"
source "$TEST_DIR/../smoke"

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    setup_mocks

    curl() { log_mock_call curl $@; echo "200"; }
    sleep() { log_mock_call sleep $@; return 1; }

    mock load_env

    FOLIO_APP_DOMAIN="example.com"
}

teardown() {
    teardown_mocks
}

@test "completes tests" {
    run smoke
    assert_success
    assert_output --partial "Successfully connected to application."
}

@test "loads environment" {
    run smoke
    assert_success
    assert_mock_called_once load_env
}

@test "tests connection to application" {
    run smoke
    assert_success
    assert_mock_called_once curl -s "https://example.com/"
}

@test "tests connection to application domain" {
    run smoke --domain "test.example.com"
    assert_success
    assert_mock_called_once curl -s "https://test.example.com/"
}

@test "tests connection to application using HTTP" {
    run smoke --insecure
    assert_success
    assert_mock_called_once curl -s "http://example.com/"
}

@test "returns non-zero exit code if connection fails" {
    curl() { log_mock_call curl $@; return 1; }
    run smoke
    assert_failure
    assert_output --partial "Failed to connect to application."
}

@test "returns non-zero exit code if connection returns non-200 status" {
    curl() { log_mock_call curl $@; echo "500"; }
    run smoke
    assert_failure
    assert_output --partial "Failed to connect to application."
}
