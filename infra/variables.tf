variable "environment" {
    description = "The environment type for the deployment."
    type = string
    default = "production"
    validation {
        condition = length(trimspace(var.environment)) > 0
        error_message = "The environment variable must not be empty."
    }
}

variable "namespace" {
    description = "The namespace for the application."
    type = string
    default = ""
    validation {
        condition = length(trimspace(var.namespace)) > 0
        error_message = "The environment variable must not be empty."
    }
}
variable "app_package" {
    description = "The application package to install on the app server."
    type = string
    default = "folio"
    validation {
        condition = length(trimspace(var.app_package)) > 0
        error_message = "The environment variable must not be empty."
    }
}
variable "app_version" {
    description = "The version of the application package to install."
    type = string
    default = ""
}

variable "domain" {
    description = "The application domain name."
    type = string
    default = ""
    validation {
        condition = length(trimspace(var.domain)) > 0
        error_message = "The environment variable must not be empty."
    }
}
variable "dns_zone" {
    description = "The Cloudflare zone ID for the application domain."
    type = string
    default = ""
    validation {
        condition = length(trimspace(var.dns_zone)) > 0
        error_message = "The environment variable must not be empty."
    }
}

variable "ssh_port" {
    description = "The SSH port to use for the application server."
    type = number
    default = 22
    validation {
        condition = var.ssh_port >= 1 && var.ssh_port <= 65535
        error_message = "The SSH port must be a valid port number (1-65535)."
    }
}
variable "ssh_key_id" {
    description = "The DigitalOcean SSH key ID to use for server for config."
    type = number
    default = 0
    validation {
        condition = var.ssh_key_id > 0
        error_message = "The SSH key ID must be a positive number."
    }
}
variable "ssh_public_key_file" {
    description = "The path to the SSH public key file for server connection."
    type = string
    default = ""
    validation {
        condition = length(trimspace(var.ssh_public_key_file)) > 0
        error_message = "The SSH public key file path must not be empty."
    }
    validation {
        condition = (length(trimspace(var.ssh_public_key_file)) > 0
            && fileexists(var.ssh_public_key_file))
        error_message = "The SSH public key file does not exist."
    }
    validation {
        condition = can(regex(
            "^ssh-(rsa|ed25519)\\s[\\w0-9+/=]+",
            trimspace(file(var.ssh_public_key_file))
        ))
        error_message = "The file does not appear to be a valid SSH public key."
    }
}

variable "cf_token" {
    description = "Cloudflare API token for managing DNS records."
    type = string
    default = ""
    validation {
        condition = length(trimspace(var.cf_token)) > 0
        error_message = "The environment variable must not be empty."
    }
}
variable "do_token" {
    description = "DigitalOcean API token for managing droplets."
    type = string
    default = ""
    validation {
        condition = length(trimspace(var.do_token)) > 0
        error_message = "The environment variable must not be empty."
    }
}

variable "acme_email" {
    description = "Email address for ACME certificate registration."
    type = string
    default = ""
    validation {
        condition = can(regex(
            "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$",
            var.acme_email
        )) || var.acme_email == ""
        error_message = "The ACME email must be a valid email address or empty."
    }
}
