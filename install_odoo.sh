#!/bin/bash

set -e

ODOO_DIR="/opt/odoo"

echo "Instalando Docker..."

apt update -y
apt install -y docker.io docker-compose-plugin

systemctl enable docker
systemctl start docker

echo "Creando estructura de carpetas..."

mkdir -p $ODOO_DIR
cd $ODOO_DIR

mkdir -p addons/desarrollado
mkdir -p addons/enterprise
mkdir -p addons/terceros
mkdir -p config
mkdir -p nginx

echo "Creando docker-compose.yml..."

cat > docker-compose.yml << 'EOF'
version: "3.9"

services:

  db:
    image: postgres:16
    container_name: odoo_postgres
    restart: always
    environment:
      POSTGRES_DB: postgres
      POSTGRES_USER: dualsoft
      POSTGRES_PASSWORD: t2jk0rh1A
    volumes:
      - postgres_data:/var/lib/postgresql/data

  odoo:
    image: odoo:18
    container_name: odoo_app
    restart: always
    depends_on:
      - db
    ports:
      - "8075:8069"
      - "8076:8072"
    environment:
      HOST: db
      USER: dualsoft
      PASSWORD: t2jk0rh1A
    volumes:
      - odoo_data:/var/lib/odoo
      - ./addons/desarrollado:/mnt/desarrollado
      - ./addons/enterprise:/mnt/enterprise
      - ./addons/terceros:/mnt/terceros
      - ./config/odoo.conf:/etc/odoo/odoo.conf

  nginx:
    image: nginx:latest
    container_name: odoo_nginx
    restart: always
    depends_on:
      - odoo
    ports:
      - "8085:80"
    volumes:
      - ./nginx/odoo.conf:/etc/nginx/conf.d/default.conf

volumes:
  postgres_data:
  odoo_data:
EOF

echo "Creando archivo odoo.conf..."

cat > config/odoo.conf << 'EOF'
[options]

db_host = db
db_port = 5432
db_user = dualsoft
db_password = t2jk0rh1A

addons_path = /mnt/desarrollado,/mnt/enterprise,/mnt/terceros,/usr/lib/python3/dist-packages/odoo/addons

admin_passwd = admin

proxy_mode = True
EOF

echo "Creando configuración nginx..."

cat > nginx/odoo.conf << 'EOF'
upstream odoo {
    server odoo:8069;
}

upstream odoochat {
    server odoo:8072;
}

server {

    listen 80;

    client_max_body_size 200m;

    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;

    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Real-IP $remote_addr;

    location / {
        proxy_pass http://odoo;
    }

    location /longpolling {
        proxy_pass http://odoochat;
    }

    location /websocket {
        proxy_pass http://odoochat;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
    }
}
EOF

echo "Levantando contenedores..."

docker compose up -d

echo ""
echo "======================================"
echo "ODOO INSTALADO"
echo ""
echo "URL:"
echo "http://IP_DEL_SERVIDOR:8085"
echo ""
echo "MASTER PASSWORD:"
echo "admin"
echo ""
echo "Directorio:"
echo "$ODOO_DIR"
echo "======================================"
