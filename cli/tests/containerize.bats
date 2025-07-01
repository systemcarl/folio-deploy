#!/usr/bin/env bats

TEST_DIR="$(realpath "$(dirname "$BATS_TEST_FILENAME")")"
source "$TEST_DIR/mocks"
source "$TEST_DIR/../containerize"

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    setup_mocks

    mock npm
    mock docker
}

teardown() {
    teardown_mocks
}

@test "containerizes application" {
    run containerize
    assert_success
}

@test "installs npm dependencies" {
    run containerize
    assert_success
    assert_mock_called_once npm install
    assert_mock_called_in_dir folio npm install
}

@test "builds SvelteKit application" {
    run containerize
    assert_success
    assert_mock_called_once npm run build
    assert_mock_called_in_dir folio npm run build
}

@test "installs npm dependencies before building" {
    run containerize
    assert_success
    assert_mocks_called_in_order \
        npm install -- \
        npm run build
}

@test "builds local container image" {
    run containerize
    assert_success
    assert_mock_called_once docker build -t folio:latest
}
