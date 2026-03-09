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
echo "Instalación completada"
echo ""
echo "Ejecute:"
echo ""
echo "odoo-manager"
echo ""

}

if [ "$OS" = "Linux" ]; then

echo "Sistema Linux detectado"

apt update -y

if ! command -v docker >/dev/null 2>&1; then

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

install_manager

elif [ "$OS" = "Darwin" ]; then

echo "Sistema macOS detectado"

if ! command -v docker >/dev/null 2>&1; then

echo ""
echo "Debe instalar Docker Desktop primero:"
echo "https://www.docker.com/products/docker-desktop/"
echo ""

exit 1

fi

install_manager

else

echo "Sistema no soportado"
exit 1

fi
