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
}

teardown() {
    teardown_mocks
}

@test "environment loads" {
    setup_env
    run load_env
    assert_success
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
