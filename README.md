# Vaultwarden-Installer-with-HTTPS-Proxy-Docker
A simple Bash installer that automatically sets up [Vaultwarden](https://github.com/dani-garcia/vaultwarden) (the lightweight Bitwarden-compatible password manager) using **Docker**, **Nginx**, and **self-signed HTTPS certificates**.

---

## ✨ Features

- 🐳 **Dockerized setup** — Runs Vaultwarden and Nginx via Docker Compose.  
- 🔒 **HTTPS by default** — Generates a self-signed SSL certificate.  
- 🔁 **HTTP → HTTPS redirect** — Automatically enforces secure connections.  
- ⚙️ **Interactive configuration** — Choose custom ports, folders, and admin token.  
- 🔐 **Admin panel support** — Easily manage your Vaultwarden instance.  

---

## 🧰 Requirements

- Ubuntu or Debian-based system  
- `bash`, `curl`, and `openssl`  
- Root or `sudo` privileges (required for Docker installation)

---

## 🚀 Installation

Clone this repository and run the installer:

```bash
git clone https://github.com/JaimeGalvezMartinez/vaultwarden-installer-with-HTTPS-Proxy-Docker.git
cd vaultwarden-installer-with-HTTPS-Proxy-Docker
chmod +x install-vaultwarden.sh
sudo ./install-vaultwarden.sh
```
During installation, you’ll be prompted for:

| Setting | Description | Default | Notes |
|----------|--------------|----------|--------|
| **Installation folder** | Directory where Vaultwarden and Nginx files are stored | `~/vaultwarden-docker` | ✅ You can modify this |
| **Internal HTTP port** | Port inside the Vaultwarden container | `80` | ⚠️ Modifying this may cause configuration problems |
| **Host HTTP port** | Port exposed for HTTP access | `8081` | ✅ You can modify this |
| **Host HTTPS port** | Port exposed for HTTPS access | `8445` | ✅ You can modify this |
| **Admin token** | Password for the admin panel | `supersecret` | ✅ You can modify this |


🌐 Accessing Your Vaultwarden

Once setup completes:

🔒 Vaultwarden (HTTPS):      https://xx.xx.xx.xx:8445


🗝️ Configuration Files
File	                                               Description

docker-compose.yml	                                 Docker Compose setup for Vaultwarden + Nginx
nginx.conf	                                         Nginx reverse proxy and HTTPS configuration
ssl/selfsigned.crt, ssl/selfsigned.key	             Self-signed certificate and key

🔄 Updating

To update Vaultwarden or Nginx to the latest version:

```bash

cd ~/vaultwarden-docker
sudo docker compose pull
sudo docker compose up -d
```

🧹 Uninstalling

To completely remove Vaultwarden and all data:

```bash

cd ~/vaultwarden-docker
sudo docker compose down -v
rm -rf ~/vaultwarden-docker

```

⚠️ Notes

This setup uses self-signed certificates, which are not trusted publicly. (For Intranets That Let's encrypt aren't working)
The admin panel is accessible at /admin using the token you set during installation.

📝 License

This project is released under the MIT License

💡 Author

Developed by Jaime Galvez @ 2025. Original Project. [Vaultwarden](https://github.com/dani-garcia/vaultwarden)
