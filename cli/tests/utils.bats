#!/usr/bin/env bats

TEST_DIR="$(realpath "$(dirname "$BATS_TEST_FILENAME")")"
source "$TEST_DIR/mocks"
source "$TEST_DIR/../utils/environment"
source "$TEST_DIR/../utils/package"
source "$TEST_DIR/../utils/repo"

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    setup_mocks

    mock npm

    git() {
        log_mock_call git "$@"
        if [[ "$1" == "remote" && "$2" == "get-url" && "$3" == "origin" ]]; then
            echo $(get_mock_state remote_origin_url)
        fi
    }

    set_mock_state \
        remote_origin_url "https://github.com/app-account/app-repo.git"
}

setup_env() {
    get_github_account() {
        log_mock_call get_github_account "$@"
        echo "app-account"
    }
    get_github_repo() {
        log_mock_call get_github_repo "$@"
        echo "app-repo"
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
