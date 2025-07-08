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
        if [[ " $* " != *" POST "* ]] && [[ "$*" == *"/statuses"* ]]; then
            echo $(get_mock_state "get_response")
        elif [[ " $* " == *" POST "* ]]; then
            echo $(get_mock_state "post_response")
        else
            echo $(get_mock_state "sha_response")
        fi
    }

    query_json() {
        log_mock_call query_json "$@"
        local j="${@: -2:1}"
        local q="${@: -1:1}"
        local get_response=$(get_mock_state get_response)
        local post_response=$(get_mock_state post_response)
        local sha_response=$(get_mock_state sha_response)
        local find_context_result=$(get_mock_state find_context_result)
        if [[ "$j" == "$get_response" ]] && [[ "$q" == "status" ]]; then
            echo $(get_mock_state "query_get_response_status_result")
        elif [[ "$j" == "$post_response" ]] && [[ "$q" == "status" ]]; then
            echo $(get_mock_state "query_post_response_status_result")
        elif [[ "$j" == "$sha_response" ]] && [[ "$q" == "status" ]]; then
            echo $(get_mock_state "query_get_sha_response_status_result")
        elif [[ "$j" == "$find_context_result" ]] && [[ "$q" == "state" ]]; then
            echo $(get_mock_state "query_get_response_state_result")
        elif [[ "$j" == "$post_response" ]] && [[ "$q" == "state" ]]; then
            echo $(get_mock_state "query_post_response_state_result")
        elif [[ "$j" == "$sha_response" ]] && [[ "$q" == "sha" ]]; then
            echo $(get_mock_state "query_get_sha_response_sha_result")
        fi
    }

    find_json() {
        log_mock_call find_json "$@"
        echo $(get_mock_state "find_context_result")
    }

    get_commit_ref() {
        log_mock_call get_commit_ref "$@"
        echo $(get_mock_state abbrev_ref)
    }

    set_mock_state get_response \
        '[{"context": "ci/cicd-repo", "state": "pending"}]'
    set_mock_state post_response \
        '{"context": "ci/cicd-repo", "state": "success"}'
    set_mock_state sha_response \
        '{"sha": "abcd1234"}'
    set_mock_state query_get_response_status_result ""
    set_mock_state query_get_sha_response_status_result ""
    set_mock_state query_post_response_status_result ""
    set_mock_state query_get_response_state_result "pending"
    set_mock_state query_get_sha_response_sha_result "abcd1234"
    set_mock_state query_post_response_state_result "success"
    set_mock_state find_context_result \
        '[{"context": "ci/cicd-repo", "state": "pending"}]'

    set_mock_state abbrev_ref "main"

    mock load_env

    FOLIO_APP_ACCOUNT="app-account"
    FOLIO_APP_REPO="app-repo"
    FOLIO_CICD_ACCOUNT="cicd-account"
    FOLIO_CICD_REPO="cicd-repo"
    FOLIO_GH_TOKEN="abc123"
}

teardown() {
    teardown_mocks
}

@test "gets commit status" {
    run status
    assert_success
    assert_output --partial "pending"
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
    assert_mock_called_once curl -s \
        -H "Accept: application/vnd.github.v3+json" \
        "$GITHUB/repos/app-account/app-repo/commits/main/statuses"
}

@test "fetches specified branch status from GitHub API" {
    run status test
    assert_success
    assert_mock_called_once curl -s \
        -H "Accept: application/vnd.github.v3+json" \
        "$GITHUB/repos/app-account/app-repo/commits/test/statuses"
}

@test "fetches current commit status from GitHub API" {
    set_mock_state abbrev_ref "abcd1234"
    run status
    assert_success
    assert_mock_called_once get_commit_ref
    assert_mock_called_in_dir "folio" get_commit_ref
    assert_mock_called_once curl -s \
        -H "Accept: application/vnd.github.v3+json" \
        "$GITHUB/repos/app-account/app-repo/commits/abcd1234/statuses"
}

@test "fetches status from CI/CD repository" {
    run status --self
    assert_success
    assert_mock_called_once curl -s \
        -H "Accept: application/vnd.github.v3+json" \
        "$GITHUB/repos/cicd-account/cicd-repo/commits/main/statuses"
}

@test "fetches current commit status from CI/CD repository" {
    set_mock_state abbrev_ref "abcd1234"
    run status --self
    assert_success
    assert_mock_called_once get_commit_ref
    assert_mock_called_in_dir "" get_commit_ref
    assert_mock_called_once curl -s \
        -H "Accept: application/vnd.github.v3+json" \
        "$GITHUB/repos/cicd-account/cicd-repo/commits/abcd1234/statuses"
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

@test "queries fetch status response status code" {
    set_mock_state get_response '{"status": 200}'
    run status
    assert_success
    assert_mock_called_once query_json '{"status": 200}' "status"
}

@test "returns status code from failed fetch status request" {
    set_mock_state query_get_response_status_result 418
    run status
    assert_failure
    assert_output --partial "Error: GitHub API returned an error: 418"
}

@test "finds commit status in response" {
    set_mock_state get_response \
        '[{"context": "ci/cicd-repo", "state": "value"}]'
    run status
    assert_success
    assert_mock_called_once find_json -l \
        '[{"context": "ci/cicd-repo", "state": "value"}]' \
        'context' 'ci/cicd-repo'
}

@test "finds contextual commit status in response" {
    FOLIO_CICD_REPO="test-repo"
    set_mock_state get_response \
        '[{"context": "ci/test-repo", "state": "value"}]'
    run status
    assert_success
    assert_mock_called_once find_json -l \
        '[{"context": "ci/test-repo", "state": "value"}]' \
        'context' 'ci/test-repo'
}

@test "defaults to 'none' state when no status found" {
    set_mock_state find_context_result ""
    run status
    assert_success
    assert_output "none"
}

@test "does not query commit status state when no status found" {
    set_mock_state find_context_result ""
    run status
    assert_success
    assert_mock_not_called query_json "" "state"
}

@test "queries commit status state" {
    set_mock_state find_context_result '{"state": "value"}'
    run status
    assert_success
    assert_mock_called_once query_json '{"state": "value"}' "state"
}

@test "returns commit status" {
    set_mock_state query_get_response_state_result "value"
    run status
    assert_success
    assert_output "value"
}

@test "does not set status" {
    run status
    assert_success
    assert_mock_not_called curl -X POST
}

@test "does not set status when getting status" {
    run status get
    assert_success
    assert_mock_not_called curl -X POST
}

@test "sets status" {
    set_mock_state query_post_response_state_result "value"
    run status set value
    assert_success
    assert_output "value"
}

@test "sets status when no status set" {
    set_mock_state find_context_result ""
    run status set value
    assert_success
    assert_mock_called_once curl -s -X POST \
        -H "Accept: application/vnd.github.v3+json" \
        "$GITHUB/repos/app-account/app-repo/statuses/abcd1234" \
        -d '{
            "state": "value",
            "context": "ci/cicd-repo",
            "description": "Automated validation by cicd-repo CI."
        }'
}

@test "does not set status when status already set" {
    set_mock_state query_get_response_state_result "value"
    run status set value
    assert_success
    assert_mock_not_called curl -X POST
}

@test "fetches commit SHA" {
    run status set branch value
    assert_success
    assert_mock_called_once curl -s \
        -H "Accept: application/vnd.github.v3+json" \
        "$GITHUB/repos/app-account/app-repo/commits/branch"
}

@test "queries fetch commit SHA response status code" {
    set_mock_state sha_response '{"status": 200}'
    run status set branch value
    assert_success
    assert_mock_called_once query_json '{"status": 200}' "status"
}

@test "returns status code from failed fetch commit SHA request" {
    set_mock_state query_get_sha_response_status_result 418
    run status set branch value
    assert_failure
    assert_output --partial "Error: GitHub API returned an error: 418"
}

@test "queries fetch commit SHA response SHA" {
    set_mock_state sha_response '{"sha": "abcd1234"}'
    run status set branch value
    assert_success
    assert_mock_called_once query_json '{"sha": "abcd1234"}' "sha"
}

@test "sets status of main" {
    run status set main value
    assert_success
    assert_mock_called_once curl -s -X POST \
        -H "Accept: application/vnd.github.v3+json" \
        "$GITHUB/repos/app-account/app-repo/statuses/abcd1234" \
        -d '{
            "state": "value",
            "context": "ci/cicd-repo",
            "description": "Automated validation by cicd-repo CI."
        }'
}

@test "sets status of CI/CD repository" {
    run status set --self value
    assert_success
    assert_mock_called_once curl -s -X POST \
        -H "Accept: application/vnd.github.v3+json" \
        "$GITHUB/repos/cicd-account/cicd-repo/statuses/abcd1234" \
        -d '{
            "state": "value",
            "context": "ci/cicd-repo",
            "description": "Automated self-validation."
        }'
}

@test "sets status with authorization header" {
    run status set value
    assert_success
    assert_mock_called_once curl -s -X POST \
        -H "Authorization: Bearer abc123"
}

@test "sets status using token" {
    run status set --token 456def value
    assert_success
    assert_mock_called_once curl -s -X POST \
        -H "Authorization: Bearer 456def"
}

@test "sets status with context" {
    run status set value --context "ci/test-repo"
    assert_success
    assert_mock_called_once curl -s -X POST \
        -H "Accept: application/vnd.github.v3+json" \
        "$GITHUB/repos/app-account/app-repo/statuses/abcd1234" \
        -d '{
            "state": "value",
            "context": "ci/test-repo",
            "description": "Automated validation by cicd-repo CI."
        }'
}

@test "sets status with description" {
    run status set value --description "Im a teapot."
    assert_success
    assert_mock_called_once curl -s -X POST \
        -H "Accept: application/vnd.github.v3+json" \
        "$GITHUB/repos/app-account/app-repo/statuses/abcd1234" \
        -d '{
            "state": "value",
            "context": "ci/cicd-repo",
            "description": "Im a teapot."
        }'
}

@test "queries set status response status code" {
    set_mock_state post_response '{"status": 201}'
    run status set value
    assert_success
    assert_mock_called_once query_json '{"status": 201}' "status"
}

@test "returns status code from failed set status request" {
    set_mock_state query_post_response_status_result 418
    run status set value
    assert_failure
    assert_output --partial "Error: GitHub API returned an error: 418"
}

@test "queries set status response state" {
    set_mock_state post_response '{"state": "value"}'
    run status set value
    assert_success
    assert_mock_called_once query_json '{"state": "value"}' "state"
}
