#!/usr/bin/env bats

TEST_DIR="$(realpath "$(dirname "$BATS_TEST_FILENAME")")"
source "$TEST_DIR/mocks"
source "$TEST_DIR/../deploy"

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    setup_mocks

    docker() {
        log_mock_call docker "$@"
        if [[ "$1" == "image" && "$2" == "inspect" ]]; then
            if [[ "$(get_mock_state has_image)" == "false" ]]; then
                return 1
            fi
        fi
    }
    export -f docker

    mock load_env

    export FOLIO_GH_NAMESPACE="default-namespace"
    export FOLIO_GH_PACKAGE="default-package"
}

teardown() {
    teardown_mocks
}

@test "loads environment" {
    run deploy
    assert_success
    assert_mock_called_once load_env
}

@test "deploys locally" {
    run deploy
    assert_success
    assert_output --partial \
        "Application is running on http://localhost:3000"
}

@test "deploys local Docker image to local container" {
    set_mock_state has_image true
    run deploy
    assert_success
    assert_mock_called_once docker run -d \
        --name "folio" \
        -p "3000:3000" \
        "default-package:latest"
}

@test "deploys package override to local container" {
    set_mock_state has_image true
    run deploy --package "test-package"
    assert_success
    assert_mock_called_once docker run -d \
        --name "folio" \
        -p "3000:3000" \
        "test-package:latest"
}

@test "does not pull remote Docker image if local image exists" {
    set_mock_state has_image true
    run deploy
    assert_success
    assert_mock_not_called docker pull
}

@test "deploys remote Docker image to local container requires namespace" {
    unset FOLIO_GH_NAMESPACE
    set_mock_state has_image false
    run deploy
    assert_failure
    assert_output --partial \
        "Error: GitHub namespace is required to retrieve image."
}

@test "pulls remote Docker image if local image does not exist" {
    set_mock_state has_image false
    run deploy
    assert_success
    assert_mock_called_once docker pull \
        "ghcr.io/default-namespace/default-package:latest"
}

@test "pulls remote Docker image from namespace override" {
    set_mock_state has_image false
    run deploy --namespace "test-namespace"
    assert_success
    assert_mock_called_once docker pull \
        "ghcr.io/test-namespace/default-package:latest"
}

@test "pulls remote Docker image from package override" {
    set_mock_state has_image false
    run deploy --package "test-package"
    assert_success
    assert_mock_called_once docker pull \
        "ghcr.io/default-namespace/test-package:latest"
}

@test "pulls remote Docker image before deploying" {
    set_mock_state has_image false
    run deploy
    assert_success
    assert_mocks_called_in_order \
        docker pull "ghcr.io/default-namespace/default-package:latest" -- \
        docker run -d \
            --name "folio" \
            -p "3000:3000" \
            "ghcr.io/default-namespace/default-package:latest"
}

@test "deploys remote Docker image to local container" {
    set_mock_state has_image false
    run deploy
    assert_success
    assert_mock_called_once docker run -d \
        --name "folio" \
        -p "3000:3000" \
        "ghcr.io/default-namespace/default-package:latest"
}

@test "deploys remote Docker image to local container with namespace override" {
    set_mock_state has_image false
    run deploy --namespace "test-namespace"
    assert_success
    assert_mock_called_once docker run -d \
        --name "folio" \
        -p "3000:3000" \
        "ghcr.io/test-namespace/default-package:latest"
}

@test "deploys remote Docker image to local container with package override" {
    set_mock_state has_image false
    run deploy --package "test-package"
    assert_success
    assert_mock_called_once docker run -d \
        --name "folio" \
        -p "3000:3000" \
        "ghcr.io/default-namespace/test-package:latest"
}
