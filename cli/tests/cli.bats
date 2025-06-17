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
    mock deploy
    mock destroy
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

@test "deploy script changes working directory to project root" {
    run ./deploy
    assert_success
    assert_mock_called_once cd "/code"
}

@test "deploy script changes working directory before sourcing" {
    run ./deploy
    assert_success
    assert_mocks_called_in_order \
        cd "/code" -- \
        source "./cli/deploy"
}

@test "deploy script sources the deploy file" {
    run ./deploy
    assert_success
    assert_mock_called_once source "./cli/deploy"
}

@test "deploy script sources before calling deploy function" {
    run ./deploy
    assert_success
    assert_mocks_called_in_order \
        source "./cli/deploy" -- \
        deploy
}

@test "deploy script passes arguments to deploy function" {
    run ./deploy --arg1 value1 --arg2 value2
    assert_success
    assert_mock_called_once deploy --arg1 value1 --arg2 value2
}

@test "deploy script exits with deploy function non-zero status" {
    deploy() { return 1; }
    run ./deploy
    assert_failure
}

@test "destroy script changes working directory to project root" {
    run ./destroy
    assert_success
    assert_mock_called_once cd "/code"
}

@test "destroy script changes working directory before sourcing" {
    run ./destroy
    assert_success
    assert_mocks_called_in_order \
        cd "/code" -- \
        source "./cli/destroy"
}

@test "destroy script sources the destroy file" {
    run ./destroy
    assert_success
    assert_mock_called_once source "./cli/destroy"
}

@test "destroy script sources before calling destroy function" {
    run ./destroy
    assert_success
    assert_mocks_called_in_order \
        source "./cli/destroy" -- \
        destroy
}

@test "destroy script passes arguments to destroy function" {
    run ./destroy --arg1 value1 --arg2 value2
    assert_success
    assert_mock_called_once destroy --arg1 value1 --arg2 value2
}

@test "destroy script exits with destroy function non-zero status" {
    destroy() { return 1; }
    run ./destroy
    assert_failure
}
