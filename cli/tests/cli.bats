#!/usr/bin/env bats

TEST_DIR="$(realpath "$(dirname "$BATS_TEST_FILENAME")")"
source "$TEST_DIR/mocks"

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    setup_mocks

    mock cd
    mock source
    mock containerize
}

teardown() {
    teardown_mocks
}

@test "containerize script changes working directory to project root" {
    run ./containerize
    assert_success
    assert_mock_called_once cd "/code"
}

@test "containerize script changes working directory before sourcing" {
    run ./containerize
    assert_success
    assert_mocks_called_in_order \
        cd "/code" -- \
        source "./cli/containerize"
}

@test "containerize script sources the containerize file" {
    run ./containerize
    assert_success
    assert_mock_called_once source "./cli/containerize"
}

@test "containerize script sources before calling containerize function" {
    run ./containerize
    assert_success
    assert_mocks_called_in_order \
        source "./cli/containerize" -- \
        containerize
}

@test "containerize script passes arguments to containerize function" {
    run ./containerize --arg1 value1 --arg2 value2
    assert_success
    assert_mock_called_once containerize --arg1 value1 --arg2 value2
}

@test "containerize script exits with containerize function non-zero status" {
    containerize() { return 1; }
    run ./containerize
    assert_failure
}
