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
    mock status
    mock validate
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

@test "status script changes working directory to project root" {
    run ./status
    assert_success
    assert_mock_called_once cd "/code"
}

@test "status script changes working directory before sourcing" {
    run ./status
    assert_success
    assert_mocks_called_in_order \
        cd "/code" -- \
        source "./cli/status"
}

@test "status script sources the status file" {
    run ./status
    assert_success
    assert_mock_called_once source "./cli/status"
}

@test "status script sources before calling status function" {
    run ./status
    assert_success
    assert_mocks_called_in_order \
        source "./cli/status" -- \
        status
}

@test "status script passes arguments to status function" {
    run ./status --arg1 value1 --arg2 value2
    assert_success
    assert_mock_called_once status --arg1 value1 --arg2 value2
}

@test "status script exits with status function non-zero status" {
    status() { return 1; }
    run ./status
    assert_failure
}

@test "validate script changes working directory to project root" {
    run ./validate
    assert_success
    assert_mock_called_once cd "/code"
}

@test "validate script changes working directory before sourcing" {
    run ./validate
    assert_success
    assert_mocks_called_in_order \
        cd "/code" -- \
        source "./cli/validate"
}

@test "validate script sources the validate file" {
    run ./validate
    assert_success
    assert_mock_called_once source "./cli/validate"
}

@test "validate script sources before calling validate function" {
    run ./validate
    assert_success
    assert_mocks_called_in_order \
        source "./cli/validate" -- \
        validate
}

@test "validate script passes arguments to validate function" {
    run ./validate --arg1 value1 --arg2 value2
    assert_success
    assert_mock_called_once validate --arg1 value1 --arg2 value2
}

@test "validate script exits with validate function non-zero status" {
    validate() { return 1; }
    run ./validate
    assert_failure
}
