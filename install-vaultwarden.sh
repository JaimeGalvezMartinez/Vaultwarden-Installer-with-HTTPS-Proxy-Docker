#!/bin/bash
set -e

echo "=============================================="
echo "🚀 Vaultwarden Installer with HTTPS Proxy"
echo "=============================================="
echo ""

# === USER INPUT ===
read -rp "📁 Installation folder (default ~/vaultwarden-docker): " VAULT_DIR
VAULT_DIR=${VAULT_DIR:-$HOME/vaultwarden-docker}

read -rp "🔢 HTTP internal port for Vaultwarden (default 80): " HTTP_PORT_INTERNAL
HTTP_PORT_INTERNAL=${HTTP_PORT_INTERNAL:-80}

read -rp "🔢 HTTP host port to expose (default 8081): " HTTP_PORT_HOST
HTTP_PORT_HOST=${HTTP_PORT_HOST:-8081}

read -rp "🔒 HTTPS host port to expose (default 8445): " HTTPS_PORT
HTTPS_PORT=${HTTPS_PORT:-8445}

read -rp "🗝️  Admin token (default 'supersecret'): " ADMIN_TOKEN
ADMIN_TOKEN=${ADMIN_TOKEN:-supersecret}

SSL_DIR="$VAULT_DIR/ssl"
NGINX_CONF="$VAULT_DIR/nginx.conf"

echo ""
echo "Configuration summary:"
echo "----------------------------------------------"
echo "📂 Folder:            $VAULT_DIR"
echo "🔢 HTTP internal:     $HTTP_PORT_INTERNAL"
echo "🔢 HTTP host port:    $HTTP_PORT_HOST"
echo "🔒 HTTPS host port:   $HTTPS_PORT"
echo "🗝️  Admin token:       $ADMIN_TOKEN"
echo "----------------------------------------------"
read -rp "Continue with installation? (y/n): " CONFIRM
[[ "$CONFIRM" =~ ^[yY]$ ]] || { echo "❌ Installation cancelled."; exit 1; }

# === FUNCTIONS ===

install_docker() {
    if ! command -v docker &>/dev/null; then
        echo "🚀 Installing Docker..."
        apt update && apt install -y ca-certificates curl gnupg lsb-release
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
          https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt update && apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        systemctl enable --now docker
    else
        echo "✅ Docker is already installed."
    fi
}

generate_certificate() {
    echo "🔒 Generating self-signed certificate..."
    mkdir -p "$SSL_DIR"
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout "$SSL_DIR/selfsigned.key" \
        -out "$SSL_DIR/selfsigned.crt" \
        -subj "/C=ES/ST=Castilla-La Mancha/L=Toledo/O=Vaultwarden/CN=Intranet"
}

create_nginx_conf() {
    echo "🧱 Creating nginx.conf..."
    mkdir -p "$VAULT_DIR"
    cat > "$NGINX_CONF" <<EOF
server {
    listen 443 ssl;
    server_name localhost;

    ssl_certificate /etc/ssl/private/selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/selfsigned.key;

    location / {
        proxy_pass http://vaultwarden:$HTTP_PORT_INTERNAL;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen $HTTP_PORT_HOST;
    server_name localhost;
    return 301 https://\$host\$request_uri;
}
EOF
}

create_compose() {
    echo "🧱 Creating docker-compose.yml..."
    mkdir -p "$VAULT_DIR"

    cat > "$VAULT_DIR/docker-compose.yml" <<EOF
services:
  vaultwarden:
    image: vaultwarden/server:latest
    restart: always
    environment:
      - ADMIN_TOKEN=$ADMIN_TOKEN
    volumes:
      - vaultwarden_data:/data

  proxy:
    image: nginx:latest
    restart: always
    depends_on:
      - vaultwarden
    ports:
      - "$HTTPS_PORT:443"
      - "$HTTP_PORT_HOST:$HTTP_PORT_HOST"
    volumes:
      - $SSL_DIR:/etc/ssl/private:ro
      - $NGINX_CONF:/etc/nginx/conf.d/default.conf:ro

volumes:
  vaultwarden_data:
EOF
}

start_containers() {
    echo "🚀 Starting Vaultwarden + Nginx proxy..."
    cd "$VAULT_DIR"
    docker compose up -d
}

# === EXECUTION ===
install_docker
generate_certificate
create_nginx_conf
create_compose
start_containers

echo ""
echo "✅ Installation completed successfully."
echo "🌐 Vaultwarden available at:"
echo "  - HTTPS: https://localhost:$HTTPS_PORT (self-signed)"
echo "  - HTTP redirect: http://localhost:$HTTP_PORT_HOST"
echo "⚠️ Remember to accept the self-signed certificate in your browser."
