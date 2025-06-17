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

    mock load_env

    FOLIO_APP_ACCOUNT="app-account"
    FOLIO_APP_REPO="app-repo"
}

teardown() {
    teardown_mocks
}

@test "deploys locally" {
    run deploy
    assert_success
    assert_output --partial \
        "Application is running on http://localhost:3000"
}

@test "loads environment" {
    run deploy
    assert_success
    assert_mock_called_once load_env
}

@test "deploys local Docker image to local container" {
    set_mock_state has_image true
    run deploy
    assert_success
    assert_mock_called_once docker run -d \
        --name "folio" \
        -p "3000:3000" \
        "app-repo:latest"
}

@test "deploys local package" {
    FOLIO_APP_REPO="test-package"
    set_mock_state has_image true
    run deploy
    assert_success
    assert_mock_called_once docker run -d \
        "test-package:latest"
}

@test "does not pull remote Docker image if local image exists" {
    set_mock_state has_image true
    run deploy
    assert_success
    assert_mock_not_called docker pull
}

@test "pulls remote Docker image if local image does not exist" {
    set_mock_state has_image false
    run deploy
    assert_success
    assert_mock_called_once docker pull \
        "ghcr.io/app-account/app-repo:latest"
}

@test "pulls remote Docker image from namespace" {
    FOLIO_APP_ACCOUNT="test-account"
    set_mock_state has_image false
    run deploy
    assert_success
    assert_mock_called_once docker pull \
        "ghcr.io/test-account/app-repo:latest"
}

@test "pulls remote package" {
    FOLIO_APP_REPO="test-package"
    set_mock_state has_image false
    run deploy
    assert_success
    assert_mock_called_once docker pull \
        "ghcr.io/app-account/test-package:latest"
}

@test "pulls remote Docker image before deploying" {
    set_mock_state has_image false
    run deploy
    assert_success
    assert_mocks_called_in_order \
        docker pull "ghcr.io/app-account/app-repo:latest" -- \
        docker run -d \
            --name "folio" \
            -p "3000:3000" \
            "ghcr.io/app-account/app-repo:latest"
}

@test "deploys remote Docker image to local container" {
    set_mock_state has_image false
    run deploy
    assert_success
    assert_mock_called_once docker run -d \
        --name "folio" \
        -p "3000:3000" \
        "ghcr.io/app-account/app-repo:latest"
}

@test "deploys remote package to local container" {
    FOLIO_APP_REPO="test-package"
    FOLIO_APP_ACCOUNT="test-account"
    set_mock_state has_image false
    run deploy
    assert_success
    assert_mock_called_once docker run -d \
        --name "folio" \
        -p "3000:3000" \
        "ghcr.io/test-account/test-package:latest"
}
