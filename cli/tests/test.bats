#!/usr/bin/env bats

TEST_DIR="$(realpath "$(dirname "$BATS_TEST_FILENAME")")"
source "$TEST_DIR/mocks"
source "$TEST_DIR/../test"

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    setup_mocks

    uname() { log_mock_call uname "$@" ;echo $(get_mock_state os); }
    pwd() { log_mock_call pwd "$@"; echo $(get_mock_state project_root); }
    cygpath() {
        log_mock_call cygpath "$@";
        echo $(get_mock_state windows_project_root);
    }

    mock docker
    mock terraform
    mock deploy
    mock destroy
    status() {
        log_mock_call status "$@";
        echo 'none';
    }

    set_mock_state os "Linux"
    set_mock_state project_root "/c/"
    set_mock_state windows_project_root "C:\\"

    mock load_env

    FOLIO_GH_TOKEN="gh_token"
}

teardown() {
    teardown_mocks
}

@test "runs tests" {
    run test
    assert_success
    assert_output --partial "All tests passed successfully."
}

@test "does not require GitHub token" {
    unset FOLIO_GH_TOKEN
    run test
    assert_success
}

@test "requires GitHub token to update commit status" {
    unset FOLIO_GH_TOKEN
    run test --set-status
    assert_failure
    assert_output --partial "GitHub token required to set commit status."
}

@test "does not set commit status" {
    run test
    assert_success
    assert_mock_not_called status set
}

@test "refuses to run tests if commit status already set" {
    status() { log_mock_call status "$@"; echo "pending"; }
    run test --set-status
    assert_failure
    assert_output --partial "Commit already tested: pending."
    assert_mock_not_called docker run
}

@test "forces tests (--force) if commit status already set" {
    status() { log_mock_call status "$@"; echo "pending"; }
    run test --set-status --force
    assert_success
    assert_mock_called_once status set pending
}

@test "forces tests (-f) if commit status already set" {
    status() { log_mock_call status "$@"; echo "pending"; }
    run test --set-status -f
    assert_success
    assert_mock_called_once status set pending
}

@test "sets commit status to 'pending'" {
    run test --set-status
    assert_success
    assert_mock_called_once status set --self pending \
        --description "Automated tests started."
}

@test "sets commit status to 'pending' before running tests" {
    run test --set-status
    assert_success
    assert_mocks_called_in_order \
        status set --self pending \
            --description "Automated tests started." -- \
        docker run
}

@test "pulls BATS Docker image silently" {
    docker() {
        log_mock_call docker "$@"
        if [[ "$1" == "pull" ]]; then echo "latest: Pulling from bats/bats"; fi
    }
    run test
    assert_success
    refute_output --partial "latest: Pulling from bats/bats"
}

@test "pulls BATS Docker image verbosely" {
    docker() {
        log_mock_call docker "$@"
        if [[ "$1" == "pull" ]]; then echo "latest: Pulling from bats/bats"; fi
    }
    run test --verbose
    assert_success
    assert_output --partial "latest: Pulling from bats/bats"
}

@test "does not pull BATS Docker image for terraform tests" {
    run test --terraform
    assert_success
    assert_mock_not_called docker pull bats/bats:latest
}

@test "does not pull BATS Docker image for deployment tests" {
    run test --deploy
    assert_success
    assert_mock_not_called docker pull bats/bats:latest
}

@test "runs command line interface BATS tests" {
    run test
    assert_success
    assert_mock_called_once docker run -it --rm \
        --name folio-tests-bats \
        bats/bats:latest \
        cli/tests/
}

@test "runs command line interface BATS tests only" {
    run test --cli
    assert_success
    assert_mock_not_called docker run -it --rm \
        --name folio-tests-bats \
        bats/bats:latest \
        infra/tests/
    assert_mock_not_called terraform --chdir=infra test
    assert_mock_not_called deploy
    assert_mock_not_called destroy
}

@test "returns non-zero if command line interface BATS tests fail" {
    docker() { log_mock_call docker "$@"; return 1; }
    run test
    assert_failure
    assert_output --partial "Command line interface BATS tests failed."
}


@test "runs command line interface BATS tests with test path" {
    run test test
    assert_success
    assert_mock_called_once docker run -it \
        bats/bats:latest \
        cli/tests/test.bats
}

@test "runs command line interface BATS tests with test filter (--filter)" {
    run test --filter "test_filter"
    assert_success
    assert_mock_called_once docker run -it \
        bats/bats:latest \
        -f "test_filter" \
        cli/tests/
}

@test "runs command line interface BATS tests with test filter (-e)" {
    run test -e "test_filter"
    assert_success
    assert_mock_called_once docker run -it \
        bats/bats:latest \
        -f "test_filter" \
        cli/tests/
}

@test "runs infrastructure BATS tests" {
    run test
    assert_success
    assert_mock_called_once docker run -it --rm \
        --name folio-tests-bats \
        bats/bats:latest \
        infra/tests/
    assert_mock_called_once terraform -chdir=infra test
}

@test "runs infrastructure BATS tests only" {
    run test --infra
    assert_success
    assert_mock_not_called docker run -it --rm \
        --name folio-tests-bats \
        bats/bats:latest \
        cli/tests/
    assert_mock_not_called deploy
    assert_mock_not_called destroy
}

@test "returns non-zero if infrastructure BATS tests fail" {
    docker() { log_mock_call docker "$@"; return 1; }
    run test
    assert_failure
    assert_output --partial "Infrastructure BATS tests failed."
}

@test "runs infrastructure BATS tests with test path" {
    run test cloud
    assert_success
    assert_mock_called_once docker run -it \
        bats/bats:latest \
        infra/tests/cloud.bats
}

@test "runs infrastructure BATS tests with test filter (--filter)" {
    run test --filter "test_filter"
    assert_success
    assert_mock_called_once docker run -it \
        bats/bats:latest \
        -f "test_filter" \
        infra/tests/
}

@test "runs infrastructure BATS tests with test filter (-e)" {
    run test -e "test_filter"
    assert_success
    assert_mock_called_once docker run -it \
        bats/bats:latest \
        -f "test_filter" \
        infra/tests/
}

@test "initializes Terraform before running tests" {
    run test
    assert_success
    assert_mocks_called_in_order \
        terraform -chdir=infra init -backend=false -- \
        terraform -chdir=infra test
}

@test "runs Terraform tests with temporary data directory" {
    terraform() {
        log_mock_call terraform "$@"
        set_mock_state data_dir $TF_DATA_DIR
    }
    run test
    assert_success
    assert_mock_state data_dir "../.tmp/.terraform"
}

@test "returns non-zero if Terraform initialization fails" {
    terraform() { log_mock_call terraform "$@"; return 1; }
    run test
    assert_failure
    assert_output --partial "Failed to initialize Terraform."
}

@test "runs Terraform tests" {
    run test
    assert_success
    assert_mock_called_once terraform -chdir=infra test
}

@test "runs infrastructure Terraform tests" {
    run test --infra
    assert_success
    assert_mock_called_once terraform -chdir=infra test
}

@test "runs Terraform tests only" {
    run test --terraform
    assert_success
    assert_mock_not_called docker run -it --rm \
        --name folio-tests-bats \
        bats/bats:latest \
        cli/tests/
    assert_mock_not_called docker run -it --rm \
        --name folio-tests-bats \
        bats/bats:latest \
        infra/tests/
}

@test "returns non-zero if Terraform tests fail" {
    terraform() {
        log_mock_call terraform "$@";
        if [[ " $* " == *" test "* ]]; then return 1; fi
    }
    run test
    assert_failure
    assert_output --partial "Terraform tests failed."
}

@test "does not run deployment tests if unit tests fail" {
    terraform() { log_mock_call terraform "$@"; return 1; }
    run test
    assert_failure
    assert_mock_not_called deploy --test
    assert_mock_not_called destroy --test
}

@test "runs deployment tests" {
    run test
    assert_success
    assert_mock_called_once deploy --test --approve
    assert_mock_called_once destroy --test --approve
}

@test "runs deployment tests only" {
    run test --deploy
    assert_success
    assert_mock_not_called docker run -it --rm \
        --name folio-tests-bats \
        bats/bats:latest \
        cli/tests/
    assert_mock_not_called docker run -it --rm \
        --name folio-tests-bats \
        bats/bats:latest \
        infra/tests/
    assert_mock_not_called terraform -chdir=infra test
}

@test "deploys test application to domain" {
    run test --domain "example.test"
    assert_success
    assert_mock_called_once deploy --test --approve --domain "example.test"
    assert_mock_called_once destroy --test --approve --domain "example.test"
}

@test "returns non-zero if deployment fails" {
    deploy() { log_mock_call deploy "$@"; return 1; }
    run test
    assert_failure
    assert_output --partial "Failed to complete test deployment."
}

@test "returns non-zero if destroy fails" {
    destroy() { log_mock_call destroy "$@"; return 1; }
    run test
    assert_failure
    assert_output --partial "Failed to complete test deployment."
}

@test "sets commit status to 'failure' after deployment fails" {
    deploy() { log_mock_call deploy "$@"; return 1; }
    run test --set-status
    assert_failure
    assert_mock_called_once status set --self failure \
        --description "Automated tests deployment failed."
}

@test "sets commit status to 'failure' after destroy fails" {
    destroy() { log_mock_call destroy "$@"; return 1; }
    run test --set-status
    assert_failure
    assert_mock_called_once status set --self failure \
        --description "Automated tests deployment failed."
}

@test "runs BATS tests with non-interactive terminal" {
    run test --ci
    assert_success
    assert_mock_not_called docker run -it
    assert_mock_called_once deploy --test --approve --ci
    assert_mock_called_once destroy --test --approve --ci
}

@test "prints non-interactive terminal option when verbose" {
    run test --ci --verbose
    assert_success
    assert_output --partial "Running tests in non-interactive mode."
}

@test "mounts Unix project root in Docker container" {
    set_mock_state project_root "/c/code"
    run test
    assert_success
    assert_mock_called_times 2 \
        docker run -v "/c/code:/code"
}

@test "converts Unix project root to MinGW path" {
    set_mock_state os "MINGW64_NT-10.0"
    set_mock_state project_root "/c/code"
    run test
    assert_success
    assert_mock_called_once cygpath -w
}

@test "mounts MinGW project root in Docker container" {
    set_mock_state os "MINGW64_NT-10.0"
    set_mock_state windows_project_root "C:\\code"
    run test
    assert_success
    assert_mock_called_times 2 \
        docker run -v "C:\\code:/code"
}

@test "converts Unix project root to MSYS path" {
    set_mock_state os "MSYS_NT-10.0"
    set_mock_state project_root "/c/code"
    run test
    assert_success
    assert_mock_called_once cygpath -w
}

@test "mounts MSYS project root in Docker container" {
    set_mock_state os "MSYS_NT-10.0"
    set_mock_state windows_project_root "C:\\code"
    run test
    assert_success
    assert_mock_called_times 2 \
        docker run -v "C:\\code:/code"
}

@test "converts Unix project root to Cygwin path" {
    set_mock_state os "CYGWIN_NT-10.0"
    set_mock_state project_root "/c/code"
    run test
    assert_success
    assert_mock_called_once cygpath -w
}

@test "mounts Cygwin project root in Docker container" {
    set_mock_state os "CYGWIN_NT-10.0"
    set_mock_state windows_project_root "C:\\code"
    run test
    assert_success
    assert_mock_called_times 2 \
        docker run -v "C:\\code:/code"
}

@test "sets commit status to 'failure' after failing tests" {
    docker() { log_mock_call docker "$@"; return 1; }
    run test --set-status
    assert_failure
    assert_mock_called_once status set --self failure \
        --description "Automated tests failed."
}

@test "sets commit status to 'success' after passing tests" {
    run test --set-status
    assert_success
    assert_mock_called_once status set --self success \
        --description "Automated tests completed successfully."
}

@test "does not set commit status during dry run" {
    run test --set-status --dry-run
    assert_success
    assert_mock_not_called status
}

@test "does not run BATS tests during dry run" {
    run test --dry-run
    assert_success
    assert_mock_not_called docker
}

@test "does not run Terraform tests during dry run" {
    run test --infra --dry-run
    assert_success
    assert_mock_not_called terraform
}
