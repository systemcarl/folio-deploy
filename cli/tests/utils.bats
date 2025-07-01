#!/usr/bin/env bats

TEST_DIR="$(realpath "$(dirname "$BATS_TEST_FILENAME")")"
source "$TEST_DIR/mocks"
source "$TEST_DIR/../utils/environment"
source "$TEST_DIR/../utils/json"
source "$TEST_DIR/../utils/package"

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    setup_mocks

    mock npm
    mock docker

    node() {
        log_mock_call node "$@"
        echo $(get_mock_state node_response)
    }
    set_mock_state node_response "value"

    export ENVIRONMENT="test"
    export FOLIO_GH_NAMESPACE="test-namespace"
    export FOLIO_GH_REPO="test-repo"
    export FOLIO_GH_PACKAGE="test-package"
    export FOLIO_APP_DOMAIN="test-domain"
    export FOLIO_CF_DNS_ZONE="test-zone"
    export FOLIO_SSH_PORT="2212"
    export FOLIO_PUBLIC_KEY_FILE="/path/to/test_key.pub"
    export FOLIO_CF_TOKEN="cf_test"
    export FOLIO_DO_TOKEN="do_test"
}

teardown() {
    teardown_mocks
}

@test "loads environment" {
    run load_env
    assert_success
}

@test "uses environment variable" {
    load_env --env-file ""
    assert_equal "$ENVIRONMENT" "test"
}

@test "uses environment namespace" {
    load_env --env-file ""
    assert_equal "$FOLIO_GH_NAMESPACE" "test-namespace"
}

@test "uses environment repository" {
    load_env --env-file ""
    assert_equal "$FOLIO_GH_REPO" "test-repo"
}

@test "uses environment package" {
    load_env --env-file ""
    assert_equal "$FOLIO_GH_PACKAGE" "test-package"
}

@test "uses environment domain" {
    load_env --env-file ""
    assert_equal "$FOLIO_APP_DOMAIN" "test-domain"
}

@test "uses environment DNS zone" {
    load_env --env-file ""
    assert_equal "$FOLIO_CF_DNS_ZONE" "test-zone"
}

@test "uses environment SSH port" {
    load_env --env-file ""
    assert_equal "$FOLIO_SSH_PORT" "2212"
}

@test "uses environment public key file" {
    load_env --env-file ""
    assert_equal "$FOLIO_PUBLIC_KEY_FILE" "/path/to/test_key.pub"
}

@test "uses environment Cloudflare token" {
    load_env --env-file ""
    assert_equal "$FOLIO_CF_TOKEN" "cf_test"
}

@test "uses environment DigitalOcean token" {
    load_env --env-file ""
    assert_equal "$FOLIO_DO_TOKEN" "do_test"
}

@test "loads environment file variable" {
    load_env --env-file "cli/tests/test.env"
    assert_equal "$ENVIRONMENT" "test-env"
}

@test "loads environment file namespace" {
    load_env --env-file "cli/tests/test.env"
    assert_equal "$FOLIO_GH_NAMESPACE" "env-namespace"
}

@test "loads environment file repository" {
    load_env --env-file "cli/tests/test.env"
    assert_equal "$FOLIO_GH_REPO" "env-repo"
}

@test "loads environment file package" {
    load_env --env-file "cli/tests/test.env"
    assert_equal "$FOLIO_GH_PACKAGE" "env-package"
}

@test "loads environment file domain" {
    load_env --env-file "cli/tests/test.env"
    assert_equal "$FOLIO_APP_DOMAIN" "env-domain"
}

@test "loads environment file DNS zone" {
    load_env --env-file "cli/tests/test.env"
    assert_equal "$FOLIO_CF_DNS_ZONE" "env-zone"
}

@test "loads environment file SSH port" {
    load_env --env-file "cli/tests/test.env"
    assert_equal "$FOLIO_SSH_PORT" "2222"
}

@test "loads environment file public key file" {
    load_env --env-file "cli/tests/test.env"
    assert_equal "$FOLIO_PUBLIC_KEY_FILE" "/path/to/env_key.pub"
}

@test "loads environment file Cloudflare token" {
    load_env --env-file "cli/tests/test.env"
    assert_equal "$FOLIO_CF_TOKEN" "cf_env"
}

@test "loads environment file DigitalOcean token" {
    load_env --env-file "cli/tests/test.env"
    assert_equal "$FOLIO_DO_TOKEN" "do_env"
}

@test "sets default namespace" {
    unset FOLIO_GH_NAMESPACE
    load_env --env-file ""
    assert_equal "$FOLIO_GH_NAMESPACE" "systemcarl"
}

@test "sets default repository" {
    unset FOLIO_GH_REPO
    load_env --env-file ""
    assert_equal "$FOLIO_GH_REPO" "folio"
}

@test "sets default package" {
    unset FOLIO_GH_PACKAGE
    load_env --env-file ""
    assert_equal "$FOLIO_GH_PACKAGE" "folio"
}

@test "get version of application" {
    run get_version cli/tests
    assert_success
    assert_output "1.2.3"
}

@test "query json evaluates correct statements" {
    run query_json '{"key": "value"}' "key"
    assert_success
    assert_mock_called_once node -e "
        const json = JSON.parse(process.argv[1]);
        console.log(json[process.argv[2]]);
    "
}

@test "passes json passes json and query" {
    run query_json '{"key": "value"}' "key"
    assert_success
    assert_mock_called_once node -- '{"key": "value"}' "key"
}

@test "query json returns value" {
    set_mock_state node_response "value"
    run query_json '{"key": "value"}' "key"
    assert_success
    assert_output "value"
}
