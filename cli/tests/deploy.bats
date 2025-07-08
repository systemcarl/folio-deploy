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

    mock load_env

    FOLIO_APP_ACCOUNT="app-account"
    FOLIO_APP_REPO="app-repo"
}

setup_remote_env() {
    ENVIRONMENT="production"
    GOOGLE_CREDENTIALS="/path/to/gcs_creds.json"
    FOLIO_APP_DOMAIN="example.com"
    FOLIO_CF_DNS_ZONE="abc123"
    FOLIO_SSH_PORT="22"
    FOLIO_SSH_KEY_ID="1234"
    FOLIO_ACME_EMAIL="example@example.com"
    FOLIO_PUBLIC_KEY_FILE="/path/to/public_key.pub"
    FOLIO_CF_TOKEN="cf_token"
    FOLIO_DO_TOKEN="do_token"
}

teardown() {
    teardown_mocks
}

@test "deploys locally" {
    run deploy --local
    assert_success
    assert_output --partial \
        "Application is running on http://localhost:3000"
}

@test "loads environment" {
    run deploy --local
    assert_success
    assert_mock_called_once load_env
}

@test "deploys local Docker image to local container" {
    set_mock_state has_image true
    run deploy --local
    assert_success
    assert_mock_called_once docker run -d \
        --name "folio" \
        -p "3000:3000" \
        "app-repo:latest"
}

@test "deploys local package" {
    FOLIO_APP_REPO="test-package"
    set_mock_state has_image true
    run deploy --local
    assert_success
    assert_mock_called_once docker run -d \
        "test-package:latest"
}

@test "does not pull remote Docker image if local image exists" {
    set_mock_state has_image true
    run deploy --local
    assert_success
    assert_mock_not_called docker pull
}

@test "pulls remote Docker image if local image does not exist" {
    set_mock_state has_image false
    run deploy --local
    assert_success
    assert_mock_called_once docker pull \
        "ghcr.io/app-account/app-repo:latest"
}

@test "pulls remote Docker image from namespace" {
    FOLIO_APP_ACCOUNT="test-account"
    set_mock_state has_image false
    run deploy --local
    assert_success
    assert_mock_called_once docker pull \
        "ghcr.io/test-account/app-repo:latest"
}

@test "pulls remote package" {
    FOLIO_APP_REPO="test-package"
    set_mock_state has_image false
    run deploy --local
    assert_success
    assert_mock_called_once docker pull \
        "ghcr.io/app-account/test-package:latest"
}

@test "pulls remote Docker image before deploying" {
    set_mock_state has_image false
    run deploy --local
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
    run deploy --local
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
    run deploy --local
    assert_success
    assert_mock_called_once docker run -d \
        --name "folio" \
        -p "3000:3000" \
        "ghcr.io/test-account/test-package:latest"
}

@test "deploys remotely" {
    setup_remote_env
    run deploy <<< "y"
    assert_success
    assert_output --partial "Deployment of production completed successfully."
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

@test "requires SSH port to deploy remotely" {
    setup_remote_env
    unset FOLIO_SSH_PORT
    run deploy <<< "y"
    assert_failure
    assert_output --partial \
        "Error: SSH port required for non-local deployment."
}

@test "requires SSH key ID to deploy remotely" {
    setup_remote_env
    unset FOLIO_SSH_KEY_ID
    run deploy <<< "y"
    assert_failure
    assert_output --partial \
        "Error: SSH key ID required for non-local deployment."
}

@test "requires public key file to deploy remotely" {
    setup_remote_env
    unset FOLIO_PUBLIC_KEY_FILE
    run deploy <<< "y"
    assert_failure
    assert_output --partial \
        "Error: Public key file required for non-local deployment."
}

@test "requires Google Cloud Service credentials to deploy remotely" {
    setup_remote_env
    unset GOOGLE_CREDENTIALS
    run deploy <<< "y"
    assert_failure
    assert_output --partial \
        "Error: GCS credentials required for non-local deployment."
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

@test "accepts SSH port as option" {
    setup_remote_env
    unset FOLIO_SSH_PORT
    run deploy <<< "y" --ssh-port "2222"
    assert_success
    assert_output --partial "Deployment of production completed successfully."
}

@test "accepts SSH key ID as option" {
    setup_remote_env
    unset FOLIO_SSH_KEY_ID
    run deploy <<< "y" --ssh-key-id "1234"
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

@test "accepts Google Cloud Service credentials as option" {
    setup_remote_env
    unset GOOGLE_CREDENTIALS
    run deploy <<< "y" --gcs-creds "/path/to/gcs_creds.json"
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
    assert_mock_called_once terraform -chdir=infra init \
        -reconfigure \
        -backend-config="prefix=production"
}

@test "initializes Terraform staging environment" {
    setup_remote_env
    run deploy <<< "y" --staging
    assert_success
    assert_mock_called_once terraform init
    assert_mock_called_once terraform -chdir=infra init \
        -reconfigure \
        -backend-config="prefix=staging"
}

@test "initializes Terraform before creating plan" {
    setup_remote_env
    run deploy <<< "y"
    assert_success
    assert_mocks_called_in_order \
        terraform -chdir=infra init \
            -reconfigure -backend-config="prefix=production" -- \
        terraform -chdir=infra plan -out=tfplan
}

@test "overrides Google Cloud Service credentials" {
    setup_remote_env
    deploy <<< "y" --gcs-creds "/path/to/test_creds.json"
    assert_equal $GOOGLE_CREDENTIALS "/path/to/test_creds.json"
}

@test "creates Terraform plan from environment variables" {
    setup_remote_env
    run deploy <<< "y"
    assert_success
    assert_mock_called_once terraform -chdir=infra plan \
        -out=tfplan \
        -var "environment=production" \
        -var "namespace=app-account" \
        -var "domain=example.com" \
        -var "dns_zone=abc123" \
        -var "ssh_port=22" \
        -var "acme_email=example@example.com" \
        -var "ssh_key_id=1234" \
        -var "ssh_public_key_file=/path/to/public_key.pub" \
        -var "cf_token=cf_token" \
        -var "do_token=do_token"
}

@test "creates Terraform plan from options" {
    setup_remote_env
    run deploy <<< "y" \
        --domain "example.test" \
        --dns-zone "123abc" \
        --ssh-port "2222" \
        --ssh-key-id "2345" \
        --email "test@example.com" \
        --public-key "/path/to/test_key.pub" \
        --cf-token "test_token" \
        --do-token "test_token"
    assert_success
    assert_mock_called_once terraform -chdir=infra plan \
        -out=tfplan \
        -var "environment=production" \
        -var "namespace=app-account" \
        -var "domain=example.test" \
        -var "dns_zone=123abc" \
        -var "ssh_port=2222" \
        -var "acme_email=test@example.com" \
        -var "ssh_key_id=2345" \
        -var "ssh_public_key_file=/path/to/test_key.pub" \
        -var "cf_token=test_token" \
        -var "do_token=test_token"
}

@test "creates staging Terraform plan" {
    setup_remote_env
    run deploy <<< "y" --staging
    assert_success
    assert_mock_called_once terraform -chdir=infra plan \
        -out=tfplan \
        -var "environment=staging" \
        -var "namespace=app-account" \
        -var "domain=example.com" \
        -var "dns_zone=abc123" \
        -var "ssh_port=22" \
        -var "acme_email=example@example.com" \
        -var "ssh_public_key_file=/path/to/public_key.pub" \
        -var "cf_token=cf_token" \
        -var "do_token=do_token"
}

@test "creates Terraform plan before applying" {
    setup_remote_env
    run deploy <<< "y"
    assert_success
    assert_mocks_called_in_order \
        terraform -chdir=infra plan -out=tfplan -- \
        terraform -chdir=infra apply tfplan
}

@test "applies Terraform plan" {
    setup_remote_env
    run deploy <<< "y"
    assert_success
    assert_mock_called_once terraform -chdir=infra apply tfplan
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
    assert_mock_called_once terraform -chdir=infra apply tfplan
}
