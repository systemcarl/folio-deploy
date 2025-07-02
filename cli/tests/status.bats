#!/usr/bin/env bats

TEST_DIR="$(realpath "$(dirname "$BATS_TEST_FILENAME")")"
source "$TEST_DIR/mocks"
source "$TEST_DIR/../status"

GITHUB="https://api.github.com"

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    setup_mocks

    curl() {
        log_mock_call curl "$@"
        echo $(get_mock_state "curl_response")
    }

    query_json() {
        log_mock_call query_json "$@"
        echo $(get_mock_state "curl_response")
    }

    set_mock_state curl_response '{"state": "success"}'

    mock load_env

    FOLIO_APP_ACCOUNT="app-account"
    FOLIO_APP_REPO="app-repo"
    FOLIO_GH_TOKEN="abc123"
}

teardown() {
    teardown_mocks
}

@test "gets commit status" {
    run status
    assert_success
    assert_output --partial "success"
}

@test "requires GutHub token" {
    unset FOLIO_GH_TOKEN
    run status
    assert_failure
    assert_output --partial "Error: GitHub API token required for status check."
}

@test "accepts token as option" {
    unset FOLIO_GH_TOKEN
    run status --token abc123
    assert_success
}

@test "fetches status from GitHub API" {
    run status
    assert_success
    assert_output --partial "success"
    assert_mock_called_once curl -s \
        -H "Accept: application/vnd.github.v3+json" \
        "$GITHUB/repos/app-account/app-repo/commits/main/status"
}

@test "fetches status with authorization header" {
    run status
    assert_success
    assert_mock_called_once curl -s \
        -H "Authorization: Bearer abc123"
}

@test "fetches status using token" {
    run status --token 456def
    assert_success
    assert_mock_called_once curl -s \
        -H "Authorization: Bearer 456def"
}

@test "queries commit status JSON" {
    set_mock_state curl_response '{"state": "value"}'
    run status
    assert_success
    assert_mock_called_once query_json '{"state": "value"}' "state"
}

@test "returns commit status" {
    set_mock_state curl_response '{"state": "value"}'
    run status
    assert_success
    assert_output --partial "value"
}
