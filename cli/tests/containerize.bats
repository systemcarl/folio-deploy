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

    get_version() {
        log_mock_call get_version "$@"
        echo "1.2.3"
    }

    mock load_env

    FOLIO_APP_ACCOUNT="app-account"
    FOLIO_APP_REPO="app-repo"
}

teardown() {
    teardown_mocks
}

@test "containerizes application" {
    run containerize
    assert_success
}

@test "loads environment" {
    run containerize
    assert_success
    assert_mock_called_once load_env
}

@test "get application version" {
    run containerize
    assert_success
    assert_mock_called_once get_version folio
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

@test "builds container image" {
    run containerize
    assert_success
    assert_mock_called_once docker build \
        -f "Dockerfile" "."
}

@test "tags local container image" {
    run containerize
    assert_success
    assert_mock_called_once docker build \
        -t "app-repo:latest" \
        -t "app-repo:1.2.3"
}

@test "tags image with Github Package Registry namespace" {
    run containerize --push
    assert_success
    assert_mock_called_once docker build \
        -t "ghcr.io/app-account/app-repo:latest" \
        -t "ghcr.io/app-account/app-repo:1.2.3"
}

@test "labels image with version" {
    run containerize --push
    assert_success
    assert_mock_called_once docker build \
        --build-arg "VERSION=1.2.3"
}

@test "labels image with source" {
    run containerize --push
    assert_success
    assert_mock_called_once docker build \
        --build-arg "SOURCE=https://github.com/app-account/app-repo"
}

@test "pushes image to GitHub Package Registry" {
    run containerize --push
    assert_success
    assert_mock_called_times 2 docker push
    assert_mock_called_once docker push \
        "ghcr.io/app-account/app-repo:1.2.3"
    assert_mock_called_once docker push \
        "ghcr.io/app-account/app-repo:latest"
}
