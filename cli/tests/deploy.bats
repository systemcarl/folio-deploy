#!/usr/bin/env bats

TEST_DIR="$(realpath "$(dirname "$BATS_TEST_FILENAME")")"
source "$TEST_DIR/mocks"
source "$TEST_DIR/../utils/environment"
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

    mock containerize
    mock smoke

    status() { log_mock_call status "$@"; echo "none"; }

    get_version() {
        log_mock_call version "$@"
        echo "1.2.3"
    }

    mock load_env

    FOLIO_APP_ACCOUNT="app-account"
    FOLIO_APP_REPO="app-repo"
    FOLIO_CICD_REPO="cicd-repo"
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
    FOLIO_GH_TOKEN="gh_token"
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

@test "prints environment fingerprint when verbose" {
    setup_remote_env
    run deploy <<< "y" --verbose
    assert_success
    assert_output --partial "$(fingerprint_env)"
}

@test "prints auto-approve when verbose" {
    setup_remote_env
    run deploy --verbose --approve
    assert_success
    assert_output --partial "Auto-approve enabled."
}

@test "prints status updates enabled when verbose" {
    setup_remote_env
    run deploy <<< "y" --verbose --set-status
    assert_success
    assert_output --partial "Status updates enabled."
}

@test "prints status updates disabled when verbose" {
    setup_remote_env
    run deploy <<< "y" --verbose
    assert_success
    assert_output --partial "Status updates disabled."
}

@test "prints force status updates enabled when verbose" {
    setup_remote_env
    run deploy <<< "y" --verbose --set-status --force
    assert_success
    assert_output --partial "Force status updates enabled."
}

@test "refuses to set status of local deployment" {
    run deploy --local --set-status
    assert_failure
    assert_output --partial \
        "Error: Cannot set status for local deployments."
    assert_mock_not_called status
}

@test "containerizes application locally" {
    run deploy --local
    assert_success
    assert_mock_called_once containerize
    assert_mock_not_called containerize --push
}

@test "returns non-zero exit code if local containerization fails" {
    containerize() { log_mock_call containerize "$@"; return 1; }
    run deploy --local
    assert_failure
}

@test "containerizes application before deploying" {
    run deploy --local
    assert_success
    assert_mocks_called_in_order \
        containerize -- \
        docker run -d \
            --name "folio" \
            -p "3000:3000" \
            "app-repo:1.2.3"
}

@test "deploys local Docker image to local container" {
    set_mock_state has_image true
    run deploy --local
    assert_success
    assert_mock_called_once docker run -d \
        --name "folio" \
        -p "3000:3000" \
        "app-repo:1.2.3"
}

@test "deploys local package" {
    FOLIO_APP_REPO="test-package"
    set_mock_state has_image true
    run deploy --local
    assert_success
    assert_mock_called_once docker run -d \
        "test-package:1.2.3"
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
        "ghcr.io/app-account/app-repo:1.2.3"
}

@test "pulls remote Docker image from namespace" {
    FOLIO_APP_ACCOUNT="test-account"
    set_mock_state has_image false
    run deploy --local
    assert_success
    assert_mock_called_once docker pull \
        "ghcr.io/test-account/app-repo:1.2.3"
}

@test "pulls remote package" {
    FOLIO_APP_REPO="test-package"
    set_mock_state has_image false
    run deploy --local
    assert_success
    assert_mock_called_once docker pull \
        "ghcr.io/app-account/test-package:1.2.3"
}

@test "pulls remote Docker image before deploying" {
    set_mock_state has_image false
    run deploy --local
    assert_success
    assert_mocks_called_in_order \
        docker pull "ghcr.io/app-account/app-repo:1.2.3" -- \
        docker run -d \
            --name "folio" \
            -p "3000:3000" \
            "ghcr.io/app-account/app-repo:1.2.3"
}

@test "deploys remote Docker image to local container" {
    set_mock_state has_image false
    run deploy --local
    assert_success
    assert_mock_called_once docker run -d \
        --name "folio" \
        -p "3000:3000" \
        "ghcr.io/app-account/app-repo:1.2.3"
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
        "ghcr.io/test-account/test-package:1.2.3"
}

@test "smoke tests local deployment" {
    run deploy --local
    assert_success
    assert_mock_called_once smoke --insecure --domain "localhost:3000"
}

@test "smoke tests local deployment with non-interactive output" {
    run deploy --local --ci
    assert_success
    assert_mock_called_once smoke --insecure --domain "localhost:3000" --ci
}

@test "return non-zero exit code if smoke test fails" {
    smoke() { log_mock_call smoke $@; return 1; }
    run deploy --local
    assert_failure
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

@test "does not require GitHub API token" {
    setup_remote_env
    unset FOLIO_GH_TOKEN
    run deploy <<< "y"
    assert_success
    assert_output --partial "Deployment of production completed successfully."
}

@test "requires GitHub API token to update commit status" {
    setup_remote_env
    unset FOLIO_GH_TOKEN
    run deploy <<< "y" --set-status
    assert_failure
    assert_output --partial \
        "Error: GitHub token required to set deployment commit status."
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

@test "accepts GitHub API token as option" {
    setup_remote_env
    unset FOLIO_GH_TOKEN
    run deploy <<< "y" --gh-token "gh_token"
    assert_success
    assert_output --partial "Deployment of production completed successfully."
}

@test "does not set commit status" {
    setup_remote_env
    run deploy <<< "y"
    assert_success
    assert_mock_not_called status
}

@test "refuses to deploy if commit status already set" {
    setup_remote_env
    status() { log_mock_call status "$@"; echo "pending"; }
    run deploy <<< "y" --set-status
    assert_failure
    assert_output --partial \
        "Deployment already in progress."
    assert_mock_not_called status set
}

@test "forces deployment (--force) if commit status already set" {
    setup_remote_env
    status() { log_mock_call status "$@"; echo "pending"; }
    run deploy <<< "y" --set-status --force
    assert_success
    assert_mock_called_once status set --self pending
}

@test "forces deployment (-f) if commit status already set" {
    setup_remote_env
    status() { log_mock_call status "$@"; echo "pending"; }
    run deploy <<< "y" --set-status -f
    assert_success
    assert_mock_called_once status set --self pending
}

@test "sets commit status to 'pending'" {
    setup_remote_env
    run deploy <<< "y" --set-status
    assert_success
    assert_mock_called_once status set --self pending \
        --context "cd/cicd-repo" \
        --description "Deployment of production to example.com started."
}

@test "sets commit status to 'pending' before containerizing application" {
    setup_remote_env
    run deploy <<< "y" --set-status
    assert_success
    assert_mocks_called_in_order \
        status set --self pending \
            --context "cd/cicd-repo" \
            --description "Deployment of production to example.com started." \
                -- \
        containerize --push
}

@test "containerizes and publishes application" {
    setup_remote_env
    run deploy <<< "y"
    assert_success
    assert_mock_called_once containerize --push
}

@test "authenticates containerization with environment GitHub Packages token" {
    setup_remote_env
    FOLIO_GHPR_TOKEN="ghpr_token"
    run deploy <<< "y"
    assert_success
    assert_mock_called_once containerize --push --ghpr-token "ghpr_token"
}

@test "authenticates containerization with GitHub Packages token option" {
    setup_remote_env
    run deploy <<< "y" --ghpr-token "ghpr_token"
    assert_success
    assert_mock_called_once containerize --push --ghpr-token "ghpr_token"
}

@test "returns non-zero exit code if containerization fails" {
    setup_remote_env
    containerize() { log_mock_call containerize "$@"; return 1; }
    run deploy <<< "y"
    assert_failure
}

@test "sets commit status to 'failure' after failing to containerize app" {
    setup_remote_env
    containerize() { log_mock_call containerize "$@"; return 1; }
    run deploy <<< "y" --set-status
    assert_failure
    assert_mock_called_once status set --self failure \
        --context "cd/cicd-repo" \
        --description "Deployment of production to example.com failed to \
            build and push image."
}

@test "containerizes application before applying Terraform plan" {
    setup_remote_env
    run deploy <<< "y"
    assert_success
    assert_mocks_called_in_order \
        containerize --push -- \
        terraform -chdir=infra apply tfplan
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

@test "sets commit status to 'failure' after failing to initialize Terraform" {
    setup_remote_env
    terraform() { log_mock_call terraform "$@"; return 1; }
    run deploy <<< "y" --set-status
    assert_failure
    assert_mock_called_once status set --self failure \
        --context "cd/cicd-repo" \
        --description "Deployment of production to example.com failed to \
            initialize environment."
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

@test "creates Terraform plan from options" {
    setup_remote_env
    run deploy <<< "y" \
        --environment "test" \
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

@test "creates staging Terraform plan" {
    setup_remote_env
    run deploy <<< "y" --staging
    assert_success
    assert_mock_called_once terraform -chdir=infra plan \
        -out=tfplan \
        -var "environment=staging" \
        -var "app_version=1.2.3" \
        -var "namespace=app-account" \
        -var "domain=example.com" \
        -var "dns_zone=abc123" \
        -var "ssh_port=22" \
        -var "acme_email=example@example.com" \
        -var "ssh_public_key_file=/path/to/public_key.pub" \
        -var "cf_token=cf_token" \
        -var "do_token=do_token"
}

@test "sets commit status to 'failure' after failing to create Terraform plan" {
    setup_remote_env
    terraform() {
        log_mock_call terraform "$@";
        if [[ " $* " == *" plan "* ]]; then return 1; fi
    }
    run deploy <<< "y" --set-status
    assert_failure
    assert_mock_called_once status set --self failure \
        --context "cd/cicd-repo" \
        --description "Deployment of production to example.com failed to \
            resolve required resources."
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

@test "sets commit status to 'pending' after plan aborted" {
    setup_remote_env
    run deploy <<< "n" --set-status
    assert_success
    assert_mock_called_once status set --self pending \
        --context "cd/cicd-repo" \
        --description "Deployment of production to example.com aborted by user."
}

@test "sets commit status to 'failure' after failing to apply Terraform plan" {
    setup_remote_env
    terraform() {
        log_mock_call terraform "$@";
        if [[ " $* " == *" apply "* ]]; then return 1; fi
    }
    run deploy <<< "y" --set-status
    assert_failure
    assert_mock_called_once status set --self failure \
        --context "cd/cicd-repo" \
        --description "Deployment of production to example.com failed to \
            provision resources."
}

@test "smoke tests remote deployment" {
    setup_remote_env
    run deploy <<< "y"
    assert_success
    assert_mock_called_once smoke --domain example.com
}

@test "smoke tests remote deployment with non-interactive output" {
    setup_remote_env
    run deploy <<< "y" --ci
    assert_success
    assert_mock_called_once smoke --domain example.com --ci
}

@test "returns non-zero exit code if smoke test fails" {
    setup_remote_env
    smoke() { log_mock_call smoke $@; return 1; }
    run deploy <<< "y"
    assert_failure
}

@test "sets commit status to 'failure' after failed smoke test" {
    setup_remote_env
    smoke() { log_mock_call smoke $@; return 1; }
    run deploy <<< "y" --set-status
    assert_failure
    assert_mock_called_once status set --self failure \
        --context "cd/cicd-repo" \
        --description "Deployment of production to example.com failed smoke \
            test."
}

@test "sets commit status to 'success' after successful deployment" {
    setup_remote_env
    run deploy <<< "y" --set-status
    assert_success
    assert_mock_called_once status set --self success \
        --context "cd/cicd-repo" \
        --description "Deployment of production to example.com deployed \
            successfully."
}

@test "does not set commit status during dry run" {
    setup_remote_env
    run deploy <<< "y" --set-status --dry-run
    assert_success
    assert_mock_not_called status
}

@test "does not deploy locally during dry run" {
    run deploy <<< "y" --local --dry-run
    assert_success
    assert_mock_not_called docker
}

@test "does not deploy remotely during dry run" {
    setup_remote_env
    run deploy <<< "y" --dry-run
    assert_success
    assert_mock_not_called terraform
}
