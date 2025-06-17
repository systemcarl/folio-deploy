#!/usr/bin/env bats

TEST_DIR="$(realpath "$(dirname "$BATS_TEST_FILENAME")")"
source "$TEST_DIR/mocks"
source "$TEST_DIR/../destroy"

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    setup_mocks

    docker() {
        log_mock_call docker "$@"
        if [[ "$1" == "ps" ]]; then
            if [[ $(get_mock_state "container_running") != "false" ]]; then
                echo "123456789abc"
            fi
        fi
    }
}

teardown() {
    teardown_mocks
}

@test "destroys locally" {
    run destroy
    assert_success
    assert_output --partial \
        "Application container stopped and removed successfully."
}

@test "does not stop container if no local container" {
    set_mock_state container_running false
    run destroy
    assert_success
    assert_mock_not_called docker stop
}

@test "does not remove container if no local container" {
    set_mock_state container_running false
    run destroy
    assert_success
    assert_mock_not_called docker rm
}

@test "stops local container" {
    run destroy
    assert_success
    assert_mock_called_once docker stop folio
}

@test "stops container before removing" {
    run destroy
    assert_success
    assert_mocks_called_in_order \
        docker stop folio -- \
        docker rm folio
}

@test "removes local container" {
    run destroy
    assert_success
    assert_mock_called_once docker rm folio
}
