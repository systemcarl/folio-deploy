#!/usr/bin/env bats

TEST_DIR="$(realpath "$(dirname "$BATS_TEST_FILENAME")")"
source "$TEST_DIR/mocks"
source "$TEST_DIR/../utils/environment"
source "$TEST_DIR/../destroy"

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    setup_mocks

    mock terraform

    docker() {
        log_mock_call docker "$@"
        if [[ "$1" == "ps" ]]; then
            if [[ $(get_mock_state "container_running") != "false" ]]; then
                echo "123456789abc"
            fi
        fi
    }

    get_version() {
        log_mock_call version "$@"
        echo "1.2.3"
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
    FOLIO_ACME_EMAIL="example@example.com"
    FOLIO_SSH_KEY_ID="1234"
    FOLIO_PUBLIC_KEY_FILE="/path/to/public_key.pub"
    FOLIO_CF_TOKEN="cf_token"
    FOLIO_DO_TOKEN="do_token"
}

teardown() {
    teardown_mocks
}

@test "destroys locally" {
    run destroy --local
    assert_success
    assert_output --partial \
        "Application container stopped and removed successfully."
}

@test "loads environment" {
    run load_env
    assert_success
    assert_mock_called_once load_env
}

@test "prints environment fingerprint when verbose" {
    setup_remote_env
    run destroy <<< "y" --verbose
    assert_success
    assert_output --partial "$(fingerprint_env)"
}

@test "does not stop container if no local container" {
    set_mock_state container_running false
    run destroy --local
    assert_success
    assert_mock_not_called docker stop
}

@test "does not remove container if no local container" {
    set_mock_state container_running false
    run destroy --local
    assert_success
    assert_mock_not_called docker rm
}

@test "stops local container" {
    run destroy --local
    assert_success
    assert_mock_called_once docker stop folio
}

@test "stops container before removing" {
    run destroy --local
    assert_success
    assert_mocks_called_in_order \
        docker stop folio -- \
        docker rm folio
}

@test "removes local container" {
    run destroy --local
    assert_success
    assert_mock_called_once docker rm folio
}

@test "destroys remotely" {
    setup_remote_env
    run destroy <<< "y"
    assert_success
    assert_output --partial "Deployment destroyed successfully."
}

@test "requires domain for remote destroy" {
    setup_remote_env
    unset FOLIO_APP_DOMAIN
    run destroy <<< "y"
    assert_failure
    assert_output --partial \
        "Error: Domain required for non-local deployment."
}

@test "requires Cloudflare DNS zone for remote destroy" {
    setup_remote_env
    unset FOLIO_CF_DNS_ZONE
    run destroy <<< "y"
    assert_failure
    assert_output --partial \
        "Error: Cloudflare DNS zone required for non-local deployment."
}

@test "requires SSH port for remote destroy" {
    setup_remote_env
    unset FOLIO_SSH_PORT
    run destroy <<< "y"
    assert_failure
    assert_output --partial \
        "Error: SSH port required for non-local deployment."
}

@test "requires SSH key ID for remote destroy" {
    setup_remote_env
    unset FOLIO_SSH_KEY_ID
    run destroy <<< "y"
    assert_failure
    assert_output --partial \
        "Error: SSH key ID required for non-local deployment."
}

@test "requires public key file for remote destroy" {
    setup_remote_env
    unset FOLIO_PUBLIC_KEY_FILE
    run destroy <<< "y"
    assert_failure
    assert_output --partial \
        "Error: Public key file required for non-local deployment."
}

@test "requires GCS credentials for remote destroy" {
    setup_remote_env
    unset GOOGLE_CREDENTIALS
    run destroy <<< "y"
    assert_failure
    assert_output --partial \
        "Error: GCS credentials required for non-local deployment."
}

@test "requires Cloudflare token for remote destroy" {
    setup_remote_env
    unset FOLIO_CF_TOKEN
    run destroy <<< "y"
    assert_failure
    assert_output --partial \
        "Error: Cloudflare token required for non-local deployment."
}

@test "requires DigitalOcean token for remote destroy" {
    setup_remote_env
    unset FOLIO_DO_TOKEN
    run destroy <<< "y"
    assert_failure
    assert_output --partial \
        "Error: DigitalOcean token required for non-local deployment."
}

@test "accepts domain as option" {
    setup_remote_env
    unset FOLIO_APP_DOMAIN
    run destroy <<< "y" --domain example.test
    assert_success
    assert_output --partial "Deployment destroyed successfully."
}

@test "accepts Cloudflare DNS zone as option" {
    setup_remote_env
    unset FOLIO_CF_DNS_ZONE
    run destroy <<< "y" --dns-zone abc123
    assert_success
    assert_output --partial "Deployment destroyed successfully."
}

@test "accepts SSH port as option" {
    setup_remote_env
    unset FOLIO_SSH_PORT
    run destroy <<< "y" --ssh-port 2222
    assert_success
    assert_output --partial "Deployment destroyed successfully."
}

@test "accepts SSH key ID as option" {
    setup_remote_env
    unset FOLIO_SSH_KEY_ID
    run destroy <<< "y" --ssh-key-id 1234
    assert_success
    assert_output --partial "Deployment destroyed successfully."
}

@test "accepts public key file as option" {
    setup_remote_env
    unset FOLIO_PUBLIC_KEY_FILE
    run destroy <<< "y" --public-key /path/to/public_key.pub
    assert_success
    assert_output --partial "Deployment destroyed successfully."
}

@test "accepts GCS credentials as option" {
    setup_remote_env
    unset GOOGLE_CREDENTIALS
    run destroy <<< "y" --gcs-creds /path/to/gcs_creds.json
    assert_success
    assert_output --partial "Deployment destroyed successfully."
}

@test "accepts Cloudflare token as option" {
    setup_remote_env
    unset FOLIO_CF_TOKEN
    run destroy <<< "y" --cf-token cf_token
    assert_success
    assert_output --partial "Deployment destroyed successfully."
}

@test "accepts DigitalOcean token as option" {
    setup_remote_env
    unset FOLIO_DO_TOKEN
    run destroy <<< "y" --do-token do_token
    assert_success
    assert_output --partial "Deployment destroyed successfully."
}

@test "initializes Terraform" {
    setup_remote_env
    run destroy <<< "y"
    assert_success
    assert_mock_called_once terraform -chdir=infra init \
        -reconfigure \
        -backend-config="prefix=production"
}

@test "initializes Terraform staging environment" {
    setup_remote_env
    run destroy <<< "y" --staging
    assert_success
    assert_mock_called_once terraform -chdir=infra init \
        -reconfigure \
        -backend-config="prefix=staging"
}

@test "initializes Terraform before creating destroy plan" {
    setup_remote_env
    run destroy <<< "y"
    assert_success
    assert_mocks_called_in_order \
        terraform -chdir=infra init \
            -reconfigure -backend-config="prefix=production" -- \
        terraform -chdir=infra plan -destroy -out=tfplan
}

@test "overrides Google Cloud Service credentials" {
    setup_remote_env
    destroy <<< "y" --gcs-creds "/path/to/test_creds.json"
    assert_equal $GOOGLE_CREDENTIALS "/path/to/test_creds.json"
}

@test "creates Terraform destroy plan from environment variables" {
    setup_remote_env
    run destroy <<< "y"
    assert_success
    assert_mock_called_once terraform -chdir=infra plan -destroy \
        -out=tfplan \
        -var "environment=production" \
        -var "app_version=1.2.3" \
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

@test "creates Terraform destroy plan from options" {
    setup_remote_env
    run destroy <<< "y" \
        --environment "test" \
        --domain "example.test" \
        --dns-zone 123abc \
        --ssh-port 2222 \
        --email "test@example.com" \
        --ssh-key-id 2345 \
        --public-key /path/to/test_key.pub \
        --cf-token test_token \
        --do-token test_token
    assert_success
    assert_mock_called_once terraform -chdir=infra plan -destroy \
        -out=tfplan \
        -var "environment=test" \
        -var "app_version=1.2.3" \
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

@test "creates staging Terraform destroy plan" {
    setup_remote_env
    run destroy <<< "y" --staging
    assert_success
    assert_mock_called_once terraform -chdir=infra plan -destroy \
        -out=tfplan \
        -var "environment=staging" \
        -var "app_version=1.2.3" \
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

@test "creates Terraform plan before destroying" {
    setup_remote_env
    run destroy <<< "y"
    assert_success
    assert_mocks_called_in_order \
        terraform -chdir=infra plan -destroy -out=tfplan -- \
        terraform -chdir=infra apply tfplan
}

@test "applies Terraform destroy plan" {
    setup_remote_env
    run destroy <<< "y"
    assert_success
    assert_mock_called_once terraform -chdir=infra apply tfplan
}

@test "aborts if Terraform destroy not approved" {
    setup_remote_env
    run destroy <<< "n"
    assert_success
    assert_output --partial "Deployment aborted."
    assert_mock_not_called terraform apply
}

@test "automatically approves Terraform destroy" {
    setup_remote_env
    run destroy --approve
    assert_success
    assert_output --partial "Deployment destroyed successfully."
    assert_mock_called_once terraform -chdir=infra apply tfplan
}
