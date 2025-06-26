#!/usr/bin/env bats

TEST_DIR="$(realpath "$(dirname "$BATS_TEST_FILENAME")")"
source "$TEST_DIR/mocks"
source "$TEST_DIR/../deploy"

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    setup_mocks

    mock terraform

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

setup_remote_env() {
    export ENVIRONMENT="production"
    export FOLIO_GH_NAMESPACE="default-namespace"
    export FOLIO_GH_PACKAGE="default-package"
    export FOLIO_APP_DOMAIN="example.com"
    export FOLIO_CF_DNS_ZONE="abc123"
    export FOLIO_SSH_PORT="22"
    export FOLIO_PUBLIC_KEY_FILE="/path/to/public_key.pub"
    export FOLIO_CF_TOKEN="cf_token"
    export FOLIO_DO_TOKEN="do_token"
}

teardown() {
    teardown_mocks
}

@test "loads environment" {
    run deploy --local
    assert_success
    assert_mock_called_once load_env
}

@test "deploys locally" {
    run deploy --local
    assert_success
    assert_output --partial \
        "Application is running on http://localhost:3000"
}

@test "deploys local Docker image to local container" {
    set_mock_state has_image true
    run deploy --local
    assert_success
    assert_mock_called_once docker run -d \
        --name "folio" \
        -p "3000:3000" \
        "default-package:latest"
}

@test "deploys package override to local container" {
    set_mock_state has_image true
    run deploy --local --package "test-package"
    assert_success
    assert_mock_called_once docker run -d \
        --name "folio" \
        -p "3000:3000" \
        "test-package:latest"
}

@test "does not pull remote Docker image if local image exists" {
    set_mock_state has_image true
    run deploy --local
    assert_success
    assert_mock_not_called docker pull
}

@test "deploys remote Docker image to local container requires namespace" {
    unset FOLIO_GH_NAMESPACE
    set_mock_state has_image false
    run deploy --local
    assert_failure
    assert_output --partial \
        "Error: GitHub namespace is required to retrieve image."
}

@test "pulls remote Docker image if local image does not exist" {
    set_mock_state has_image false
    run deploy  --local
    assert_success
    assert_mock_called_once docker pull \
        "ghcr.io/default-namespace/default-package:latest"
}

@test "pulls remote Docker image from namespace override" {
    set_mock_state has_image false
    run deploy --local --namespace "test-namespace"
    assert_success
    assert_mock_called_once docker pull \
        "ghcr.io/test-namespace/default-package:latest"
}

@test "pulls remote Docker image from package override" {
    set_mock_state has_image false
    run deploy --local --package "test-package"
    assert_success
    assert_mock_called_once docker pull \
        "ghcr.io/default-namespace/test-package:latest"
}

@test "pulls remote Docker image before deploying" {
    set_mock_state has_image false
    run deploy  --local
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
    run deploy  --local
    assert_success
    assert_mock_called_once docker run -d \
        --name "folio" \
        -p "3000:3000" \
        "ghcr.io/default-namespace/default-package:latest"
}

@test "deploys remote Docker image to local container with namespace override" {
    set_mock_state has_image false
    run deploy --local --namespace "test-namespace"
    assert_success
    assert_mock_called_once docker run -d \
        --name "folio" \
        -p "3000:3000" \
        "ghcr.io/test-namespace/default-package:latest"
}

@test "deploys remote Docker image to local container with package override" {
    set_mock_state has_image false
    run deploy --local --package "test-package"
    assert_success
    assert_mock_called_once docker run -d \
        --name "folio" \
        -p "3000:3000" \
        "ghcr.io/default-namespace/test-package:latest"
}

@test "deploys remotely" {
    setup_remote_env
    run deploy <<< "y"
    assert_success
    assert_output --partial "Deployment of production completed successfully."
}

@test "requires namespace to deploy remotely" {
    setup_remote_env
    unset FOLIO_GH_NAMESPACE
    run deploy <<< "y"
    assert_failure
    assert_output --partial \
        "Error: GitHub namespace required for non-local deployment."
}

@test "requires domain to deploy remotely" {
    setup_remote_env
    unset FOLIO_APP_DOMAIN
    run deploy <<< "y"
    assert_failure
    assert_output --partial \
        "Error: Domain required for non-local deployment."
}

@test "requires Cloudflare DNS zone to deploy remotely" {
    setup_remote_env
    unset FOLIO_CF_DNS_ZONE
    run deploy <<< "y"
    assert_failure
    assert_output --partial \
        "Error: Cloudflare DNS zone required for non-local deployment."
}

@test "requires public key file to deploy remotely" {
    setup_remote_env
    unset FOLIO_PUBLIC_KEY_FILE
    run deploy <<< "y"
    assert_failure
    assert_output --partial \
        "Error: Public key file required for non-local deployment."
}

@test "requires Cloudflare API token to deploy remotely" {
    setup_remote_env
    unset FOLIO_CF_TOKEN
    run deploy <<< "y"
    assert_failure
    assert_output --partial \
        "Error: Cloudflare token required for non-local deployment."
}

@test "requires DigitalOcean API token to deploy remotely" {
    setup_remote_env
    unset FOLIO_DO_TOKEN
    run deploy <<< "y"
    assert_failure
    assert_output --partial \
        "Error: DigitalOcean token required for non-local deployment."
}

@test "accepts namespace as option" {
    setup_remote_env
    unset FOLIO_GH_NAMESPACE
    run deploy <<< "y" --namespace "test-namespace"
    assert_success
    assert_output --partial "Deployment of production completed successfully."
}

@test "accepts domain as option" {
    setup_remote_env
    unset FOLIO_APP_DOMAIN
    run deploy <<< "y" --domain "example.com"
    assert_success
    assert_output --partial "Deployment of production completed successfully."
}

@test "accepts Cloudflare DNS zone as option" {
    setup_remote_env
    unset FOLIO_CF_DNS_ZONE
    run deploy <<< "y" --dns-zone "example.com"
    assert_success
    assert_output --partial "Deployment of production completed successfully."
}

@test "accepts public key file as option" {
    setup_remote_env
    unset FOLIO_PUBLIC_KEY_FILE
    run deploy <<< "y" --public-key "/path/to/public_key.pub"
    assert_success
    assert_output --partial "Deployment of production completed successfully."
}

@test "accepts Cloudflare API token as option" {
    setup_remote_env
    unset FOLIO_CF_TOKEN
    run deploy <<< "y" --cf-token "cf_token"
    assert_success
    assert_output --partial "Deployment of production completed successfully."
}

@test "accepts DigitalOcean API token as option" {
    setup_remote_env
    unset FOLIO_DO_TOKEN
    run deploy <<< "y" --do-token "do_token"
    assert_success
    assert_output --partial "Deployment of production completed successfully."
}

@test "initializes Terraform" {
    setup_remote_env
    run deploy <<< "y"
    assert_success
    assert_mock_called_once terraform init
}

@test "initializes Terraform before creating plan" {
    setup_remote_env
    run deploy <<< "y"
    assert_success
    assert_mocks_called_in_order \
        terraform init -- \
        terraform plan -out=tfplan
}

@test "creates Terraform plan from environment variables" {
    setup_remote_env
    run deploy <<< "y"
    assert_success
    assert_mock_called_once terraform plan \
        -out=tfplan \
        -var "namespace=default-namespace" \
        -var "domain=example.com" \
        -var "dns_zone=abc123" \
        -var "ssh_port=22" \
        -var "ssh_public_key_file=/path/to/public_key.pub" \
        -var "cf_token=cf_token" \
        -var "do_token=do_token"
}

@test "creates Terraform plan from options" {
    run deploy <<< "y" \
        --namespace "test-namespace" \
        --domain "example.com" \
        --dns-zone "abc123" \
        --ssh-port "2222" \
        --public-key "/path/to/public_key.pub" \
        --cf-token "cf_token" \
        --do-token "do_token"
    assert_success
    assert_mock_called_once terraform plan \
        -out=tfplan \
        -var "namespace=test-namespace" \
        -var "domain=example.com" \
        -var "dns_zone=abc123" \
        -var "ssh_port=2222" \
        -var "ssh_public_key_file=/path/to/public_key.pub" \
        -var "cf_token=cf_token" \
        -var "do_token=do_token"
}

@test "creates Terraform plan before applying" {
    setup_remote_env
    run deploy <<< "y"
    assert_success
    assert_mocks_called_in_order \
        terraform plan -out=tfplan -- \
        terraform apply tfplan
}

@test "applies Terraform plan" {
    setup_remote_env
    run deploy <<< "y"
    assert_success
    assert_mock_called_once terraform apply tfplan
}

@test "aborts if plan not approved" {
    setup_remote_env
    run deploy <<< "n"
    assert_success
    assert_output --partial "Deployment aborted."
    assert_mock_not_called terraform apply
}

@test "automatically approves plan" {
    setup_remote_env
    run deploy --approve
    assert_success
    assert_mock_called_once terraform apply tfplan
}
