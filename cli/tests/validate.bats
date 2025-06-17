#!/usr/bin/env bats

TEST_DIR="$(realpath "$(dirname "$BATS_TEST_FILENAME")")"
source "$TEST_DIR/mocks"
source "$TEST_DIR/../validate"

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    setup_mocks

    mock npm
}

teardown() {
    teardown_mocks
}

@test "validates application" {
    run validate
    assert_success
    assert_output --partial "All tests passed successfully."
}

@test "installs npm dependencies" {
    run validate
    assert_success
    assert_mock_called_in_dir folio npm install
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
