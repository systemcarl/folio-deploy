variables {
    namespace = "app-account"
    app_package = "app-package"
    app_version = "1.2.3"
    domain = "app.example.com"
    dns_zone = "abc123"
    ssh_key_id = 1234
    ssh_public_key_file = "tests/.pub"
    cf_token = "abcde12345abcde12345abcde12345abcde12345"
    do_token = "12345abcde12345abcde12345abcde12345abcde"
}

run "does_not_require_optional_variables" {
    command = plan
}

run "requires_environment" {
    command = plan
    variables { environment = "" }
    expect_failures = [var.environment]
}

run "requires_namespace" {
    command = plan
    variables { namespace = "" }
    expect_failures = [var.namespace]
}

run "requires_app_package" {
    command = plan
    variables { app_package = "" }
    expect_failures = [var.app_package]
}

run "requires_domain" {
    command = plan
    variables { domain = "" }
    expect_failures = [var.domain]
}

run "requires_dns_zone" {
    command = plan
    variables { dns_zone = "" }
    expect_failures = [var.dns_zone]
}

run "requires_positive_ssh_port" {
    command = plan
    variables { ssh_port = -1 }
    expect_failures = [var.ssh_port]
}

run "requires_valid_ssh_port" {
    command = plan
    variables { ssh_port = 70000 }
    expect_failures = [var.ssh_port]
}

run "requires_positive_ssh_key_id" {
    command = plan
    variables { ssh_key_id = 0 }
    expect_failures = [var.ssh_key_id]
}

run "requires_ssh_public_key_file" {
    command = plan
    variables { ssh_public_key_file = "" }
    expect_failures = [var.ssh_public_key_file]
}

run "requires_existing_ssh_public_key_file" {
    command = plan
    variables { ssh_public_key_file = "nonexistent.pub" }
    expect_failures = [var.ssh_public_key_file]
}

run "requires_valid_ssh_public_key_file" {
    command = plan
    variables { ssh_public_key_file = "tests/bad.pub" }
    expect_failures = [var.ssh_public_key_file]
}

run "requires_cf_token" {
    command = plan
    variables { cf_token = "" }
    expect_failures = [var.cf_token]
}

run "requires_do_token" {
    command = plan
    variables { do_token = "" }
    expect_failures = [var.do_token]
}

run "requires_valid_acme_email" {
    command = plan
    variables { acme_email = "invalid-email" }
    expect_failures = [var.acme_email]
}
