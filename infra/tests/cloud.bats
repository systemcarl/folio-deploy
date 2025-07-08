#!/usr/bin/env bats

TEST_DIR="$(realpath "$(dirname "$BATS_TEST_FILENAME")")"
source "$TEST_DIR/../../cli/tests/mocks"

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    setup_mocks

    mock apt
    apt-get() {
        log_mock_call apt-get "$@"
        if [[ " $* " == *" upgrade "* ]]; then
            set_mock_state "upgrade_frontend" "$DEBIAN_FRONTEND"
        fi
    }

    mock install
    dpkg() {
        log_mock_call dpkg "$@"
        if [[ " $* " == *"--print-architecture"* ]]; then echo "arch"; fi
    }

    mock sed
    tee() {
        local input=""
        if [ ! -t 0 ]; then
            while IFS= read -r line; do input+="$line"$'\n'; done
        fi
        log_mock_call tee "$@" "$input"
        if [[ " $* " == *" /home/app/Caddyfile "* ]]; then
            if [[ " $* " == *" -a "* ]]; then
                local caddyfile=$(get_mock_state "caddyfile" \
                    | command sed 's/^"//;s/"$//')
                set_mock_state "caddyfile" "$caddyfile"
                set_mock_state "caddyfile" "$caddyfile"$'\n'"$input"
            else
                set_mock_state "caddyfile" "$input"
            fi
        fi
    }

    mock mkdir
    mock chmod
    mock chown
    mock rm
    mock ls
    mock su
    mock useradd
    mock usermod
    mock systemctl
    mock curl
    mock ufw

    VERSION_CODENAME="codename"
    environment="production"
    app_package="app-package"
    hostname="example.com"
    ssh_port="2222"
    ssh_public_key="ssh-rsa abcd123 comment"
    acme_email=""

    cloud_init() { source "infra/cloud-init.tftpl"; }
}

teardown() {
    teardown_mocks
}

@test "initializes" {
    run cloud_init
    assert_success
    assert_output --partial "Starting deployment cloud-init script..."
    assert_output --partial "Cloud-init script completed successfully."
}

@test "upgrades system packages interactively" {
    run cloud_init
    assert_success
    assert_mocks_called_in_order \
        apt-get update -- \
        apt-get -o Dpkg::Options::="--force-confold" -y upgrade
    assert_mock_state "upgrade_frontend" "noninteractive"
}

@test "installs ufw" {
    run cloud_init
    assert_success
    assert_mock_called_once apt-get install ufw -y
}

@test "installs Docker and dependencies" {
    run cloud_init
    cat $MOCK_FILE
    assert_success
    assert_mocks_called_in_order \
        apt-get install ca-certificates curl -- \
        curl -fsSL https://download.docker.com/linux/debian/gpg \
            -o /etc/apt/keyrings/docker.asc -- \
        chmod a+r /etc/apt/keyrings/docker.asc -- \
        tee /etc/apt/sources.list.d/docker.list \
            "deb [arch=arch signed-by=/etc/apt/keyrings/docker.asc]
                https://download.docker.com/linux/debian codename stable" -- \
        apt-get update -- \
        apt-get install docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin -y
}

@test "cleans up packages" {
    run cloud_init
    assert_success
    assert_mocks_called_in_order \
        apt autoremove -y -- \
        apt clean -y
}

@test "configures SSH port" {
    run cloud_init
    assert_success
    assert_mock_called_once sed -i \
        's/^#Port 22/Port '"${ssh_port}"'/' /etc/ssh/sshd_config
}

@test "disables root login in SSH" {
    run cloud_init
    assert_success
    assert_mock_called_once sed -i \
        's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
}

@test "removes SSH config files" {
    run cloud_init
    assert_success
    assert_mock_called_once rm -r /etc/ssh/ssh_config.d/*.conf
}

@test "ignores empty SSH config directory" {
    ls() { log_mock_call ls "$@"; return 1; }
    run cloud_init
    assert_success
    assert_mock_not_called rm -r /etc/ssh/ssh_config.d/*.conf
}

@test "restarts SSH service" {
    run cloud_init
    assert_success
    assert_mock_called_once systemctl restart sshd
}

@test "configures UFW" {
    run cloud_init
    assert_success
    assert_mock_called_once ufw default deny incoming
    assert_mock_called_once ufw default allow outgoing
    assert_mock_called_once ufw allow "${ssh_port}"/tcp
    assert_mock_called_once ufw allow 80/tcp
    assert_mock_called_once ufw allow 443/tcp
    assert_mock_called_once ufw --force enable
}

@test "initializes Docker" {
    run cloud_init
    assert_success
    assert_mocks_called_in_order \
        systemctl start docker -- \
        systemctl enable docker
}

@test "creates app user" {
    run cloud_init
    assert_success
    assert_mock_called_once useradd -m -s /bin/bash app
    assert_mock_called_once usermod -aG docker app
}

@test "configures app user SSH" {
    run cloud_init
    assert_success
    assert_mock_called_once mkdir -p /home/app/.ssh
    assert_mock_called_once tee /home/app/.ssh/authorized_keys \
        "${ssh_public_key}"
    assert_mock_called_once chown -R app:app /home/app/.ssh
    assert_mock_called_once chmod 700 /home/app/.ssh
    assert_mock_called_once chmod 600 /home/app/.ssh/authorized_keys
}

@test "configures Caddy" {
    run cloud_init
    assert_success
    assert_mock_called_once chown app:app /home/app/Caddyfile
    assert_mock_state "caddyfile" \
        "example.com { \
            reverse_proxy folio:3000 \
        }"
}

@test "configures Caddy with ACME email" {
    acme_email="example@example.com"
    run cloud_init
    assert_success
    assert_mock_state "caddyfile" \
        "{ \
            email example@example.com \
        } \
          \
        example.com { \
            reverse_proxy folio:3000 \
        }"
}

@test "configures Caddy with staging ACME server" {
    environment="staging"
    acme_email="example@example.com"
    run cloud_init
    assert_success
    assert_mock_state "caddyfile" \
        "{ \
            email example@example.com \
            acme_ca https://acme-staging-v02.api.letsencrypt.org/directory \
        } \
          \
        ${hostname} { \
            reverse_proxy folio:3000 \
        }"
}

@test "starts Caddy container" {
    run cloud_init
    assert_success
    assert_mocks_called_in_order \
        su - app -c "docker network create web" -- \
        su - app -c "docker run -d \
            --name caddy \
            --network web \
            --restart always \
            -p 80:80 \
            -p 443:443 \
            -v /home/app/Caddyfile:/etc/caddy/Caddyfile \
            caddy:latest"
}

@test "starts application container" {
    run cloud_init
    assert_success
    assert_mocks_called_in_order \
        su - app -c "docker network create web" -- \
        su - app -c "docker run -d \
            --name folio \
            --network web \
            ${app_package}"
}
