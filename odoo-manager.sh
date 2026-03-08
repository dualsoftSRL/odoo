#!/bin/bash

BASE_DIR="/opt"

pause() {
  read -p "Presione ENTER para continuar..." </dev/tty
}

get_ip() {
  IP=$(curl -4 -s ifconfig.me 2>/dev/null)
  if [ -z "$IP" ]; then
    IP=$(hostname -I | tr ' ' '\n' | grep -E '^[0-9]+\.' | head -1)
  fi
  echo "$IP"
}

get_instances() {
  docker ps --format '{{.Names}}' \
    | grep -E '(_odoo|_app)$' \
    | sed 's/_odoo$//' \
    | sed 's/_app$//' \
    | sort -u
}

get_odoo_port() {
  local NAME="$1"
  docker ps --format '{{.Names}} {{.Ports}}' \
    | grep -E "^(${NAME}_odoo|${NAME}_app) " \
    | grep -oE '0\.0\.0\.0:[0-9]+->8069/tcp' \
    | head -1 \
    | sed 's/0.0.0.0://' \
    | sed 's/->8069\/tcp//'
}

get_instance_dir() {
  local NAME="$1"
  if [ -d "/opt/$NAME" ]; then
    echo "/opt/$NAME"
    return
  fi
  if [ -d "/opt/odoo-$NAME" ]; then
    echo "/opt/odoo-$NAME"
    return
  fi
  if [ "$NAME" = "odoo" ] && [ -d "/opt/odoo" ]; then
    echo "/opt/odoo"
    return
  fi
  echo "/opt/$NAME"
}

list_instances() {
  IP=$(get_ip)

  echo ""
  echo "Instancias instaladas:"
  echo ""

  INSTANCES=$(get_instances)

  if [ -z "$INSTANCES" ]; then
    echo "No se encontraron instancias."
    echo ""
    pause
    return
  fi

  while IFS= read -r NAME; do
    [ -z "$NAME" ] && continue
    PORT=$(get_odoo_port "$NAME")
    if [ -n "$PORT" ]; then
      echo "$NAME  →  http://$IP:$PORT"
    else
      echo "$NAME  →  puerto no detectado"
    fi
  done <<< "$INSTANCES"

  echo ""
  pause
}

port_available() {
  PORT=8070
  while ss -tuln | grep -q ":$PORT "; do
    PORT=$((PORT+1))
  done
  echo "$PORT"
}

create_instance() {
  echo ""
  read -p "Nombre de la nueva instancia: " NAME </dev/tty

  if [ -z "$NAME" ]; then
    echo "Nombre inválido"
    pause
    return
  fi

  if docker ps -a --format '{{.Names}}' | grep -qE "^${NAME}_(odoo|app|nginx|postgres)$"; then
    echo ""
    echo "ERROR: ya existe una instancia Docker con ese nombre"
    pause
    return
  fi

  if [ -d "/opt/$NAME" ] || [ -d "/opt/odoo-$NAME" ]; then
    echo ""
    echo "ERROR: ya existe una carpeta para esa instancia"
    pause
    return
  fi

  DIR="/opt/$NAME"

  PORT=$(port_available)
  LONGPOLL=$((PORT+1))
  NGINX_PORT=$((PORT+10))

  mkdir -p "$DIR"/addons/desarrollado
  mkdir -p "$DIR"/addons/enterprise
  mkdir -p "$DIR"/addons/terceros
  mkdir -p "$DIR"/config
  mkdir -p "$DIR"/nginx
  mkdir -p "$DIR"/backups

  cd "$DIR" || exit 1

  cat > docker-compose.yml <<EOF
version: "3.9"

services:

  db:
    image: postgres:16
    container_name: ${NAME}_postgres
    restart: always
    environment:
      POSTGRES_DB: postgres
      POSTGRES_USER: odoo
      POSTGRES_PASSWORD: odoo
    volumes:
      - postgres_data:/var/lib/postgresql/data

  odoo:
    image: odoo:18
    container_name: ${NAME}_odoo
    restart: always
    depends_on:
      - db
    ports:
      - "${PORT}:8069"
      - "${LONGPOLL}:8072"
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
    container_name: ${NAME}_nginx
    restart: always
    depends_on:
      - odoo
    ports:
      - "${NGINX_PORT}:80"
    volumes:
      - ./nginx/odoo.conf:/etc/nginx/conf.d/default.conf

volumes:
  postgres_data:
  odoo_data:
EOF

  cat > config/odoo.conf <<EOF
[options]
db_host = db
db_port = 5432
db_user = odoo
db_password = odoo
addons_path = /mnt/desarrollado,/mnt/enterprise,/mnt/terceros,/usr/lib/python3/dist-packages/odoo/addons
admin_passwd = admin
proxy_mode = True
EOF

  cat > nginx/odoo.conf <<EOF
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

    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;

    location / {
        proxy_pass http://odoo;
    }

    location /longpolling {
        proxy_pass http://odoochat;
    }

    location /websocket {
        proxy_pass http://odoochat;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
    }
}
EOF

  docker compose up -d

  IP=$(get_ip)

  echo ""
  echo "Instancia creada correctamente"
  echo "Ruta: $DIR"
  echo "Acceso Odoo: http://$IP:$PORT"
  echo "Acceso Nginx: http://$IP:$NGINX_PORT"
  echo ""
  pause
}

delete_instance() {
  echo ""
  echo "Seleccione instancia a borrar:"
  echo ""

  mapfile -t INST_ARRAY < <(get_instances)

  if [ ${#INST_ARRAY[@]} -eq 0 ]; then
    echo "No hay instancias para borrar."
    echo ""
    pause
    return
  fi

  select NAME in "${INST_ARRAY[@]}"; do
    if [ -z "$NAME" ]; then
      echo "Opción inválida"
      pause
      return
    fi

    read -p "CONFIRMAR borrar la instancia '$NAME' (si/no): " CONF </dev/tty

    if [ "$CONF" != "si" ]; then
      echo "Cancelado"
      pause
      return
    fi

    DIR=$(get_instance_dir "$NAME")

    docker stop ${NAME}_odoo ${NAME}_app ${NAME}_nginx ${NAME}_postgres 2>/dev/null || true
    docker rm ${NAME}_odoo ${NAME}_app ${NAME}_nginx ${NAME}_postgres 2>/dev/null || true

    docker volume rm ${NAME}_postgres_data ${NAME}_odoo_data 2>/dev/null || true

    if [ -d "$DIR" ]; then
      rm -rf "$DIR"
      echo "Carpeta eliminada: $DIR"
    fi

    echo ""
    echo "Instancia eliminada"
    echo ""
    pause
    break
  done
}

while true; do
  clear
  echo "================================="
  echo "      ODOO SERVER MANAGER"
  echo "================================="
  echo ""
  echo "1) Listar instancias"
  echo "2) Crear nueva instancia"
  echo "3) Borrar instancia"
  echo "0) Salir"
  echo ""

  read -p "Seleccione opción: " OPTION </dev/tty

  case "$OPTION" in
    1) list_instances ;;
    2) create_instance ;;
    3) delete_instance ;;
    0) exit ;;
    *)
      echo ""
      echo "Opción inválida"
      sleep 1
      ;;
  esac
done