#Author:Jaime Galvez Martinez
#Date: 19/10/2025

#!/bin/bash

set -e

echo "=============================================="
echo "🚀 Vaultwarden Installer with HTTPS Proxy"
echo "=============================================="
echo "=============================================="
echo " Author: Jaime Galvez Martinez "
echo "=============================================="
wcho ""

# === USER INPUT ===
read -rp "📁 Installation folder (default ~/vaultwarden-docker): " VAULT_DIR
VAULT_DIR=${VAULT_DIR:-$HOME/vaultwarden-docker}

read -rp "🔢 HTTP internal port for Vaultwarden (default 80): " HTTP_PORT_INTERNAL
HTTP_PORT_INTERNAL=${HTTP_PORT_INTERNAL:-80}

read -rp "🔢 HTTP host port to expose (default 8081): " HTTP_PORT_HOST
HTTP_PORT_HOST=${HTTP_PORT_HOST:-8081}

read -rp "🔒 HTTPS host port to expose (default 8445): " HTTPS_PORT
HTTPS_PORT=${HTTPS_PORT:-8445}

if lsof -i :"$HTTPS_PORT" &>/dev/null; then
  echo "⚠️  Port $HTTPS_PORT is already in used."
else
  echo "✅ Port $HTTPS_PORT is available."
fi


# Check for OpenSSL
command -v openssl >/dev/null 2>&1 || {
  echo "⚠️ OpenSSL not found. Installing..."
  sudo apt update && sudo apt install -y openssl
}

# Update and upgrade packages
sudo apt update && sudo apt upgrade -y

# Ensure vault directory exists
mkdir -p "$VAULT_DIR"

echo "✅ OpenSSL installed and vault directory ready at: $VAULT_DIR"


# === TOKEN GENERATION ===
generate_token() {
  # Generates a secure 8-character token (alphanumeric + symbols)
  openssl rand -base64 9 | tr -dc 'A-Za-z0-9@#%&_+=' | head -c 8
}

while true; do
  read -rsp "🗝️  Admin token (leave empty to generate a random one): " ADMIN_TOKEN
  echo
  if [ -z "$ADMIN_TOKEN" ]; then
    ADMIN_TOKEN=$(generate_token)
    echo "🔒 Automatically generated token: $ADMIN_TOKEN"
    echo "⚠️  Please copy and store this token safely."
    break
  else
    read -rsp "🔁 Confirm admin token: " CONFIRM_TOKEN
    echo
    if [ "$ADMIN_TOKEN" == "$CONFIRM_TOKEN" ]; then
      echo "✅ Token confirmed successfully!"
      break
    else
      echo "❌ Tokens do not match. Please try again."
    fi
  fi
done

# === SSL METADATA INPUT ===
echo ""
echo "🔧 SSL Certificate Metadata (press Enter to use defaults):"
read -rp "🌍 Country Code (default ES): " SSL_COUNTRY
SSL_COUNTRY=${SSL_COUNTRY:-ES}

read -rp "🏙️  State or Province (default State): " SSL_STATE
SSL_STATE=${SSL_STATE:-Castilla-La Mancha}

read -rp "🏡 City (default Toledo): " SSL_CITY
SSL_CITY=${SSL_CITY:-Toledo}

read -rp "🏢 Organization (default INTRANET): " SSL_ORG
SSL_ORG=${SSL_ORG:-INTRANET}

# Capture The main IP of the system
SSL_CN=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')

# And main IP saves in the variable SSL_CN 
echo " 🌐 Common Name / Domain: $SSL_CN"

SSL_DIR="$VAULT_DIR/ssl"
NGINX_CONF="$VAULT_DIR/nginx.conf"

echo ""
echo "Configuration summary:"
echo "----------------------------------------------"
echo "📂 Folder:            $VAULT_DIR"
echo "🔢 HTTP internal:     $HTTP_PORT_INTERNAL"
echo "🔢 HTTP host port:    $HTTP_PORT_HOST"
echo "🔒 HTTPS host port:   $HTTPS_PORT"
echo "🗝️  Admin token:      $ADMIN_TOKEN"
echo "⚠️  Please copy and store this token safely."
echo ""
echo "📜 SSL Certificate Info:"
echo "   Country:           $SSL_COUNTRY"
echo "   State:             $SSL_STATE"
echo "   City:              $SSL_CITY"
echo "   Organization:      $SSL_ORG"
echo "   Common Name:       $SSL_CN"
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
        -subj "/C=$SSL_COUNTRY/ST=$SSL_STATE/L=$SSL_CITY/O=$SSL_ORG/CN=$SSL_CN"
}

create_nginx_conf() {
    echo "🧱 Creating nginx.conf..."
    mkdir -p "$VAULT_DIR"
    cat > "$NGINX_CONF" <<EOF
server {
    listen 443 ssl;
    server_name $SSL_CN;

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
    listen 80;
    server_name $SSL_CN;
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
      - "$HTTP_PORT_HOST:80"
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
echo "✅ Installation completed successfully!"
echo "----------------------------------------------"
echo "🌐 Access Vaultwarden at:"
echo "   🔒 HTTPS: https://$SSL_CN:$HTTPS_PORT"
echo "   🔁 HTTP redirect: http://$SSL_CN:$HTTP_PORT_HOST"
echo ""
echo "🗝️  Admin Token: $ADMIN_TOKEN"
echo "⚠️  Please copy and store this token safely. — it will not be shown again!"
echo "----------------------------------------------"
