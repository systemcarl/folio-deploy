#!/usr/bin/env bats

TEST_DIR="$(realpath "$(dirname "$BATS_TEST_FILENAME")")"
source "$TEST_DIR/mocks"
source "$TEST_DIR/../utils/environment"
source "$TEST_DIR/../utils/package"

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    setup_mocks

    mock npm
    mock docker

    export FOLIO_GH_NAMESPACE="test-namespace"
    export FOLIO_GH_REPO="test-repo"
    export FOLIO_GH_PACKAGE="test-package"
}

teardown() {
    teardown_mocks
}

@test "loads environment" {
    run load_env
    assert_success
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
