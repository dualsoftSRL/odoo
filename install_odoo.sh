#!/bin/bash

set -e

echo "================================="
echo " ODOO SERVER INSTALLER"
echo "================================="

OS=$(uname)

install_manager() {

echo "Instalando Odoo Manager..."

curl -fsSL https://raw.githubusercontent.com/dualsoftSRL/odoo/main/odoo-manager.sh \
-o /usr/local/bin/odoo-manager

chmod +x /usr/local/bin/odoo-manager

echo ""
echo "Odoo Manager instalado"
echo ""
echo "Ejecute:"
echo ""
echo "odoo-manager"
echo ""

}

install_linux() {

echo "Sistema detectado: Linux"

echo "Actualizando repositorios..."

apt update -y

echo "Verificando Docker..."

if command -v docker >/dev/null 2>&1
then
    echo "Docker ya instalado"
else

echo "Instalando Docker..."

apt install -y ca-certificates curl gnupg

install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
| tee /etc/apt/keyrings/docker.asc > /dev/null

chmod a+r /etc/apt/keyrings/docker.asc

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
| tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update -y

apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker

fi

echo "Verificando Watchtower..."

if ! docker ps -a | grep -q watchtower; then

docker run -d \
--name watchtower \
--restart always \
-v /var/run/docker.sock:/var/run/docker.sock \
containrrr/watchtower \
--cleanup --interval 86400

echo "Watchtower instalado"

else

echo "Watchtower ya existe"

fi

install_manager

}

install_mac() {

echo "Sistema detectado: macOS"

if ! command -v docker >/dev/null 2>&1
then

echo ""
echo "Docker no está instalado."
echo ""
echo "Instale Docker Desktop primero:"
echo ""
echo "https://www.docker.com/products/docker-desktop/"
echo ""
exit 1

fi

echo "Docker encontrado"

install_manager

}

# Detectar sistema

if [ "$OS" = "Linux" ]; then

install_linux

elif [ "$OS" = "Darwin" ]; then

install_mac

else

echo "Sistema no soportado: $OS"
exit 1

fi

echo ""
echo "================================="
echo " INSTALACIÓN COMPLETA"
echo "================================="
echo ""
echo "Para iniciar el gestor:"
echo ""
echo "odoo-manager"
echo ""