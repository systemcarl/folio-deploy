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
    export -f curl

    query_json() {
        log_mock_call query_json "$@"
        echo $(get_mock_state "curl_response")
    }
    export -f query_json

    set_mock_state curl_response '{"state": "success"}'

    export GITHUB_NAMESPACE="test-namespace"
    export GITHUB_TOKEN="abc123"
}

teardown() {
    teardown_mocks
}

@test "requires GitHub namespace" {
    unset GITHUB_NAMESPACE
    run status
    assert_failure
    assert_output --partial "Error: GitHub namespace required for status check."
}

@test "requires GutHub token" {
    unset GITHUB_TOKEN
    run status
    assert_failure
    assert_output --partial "Error: GitHub API token required for status check."
}

@test "accepts namespace as option" {
    unset GITHUB_NAMESPACE
    run status --namespace test-namespace
    assert_success
}

@test "accepts token as option" {
    unset GITHUB_TOKEN
    run status --token abc123
    assert_success
}

@test "fetches status from GitHub API" {
    run status
    assert_success
    assert_output --partial "success"
    assert_mock_called_once curl -s \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization Bearer $GITHUB_TOKEN" \
        "$GITHUB/repos/$GITHUB_NAMESPACE/folio/commits/main/status"
}

@test "queries commit status JSON" {
    set_mock_state curl_response '{"state": "value"}'
    run status
    assert_success
    assert_mock_called_once query_json '{"state": "value"}' 'state'
}


@test "returns commit status" {
    set_mock_state curl_response '{"state": "value"}'
    run status
    assert_success
    assert_output --partial "value"
}
