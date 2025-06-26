mock_provider "cloudflare" {}
mock_provider "digitalocean" {}

override_resource {
    target = digitalocean_droplet.app
    values = { id = 12345678 }
}
override_resource {
    target = digitalocean_reserved_ip.app_ip
    values = { ip_address = "134.199.178.76" }
}

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

run "assigns_reserved_ip_to_droplet_id" {
    assert {
        condition = (
            tostring(digitalocean_reserved_ip_assignment.assign_ip.droplet_id)
                == tostring(digitalocean_droplet.app.id)
        )
        error_message = "Reserved IP not assigned to the correct droplet."
    }
}

run "assigns_reserved_ip_to_correct_ip_address" {
    assert {
        condition = (
            digitalocean_reserved_ip_assignment.assign_ip.ip_address
                == digitalocean_reserved_ip.app_ip.ip_address
        )
        error_message = "Reserved IP not assigned to the correct IP address."
    }
}

run "creates_dns_a_record" {
    command = plan

    assert {
        condition = cloudflare_dns_record.a.type == "A"
        error_message = "DNS record type not as expected."
    }
}

run "creates_dns_a_record_with_correct_zone_id" {
    command = plan

    assert {
        condition = cloudflare_dns_record.a.zone_id == "abc123"
        error_message = "DNS record zone ID not as expected."
    }
}

run "creates_dns_a_record_with_domain" {
    command = plan

    assert {
        condition = cloudflare_dns_record.a.name == "app.example.com"
        error_message = "DNS record name not as expected."
    }
}

run "creates_dns_a_record_with_correct_ip" {
    command = plan

    assert {
        condition = (cloudflare_dns_record.a.content
            == digitalocean_reserved_ip.app_ip.ip_address)
        error_message = "DNS record IP address not as expected."
    }
}

run "creates_dns_a_record_with_correct_comment" {
    command = plan

    assert {
        condition = (cloudflare_dns_record.a.comment
            == "Personal website and portfolio.")
        error_message = "DNS record comment not as expected."
    }
}

run "creates_proxied_dns_a_record" {
    command = plan

    assert {
        condition = cloudflare_dns_record.a.proxied == true
        error_message = "DNS record not set to proxied."
    }
}

run "creates_dns_a_record_with_correct_ttl" {
    command = plan

    assert {
        condition = cloudflare_dns_record.a.ttl == 1
        error_message = "DNS record TTL not as expected."
    }
}
