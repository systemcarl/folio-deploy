terraform {
    required_version = "~> 1.12.2"
    backend "gcs" {
        bucket = "folio-terraform"
    }
    required_providers {
        cloudflare = {
            source  = "cloudflare/cloudflare"
            version = "~> 5"
        }
        digitalocean = {
            source = "digitalocean/digitalocean"
            version = "~> 2.55"
        }
    }
}

provider "cloudflare" {
    api_token = var.cf_token
}

provider "digitalocean" {
    token = var.do_token
}

locals {
    app_version = (
        var.app_version != ""
            ? var.app_version
            : jsondecode(file("${path.module}/../folio/package.json")).version
    )
}

resource "digitalocean_droplet" "app" {
    name = "app"
    image = "debian-12-x64"
    region = "tor1"
    size = "s-1vcpu-1gb"
    ssh_keys = [var.ssh_key_id]
    user_data = templatefile(
        "${path.module}/cloud-init.tftpl",
        {
            environment = var.environment,
            ssh_port = var.ssh_port,
            ssh_public_key = file(var.ssh_public_key_file),
            hostname = var.domain,
            app_package = join("", [
                "ghcr.io/${var.namespace}/",
                "${var.app_package}:${local.app_version}"
            ]),
            acme_email = var.acme_email
        }
    )
    tags = ["${var.app_package}", "${var.environment}"]
}

resource "digitalocean_reserved_ip" "app_ip" {
    region = "tor1"
}

resource "digitalocean_reserved_ip_assignment" "assign_ip" {
    droplet_id = digitalocean_droplet.app.id
    ip_address = digitalocean_reserved_ip.app_ip.ip_address
}

resource "cloudflare_dns_record" "a" {
    zone_id = var.dns_zone
    name = var.domain
    type = "A"
    comment = "Personal website and portfolio."
    content = digitalocean_reserved_ip.app_ip.ip_address
    proxied = true
    ttl = 1
}
