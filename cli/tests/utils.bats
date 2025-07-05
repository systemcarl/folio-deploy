#!/usr/bin/env bats

TEST_DIR="$(realpath "$(dirname "$BATS_TEST_FILENAME")")"
source "$TEST_DIR/mocks"
source "$TEST_DIR/../utils/environment"
source "$TEST_DIR/../utils/json"
source "$TEST_DIR/../utils/package"
source "$TEST_DIR/../utils/repo"

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    setup_mocks

    mock npm

    node() {
        log_mock_call node "$@"
        echo $(get_mock_state node_response)
    }
    set_mock_state node_response "value"

    git() {
        log_mock_call git "$@"
        if [[ "$1" == "remote" && "$2" == "get-url" && "$3" == "origin" ]]; then
            echo $(get_mock_state remote_origin_url)
        elif [[ "$1" == "rev-parse" && "$2" == "--abbrev-ref" ]]; then
            echo $(get_mock_state abbrev_ref)
        elif [[ "$1" == "rev-parse" && "$2" == $(get_mock_state ref_1) ]]; then
            echo $(get_mock_state commit_sha_1)
        elif [[ "$1" == "rev-parse" && "$2" == $(get_mock_state ref_2) ]]; then
            echo $(get_mock_state commit_sha_2)
        fi
    }

    set_mock_state \
        remote_origin_url "https://github.com/app-account/app-repo.git"
    set_mock_state abbrev_ref "branch"
    set_mock_state ref_1 "HEAD"
    set_mock_state ref_2 "branch"
    set_mock_state commit_sha_1 "abcd1234"
    set_mock_state commit_sha_2 "abcd1234"
}

setup_env() {
    get_github_account() {
        log_mock_call get_github_account "$@"
        if [[ $(pwd) == "/code/folio" ]]; then
            echo "app-account"
        elif [[ $(pwd) == "/code" ]]; then
            echo "cicd-account"
        fi
    }
    get_github_repo() {
        log_mock_call get_github_repo "$@"
        if [[ $(pwd) == "/code/folio" ]]; then
            echo "app-repo"
        elif [[ $(pwd) == "/code" ]]; then
            echo "cicd-repo"
        fi
    }

    ENVIRONMENT="test"
    FOLIO_APP_DOMAIN="example.test"
    FOLIO_CF_DNS_ZONE="test1234"
    FOLIO_SSH_PORT="2222"
    FOLIO_ACME_EMAIL="example@example.com"
    FOLIO_SSH_KEY_ID="1234"
    FOLIO_PUBLIC_KEY_FILE="/path/to/test_key.pub"
    FOLIO_GCS_CREDENTIALS="/path/to/test_gcs_creds.json"
    FOLIO_CF_TOKEN="cf_test"
    FOLIO_DO_TOKEN="do_test"
    FOLIO_GH_TOKEN="gh_test"
}

teardown() {
    teardown_mocks
}

@test "environment loads" {
    setup_env
    run load_env
    assert_success
}

@test "defaults to production environment" {
    load_env
    assert_equal "$ENVIRONMENT" "production"
}

@test "loads application GitHub account" {
    setup_env
    load_env
    assert_equal "$FOLIO_APP_ACCOUNT" "app-account"
}

@test "loads application GitHub repository" {
    setup_env
    load_env
    assert_equal "$FOLIO_APP_REPO" "app-repo"
}

@test "loads CICD GitHub account" {
    setup_env
    load_env
    assert_equal "$FOLIO_CICD_ACCOUNT" "cicd-account"
}

@test "loads CICD GitHub repository" {
    setup_env
    load_env
    assert_equal "$FOLIO_CICD_REPO" "cicd-repo"
}

@test "uses environment variable" {
    setup_env
    load_env --env-file ""
    assert_equal "$ENVIRONMENT" "test"
}

@test "uses environment domain" {
    setup_env
    load_env --env-file ""
    assert_equal "$FOLIO_APP_DOMAIN" "example.test"
}

@test "uses environment DNS zone" {
    setup_env
    load_env --env-file ""
    assert_equal "$FOLIO_CF_DNS_ZONE" "test1234"
}

@test "uses environment SSH port" {
    setup_env
    load_env --env-file ""
    assert_equal "$FOLIO_SSH_PORT" "2222"
}

@test "uses environment ACME email" {
    setup_env
    load_env --env-file ""
    assert_equal "$FOLIO_ACME_EMAIL" "example@example.com"
}

@test "uses environment SSH key ID" {
    setup_env
    load_env --env-file ""
    assert_equal "$FOLIO_SSH_KEY_ID" "1234"
}

@test "uses environment public key file" {
    setup_env
    load_env --env-file ""
    assert_equal "$FOLIO_PUBLIC_KEY_FILE" "/path/to/test_key.pub"
}

@test "uses environment GCS credentials" {
    setup_env
    load_env --env-file ""
    assert_equal "$FOLIO_GCS_CREDENTIALS" "/path/to/test_gcs_creds.json"
}

@test "uses environment Cloudflare token" {
    setup_env
    load_env --env-file ""
    assert_equal "$FOLIO_CF_TOKEN" "cf_test"
}

@test "uses environment DigitalOcean token" {
    setup_env
    load_env --env-file ""
    assert_equal "$FOLIO_DO_TOKEN" "do_test"
}

@test "uses environment GitHub token" {
    setup_env
    load_env --env-file ""
    assert_equal "$FOLIO_GH_TOKEN" "gh_test"
}

@test "loads environment file variable" {
    setup_env
    load_env --env-file "cli/tests/test.env"
    assert_equal "$ENVIRONMENT" "env"
}

@test "loads environment file domain" {
    setup_env
    load_env --env-file "cli/tests/test.env"
    assert_equal "$FOLIO_APP_DOMAIN" "example.env"
}

@test "loads environment file DNS zone" {
    setup_env
    load_env --env-file "cli/tests/test.env"
    assert_equal "$FOLIO_CF_DNS_ZONE" "env123"
}

@test "loads environment file SSH port" {
    setup_env
    load_env --env-file "cli/tests/test.env"
    assert_equal "$FOLIO_SSH_PORT" "2233"
}

@test "loads environment file ACME email" {
    setup_env
    load_env --env-file "cli/tests/test.env"
    assert_equal "$FOLIO_ACME_EMAIL" "env@example.com"
}

@test "loads environment file SSH key ID" {
    setup_env
    load_env --env-file "cli/tests/test.env"
    assert_equal "$FOLIO_SSH_KEY_ID" "2345"
}

@test "loads environment file public key file" {
    setup_env
    load_env --env-file "cli/tests/test.env"
    assert_equal "$FOLIO_PUBLIC_KEY_FILE" "/path/to/env_key.pub"
}

@test "loads environment file GCS credentials" {
    setup_env
    load_env --env-file "cli/tests/test.env"
    assert_equal "$FOLIO_GCS_CREDENTIALS" "/path/to/env_creds.json"
}

@test "loads environment file Cloudflare token" {
    setup_env
    load_env --env-file "cli/tests/test.env"
    assert_equal "$FOLIO_CF_TOKEN" "cf_env"
}

@test "loads environment file DigitalOcean token" {
    setup_env
    load_env --env-file "cli/tests/test.env"
    assert_equal "$FOLIO_DO_TOKEN" "do_env"
}

@test "loads environment file GitHub token" {
    setup_env
    load_env --env-file "cli/tests/test.env"
    assert_equal "$FOLIO_GH_TOKEN" "gh_env"
}

@test "queries json using correct statements" {
    run query_json '{"key": "value"}' "key"
    assert_success
    assert_mock_called_once node -e "
        const json = JSON.parse(process.argv[1]);
        console.log(json[process.argv[2]]);
    "
}

@test "queries json with correct literals" {
    run query_json '{"key": "value"}' "key"
    assert_success
    assert_mock_called_once node -- '{"key": "value"}' "key"
}

@test "queries json property value" {
    set_mock_state node_response "value"
    run query_json '{"key": "value"}' "key"
    assert_success
    assert_output "value"
}

@test "does not raise error when json property is not found" {
    set_mock_state node_response "undefined"
    run query_json '{"key": "value"}' "value"
    assert_success
    assert_output "undefined"
}

@test "raises error when json property is not found" {
    set_mock_state node_response "undefined"
    run query_json -e '{"key": "value"}' "value"
    assert_failure
    assert_output --partial "Error: Unable to parse JSON or query not found."
}

@test "find json first item with correct statements" {
    run find_json '[{"key": "value"}]' "key" "value"
    assert_success
    assert_mock_called_once node -e "
        const json = JSON.parse(process.argv[1]);
        const match = json.filter(i => i[process.argv[2]] === process.argv[3]);
        console.log(JSON.stringify(match[0] || ''));
    "
}

@test "finds json last item with correct statements" {
    run find_json -l '[{"key": "value"}]' "key" "value"
    assert_success
    assert_mock_called_once node -e "
        const json = JSON.parse(process.argv[1]);
        const match = json.filter(i => i[process.argv[2]] === process.argv[3]);
        console.log(JSON.stringify(match[match.length - 1] || ''));
    "
}

@test "finds json item with correct literals" {
    run find_json '[{"key": "value"}]' "key" "value"
    assert_success
    assert_mock_called_once node -- '[{"key": "value"}]' "key" "value"
}

@test "finds json item by key-value" {
    set_mock_state node_response '{"key": "value"}'
    run find_json '[{"key": "value"}]' "key" "value"
    assert_success
    assert_output '{"key": "value"}'
}

@test "does not raise error when json is not found" {
    set_mock_state node_response ""
    run find_json '[{"key": "value"}]' "value" "key"
    assert_success
    assert_output ""
}

@test "raises error when json is not found" {
    set_mock_state node_response ""
    run find_json -e '{"key": "value"}' "value" "key"
    assert_failure
    assert_output --partial "Error: Unable to find item in JSON."
}

@test "gets version of application" {
    run get_version cli/tests
    assert_success
    assert_output "1.2.3"
}

@test "gets GitHub repository URL" {
    run get_origin_url
    assert_success
    assert_output "https://github.com/app-account/app-repo.git"
}

@test "gets GitHub account from repository URL" {
    run get_github_account
    assert_success
    assert_output "app-account"
}

@test "gets GitHub repository name from repository URL" {
    run get_github_repo
    assert_success
    assert_output "app-repo"
}

@test "gets current commit reference" {
    set_mock_state abbrev_ref "branch"
    run get_commit_ref
    assert_success
    assert_output "branch"
}

@test "compares commits with different references" {
    set_mock_state ref_1 "HEAD"
    set_mock_state ref_2 "branch"
    set_mock_state commit_sha_1 "abcd1234"
    set_mock_state commit_sha_2 "1234abcd"
    run compare_refs HEAD branch
    assert_success
}

@test "compares commits with same references" {
    set_mock_state ref_1 "HEAD"
    set_mock_state ref_2 "branch"
    set_mock_state commit_sha_1 "abcd1234"
    set_mock_state commit_sha_2 "abcd1234"
    run compare_refs HEAD branch
    assert_failure
}
