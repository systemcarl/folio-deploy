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
    mock load_env

    get_version() {
        log_mock_call get_version "$@"
        echo "1.2.3"
    }
    export -f get_version

    export FOLIO_GH_NAMESPACE="default-namespace"
    export FOLIO_GH_REPO="default-repo"
    export FOLIO_GH_PACKAGE="default-package"
}

teardown() {
    teardown_mocks
}

@test "loads environment" {
    run containerize
    assert_success
    assert_mock_called_once load_env
}

@test "accepts namespace as options" {
    unset FOLIO_GH_NAMESPACE
    run containerize \
        --push \
        --namespace "test-namespace"
    assert_success
}

@test "reads namespace from environment variable" {
    run containerize --push
    assert_success
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

@test "installs npm dependencies before testing" {
    run containerize
    assert_success
    assert_mocks_called_in_order \
        npm install -- \
        npm run test
}

@test "runs tests" {
    run containerize
    assert_success
    assert_mock_called_once npm run test
    assert_mock_called_in_dir folio npm run test
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

@test "build container image" {
    run containerize
    assert_success
    assert_mock_called_once docker build \
        -f "Dockerfile" "."
}

@test "tags local container image" {
    run containerize
    assert_success
    assert_mock_called_once docker build \
        -t "default-package:latest" \
        -t "default-package:1.2.3"
}

@test "tags image with Github Package Registry namespace" {
    run containerize --push
    assert_success
    assert_mock_called_once docker build \
        -t "ghcr.io/default-namespace/default-package:latest" \
        -t "ghcr.io/default-namespace/default-package:1.2.3"
}

@test "tags image with namespace override" {
    run containerize --push --namespace "test-namespace"
    assert_success
    assert_mock_called_once docker build \
        -t "ghcr.io/test-namespace/default-package:latest" \
        -t "ghcr.io/test-namespace/default-package:1.2.3"
}

@test "tags image with package name override" {
    run containerize --push --package "test-package"
    assert_success
    assert_mock_called_once docker build \
        -t "ghcr.io/default-namespace/test-package:latest" \
        -t "ghcr.io/default-namespace/test-package:1.2.3"
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
        --build-arg "SOURCE=https://github.com/default-namespace/default-repo"
}

@test "labels image with namespace override" {
    run containerize --namespace "test-namespace"
    assert_success
    assert_mock_called_once docker build \
        --build-arg "SOURCE=https://github.com/test-namespace/default-repo"
}

@test "labels local container image with repository name override" {
    run containerize --repo "test-repo"
    assert_success
    assert_mock_called_once docker build \
        --build-arg "SOURCE=https://github.com/default-namespace/test-repo"
}

@test "pushes image to GitHub Package Registry" {
    run containerize --push
    assert_success
    assert_mock_called_times 2 docker push
    assert_mock_called_once docker push \
        "ghcr.io/default-namespace/default-package:1.2.3"
    assert_mock_called_once docker push \
        "ghcr.io/default-namespace/default-package:latest"
}

@test "pushes image to namespace override" {
    run containerize --push --namespace "test-namespace"
    assert_success
    assert_mock_called_times 2 docker push
    assert_mock_called_once docker push \
        "ghcr.io/test-namespace/default-package:1.2.3"
    assert_mock_called_once docker push \
        "ghcr.io/test-namespace/default-package:latest"
}

@test "pushes image to package override" {
    run containerize --push --package "test-package"
    assert_success
    assert_mock_called_times 2 docker push
    assert_mock_called_once docker push \
        "ghcr.io/default-namespace/test-package:1.2.3"
    assert_mock_called_once docker push \
        "ghcr.io/default-namespace/test-package:latest"
}
