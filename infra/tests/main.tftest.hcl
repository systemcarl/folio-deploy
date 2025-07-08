variables {
    environment = "test"
    namespace = "app-account"
    app_package = "app-package"
    app_version = "1.2.3"
    domain = "app.example.com"
    dns_zone = "abc123"
    ssh_port = 2222
    ssh_key_id = 1234
    ssh_public_key_file = "tests/.pub"
    cf_token = "abcde12345abcde12345abcde12345abcde12345"
    do_token = "12345abcde12345abcde12345abcde12345abcde"
}

run "creates_droplet_with_name_app" {
    command = plan
    assert {
        condition = digitalocean_droplet.app.name == "app"
        error_message = "Droplet name not as expected."
    }
}

run "creates_droplet_using_correct_image" {
    command = plan
    assert {
        condition = digitalocean_droplet.app.image == "debian-12-x64"
        error_message = "Droplet image not as expected."
    }
}

run "creates_droplet_in_correct_region" {
    command = plan
    assert {
        condition = digitalocean_droplet.app.region == "tor1"
        error_message = "Droplet region not as expected."
    }
}

run "creates_droplet_with_correct_size" {
    command = plan
    assert {
        condition = digitalocean_droplet.app.size == "s-1vcpu-1gb"
        error_message = "Droplet size not as expected."
    }
}

run "creates_droplet_with_correct_ssk_key_id" {
    command = plan
    assert {
        condition = contains(digitalocean_droplet.app.ssh_keys, "1234")
        error_message = "Droplet SSH key ID not as expected."
    }
}

run "creates_droplet_with_correct_user_data" {
    command = plan

    assert {
        condition = digitalocean_droplet.app.user_data == sha1(
            templatefile(
                "${path.module}/cloud-init.tftpl",
                {
                    environment = "test",
                    ssh_port = 2222,
                    ssh_public_key = file("tests/.pub"),
                    hostname = "app.example.com",
                    app_package = "ghcr.io/app-account/app-package:1.2.3",
                    acme_email = ""
                }
            )
        )
        error_message = "Droplet user data not as expected."
    }
}

run "creates_droplet_with_correct_tags" {
    command = plan
    assert {
        condition = contains(digitalocean_droplet.app.tags, "app-package")
        error_message = "Droplet tags do not include application package name."
    }
    assert {
        condition = contains(digitalocean_droplet.app.tags, "test")
        error_message = "Droplet tags do not include environment."
    }
}

run "creates_reserved_ip_in_correct_region" {
    command = plan
    assert {
        condition = digitalocean_reserved_ip.app_ip.region == "tor1"
        error_message = "Reserved IP region not as expected."
    }
}
