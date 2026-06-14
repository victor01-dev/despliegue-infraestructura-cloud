#!/bin/bash
# =============================================================
# setup.sh — Despliegue automático de infraestructura cloud
# Probado en: Ubuntu 22.04 LTS (AWS EC2 t2.micro)
# Autor: Victor Vazquez Fuentes
# =============================================================

set -e  # Salir si cualquier comando falla

echo "=== [1/5] Actualizando el sistema ==="
sudo apt-get update -y && sudo apt-get upgrade -y

echo "=== [2/5] Instalando Docker ==="
sudo apt-get install -y ca-certificates curl gnupg lsb-release

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Añadir usuario actual al grupo docker para no necesitar sudo
sudo usermod -aG docker "$USER"

echo "=== [3/5] Configurando UFW (firewall) ==="
sudo ufw default deny incoming
sudo ufw default allow outgoing

# SSH — solo desde tu IP (modifica con tu IP real o elimina para acceso libre)
sudo ufw allow 22/tcp comment 'SSH'

# HTTP — solo IPs de Cloudflare (el tráfico público siempre pasa por Cloudflare)
# IPs actualizadas en: https://www.cloudflare.com/ips/
for ip in \
  173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 \
  141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 \
  197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13 \
  104.24.0.0/14 172.64.0.0/13 131.0.72.0/22; do
  sudo ufw allow from "$ip" to any port 80 proto tcp comment 'Cloudflare'
done

sudo ufw --force enable
sudo ufw status verbose

echo "=== [4/5] Clonando el repositorio ==="
REPO_DIR="$HOME/despliegue-infraestructura-cloud"

if [ -d "$REPO_DIR" ]; then
  echo "El repositorio ya existe, actualizando..."
  git -C "$REPO_DIR" pull
else
  git clone https://github.com/victor01-dev/despliegue-infraestructura-cloud.git "$REPO_DIR"
fi

cd "$REPO_DIR"

echo "=== [5/5] Levantando los contenedores ==="
docker compose up -d

echo ""
echo "============================================"
echo "  Despliegue completado."
echo "  Comprueba el estado con: docker compose ps"
echo "  Logs en tiempo real:     docker compose logs -f"
echo "============================================"
