#!/bin/bash

set -e

INSTANCE=$1

if [ -z "$INSTANCE" ]; then
  echo "Uso:"
  echo "install_odoo nombre_instancia"
  exit 1
fi

BASE_DIR="/opt/odoo-$INSTANCE"
BACKUP_DIR="$BASE_DIR/backups"

echo "================================="
echo " Instalando Odoo instancia: $INSTANCE"
echo "================================="

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

echo "Calculando puertos libres..."

BASE_PORT=8070
PORT=$BASE_PORT

while ss -tuln | grep -q ":$PORT "; do
    PORT=$((PORT+1))
done

LONGPOLL=$((PORT+1))
NGINX_PORT=$((PORT+10))

echo "Puertos asignados:"
echo "Odoo: $PORT"
echo "Longpoll: $LONGPOLL"
echo "Nginx: $NGINX_PORT"

mkdir -p $BASE_DIR
mkdir -p $BACKUP_DIR

cd $BASE_DIR

mkdir -p addons/desarrollado
mkdir -p addons/enterprise
mkdir -p addons/terceros
mkdir -p config
mkdir -p nginx

if [ ! -f docker-compose.yml ]; then

cat > docker-compose.yml << EOF
version: "3.9"

services:

  db:
    image: postgres:16
    container_name: ${INSTANCE}_postgres
    restart: always
    environment:
      POSTGRES_DB: postgres
      POSTGRES_USER: odoo
      POSTGRES_PASSWORD: odoo
    volumes:
      - postgres_data:/var/lib/postgresql/data

  odoo:
    image: odoo:18
    container_name: ${INSTANCE}_odoo
    restart: always
    depends_on:
      - db
    ports:
      - "$PORT:8069"
      - "$LONGPOLL:8072"
    environment:
      HOST: db
      USER: odoo
      PASSWORD: odoo
    volumes:
      - odoo_data:/var/lib/odoo
      - ./addons/desarrollado:/mnt/desarrollado
      - ./addons/enterprise:/mnt/enterprise
      - ./addons/terceros:/mnt/terceros
      - ./config/odoo.conf:/etc/odoo/odoo.conf

  nginx:
    image: nginx:latest
    container_name: ${INSTANCE}_nginx
    restart: always
    depends_on:
      - odoo
    ports:
      - "$NGINX_PORT:80"
    volumes:
      - ./nginx/odoo.conf:/etc/nginx/conf.d/default.conf

  watchtower:
    image: containrrr/watchtower
    container_name: ${INSTANCE}_watchtower
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --cleanup --interval 86400

volumes:
  postgres_data:
  odoo_data:
EOF

fi

if [ ! -f config/odoo.conf ]; then

cat > config/odoo.conf << 'EOF'
[options]

db_host = db
db_port = 5432
db_user = odoo
db_password = odoo

addons_path = /mnt/desarrollado,/mnt/enterprise,/mnt/terceros,/usr/lib/python3/dist-packages/odoo/addons

admin_passwd = admin

proxy_mode = True
EOF

fi

if [ ! -f nginx/odoo.conf ]; then

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

fi

BACKUP_SCRIPT="/usr/local/bin/odoo_backup_$INSTANCE.sh"

if [ ! -f $BACKUP_SCRIPT ]; then

cat > $BACKUP_SCRIPT << EOF
#!/bin/bash
DATE=\$(date +%Y%m%d_%H%M)
docker exec ${INSTANCE}_postgres pg_dump -U odoo postgres > $BACKUP_DIR/backup_\$DATE.sql
EOF

chmod +x $BACKUP_SCRIPT

fi

if ! crontab -l | grep -q "$BACKUP_SCRIPT"; then
  (crontab -l 2>/dev/null; echo "0 3 * * * $BACKUP_SCRIPT") | crontab -
fi

echo "Iniciando contenedores..."

docker compose up -d

PUBLIC_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || hostname -I | awk '{print $1}')

echo ""
echo "================================="
echo " INSTANCIA ODOO LISTA"
echo "================================="
echo ""
echo "Instancia:"
echo "$INSTANCE"
echo ""
echo "Acceso:"
echo "http://$PUBLIC_IP:$NGINX_PORT"
echo ""
echo "Directorio:"
echo "$BASE_DIR"
echo ""mkdir -p $ODOO_DIR
cd $ODOO_DIR

mkdir -p addons/desarrollado
mkdir -p addons/enterprise
mkdir -p addons/terceros
mkdir -p config
mkdir -p nginx


echo "--------------------------------------"
echo "CREANDO docker-compose.yml"
echo "--------------------------------------"

cat > docker-compose.yml << 'EOF'
version: "3.9"

services:

  db:
    image: postgres:16
    container_name: odoo_postgres
    restart: always
    environment:
      POSTGRES_DB: postgres
      POSTGRES_USER: odoo
      POSTGRES_PASSWORD: odoo
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
      USER: odoo
      PASSWORD: odoo
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


echo "--------------------------------------"
echo "CREANDO odoo.conf"
echo "--------------------------------------"

cat > config/odoo.conf << 'EOF'
[options]

db_host = db
db_port = 5432
db_user = odoo
db_password = odoo

addons_path = /mnt/desarrollado,/mnt/enterprise,/mnt/terceros,/usr/lib/python3/dist-packages/odoo/addons

admin_passwd = admin

proxy_mode = True
EOF


echo "--------------------------------------"
echo "CREANDO CONFIG NGINX"
echo "--------------------------------------"

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


echo "--------------------------------------"
echo "INICIANDO ODOO"
echo "--------------------------------------"

docker compose up -d


echo "--------------------------------------"
echo "ODOO INSTALADO"
echo "--------------------------------------"

echo ""
echo "URL:"
echo "http://IP_DEL_SERVIDOR:8085"
echo ""
echo "MASTER PASSWORD:"
echo "admin"
echo ""
echo "Directorio:"
echo "$ODOO_DIR"
echo ""
