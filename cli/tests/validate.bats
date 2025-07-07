#!/usr/bin/env bats

TEST_DIR="$(realpath "$(dirname "$BATS_TEST_FILENAME")")"
source "$TEST_DIR/mocks"
source "$TEST_DIR/../validate"

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    setup_mocks

    mock npm
    mock git

    status() { log_mock_call status "$@"; echo "none"; }

    compare_refs() {
        log_mock_call compare_refs "$@"
        if [[ $(get_mock_state is_current_ref) == "true" ]]; then
            return 1
        fi
    }

    set_mock_state is_current_ref "true"

    mock load_env

    FOLIO_GH_TOKEN="gh_token"
}

teardown() {
    teardown_mocks
}

@test "validates application" {
    run validate
    assert_success
    assert_output --partial "All tests passed successfully."
}

@test "returns non-zero exit code if change directory fails" {
    cd() { log_mock_call cd "$@"; return 1; }
    run validate
    assert_failure
}

@test "does not require GitHub token" {
    unset FOLIO_GH_TOKEN
    run validate
    assert_success
}

@test "requires GitHub token to update commit status" {
    unset FOLIO_GH_TOKEN
    run validate --set-status
    assert_failure
    assert_output --partial "GitHub token required to set commit status."
}

@test "does not set commit status" {
    run validate
    assert_success
    assert_mock_not_called status
}

@test "refuses to validate if commit status already set" {
    status() { log_mock_call status "$@"; echo "pending"; }
    run validate --set-status
    assert_failure
    assert_output --partial "Commit previously validated: pending."
    assert_mock_not_called status set
}

@test "forces validation (--force) if commit status already set" {
    status() { log_mock_call status "$@"; echo "pending"; }
    run validate --set-status --force
    assert_success
    assert_mock_called_once status set pending
}

@test "forces validation (-f) if commit status already set" {
    status() { log_mock_call status "$@"; echo "pending"; }
    run validate --set-status -f
    assert_success
    assert_mock_called_once status set pending
}

@test "sets commit status to 'pending'" {
    run validate --set-status
    assert_success
    assert_mock_called_once status set pending \
        --description "Validation started."
}

@test "sets target commit status to 'pending'" {
    run validate --set-status branch
    assert_success
    assert_mock_called_once status set branch pending \
        --description "Validation started."
}

@test "sets commit status to 'pending' before installing dependencies" {
    run validate --set-status branch
    assert_success
    assert_mocks_called_in_order \
        status set branch pending --description "Validation started." -- \
        npm install
}

@test "does not update version if change directory fails" {
    set_mock_state is_current_ref "false"
    cd() { log_mock_call cd "$@"; return 1; }
    run validate branch
    assert_failure
    assert_mock_not_called git checkout
}

@test "does not update app version if already on reference commit" {
    set_mock_state is_current_ref "true"
    run validate branch
    assert_success
    assert_mock_not_called git checkout
}

@test "updates app version if not already on reference commit" {
    set_mock_state is_current_ref "false"
    run validate branch
    assert_success
    assert_mock_called_in_dir folio git checkout branch
}

@test "returns non-zero exit code if checkout fails" {
    set_mock_state is_current_ref "false"
    git() { log_mock_call git "$@"; return 1; }
    run validate branch
    assert_failure
    assert_output --partial "Failed to checkout branch."
}

@test "restores previous app version on signal interruption" {
    set_mock_state is_current_ref "false"
    npm() { log_mock_call npm "$@"; kill -s SIGINT $BASHPID; }
    run validate branch
    assert_failure
    assert_mock_called_in_dir folio git checkout -f -
    assert_mocks_called_in_order \
        git checkout branch -- \
        git checkout -f -
}

@test "updates app version before installing dependencies" {
    set_mock_state is_current_ref "false"
    run validate branch
    assert_success
    assert_mocks_called_in_order \
        git checkout branch -- \
        npm install
}

@test "installs npm dependencies" {
    run validate
    assert_success
    assert_mock_called_in_dir folio npm install
}

@test "sets commit status to 'failure' after failing to install dependencies" {
    npm() { log_mock_call npm "$@"; return 1; }
    run validate --set-status branch
    assert_failure
    assert_mock_called_once status set branch failure \
        --description "Validation failed to install dependencies."
}

@test "restores previous app version if install fails" {
    set_mock_state is_current_ref "false"
    npm() { log_mock_call npm "$@"; return 1; }
    run validate branch
    assert_failure
    assert_mock_called_in_dir folio git checkout -f -
    assert_mocks_called_in_order \
        npm install -- \
        git checkout -f -
}

@test "installs npm dependencies before testing" {
    run validate
    assert_success
    assert_mocks_called_in_order \
        npm install -- \
        npm run test
}

@test "runs tests" {
    run validate
    assert_success
    assert_mock_called_once npm run test
    assert_mock_called_in_dir folio npm run test
}

@test "sets commit status to 'failure' after failing tests" {
    npm() {
        log_mock_call npm "$@";
        if [[ "$1" == "run" && "$2" == "test" ]]; then return 1; fi
    }
    run validate --set-status branch
    assert_failure
    assert_mock_called_once status set branch failure \
        --description "Validation tests failed."
}

@test "sets commit status to 'success' after passing tests" {
    run validate --set-status branch
    assert_success
    assert_mock_called_once status set branch success \
        --description "Validation tests passed."
}

@test "restores previous app version after tests" {
    set_mock_state is_current_ref "false"
    run validate branch
    assert_success
    assert_mock_called_in_dir folio git checkout -f -
    assert_mocks_called_in_order \
        npm run test -- \
        git checkout -f -
}
