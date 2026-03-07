#!/bin/bash

BASE_DIR="/opt"

function pause(){
read -p "Presione ENTER para continuar..."
}

function list_instances(){
echo ""
echo "Instancias Odoo instaladas:"
echo ""

ls -d /opt/odoo-* 2>/dev/null | sed 's|/opt/odoo-||'

echo ""
}

function port_available(){

PORT=8070

while ss -tuln | grep -q ":$PORT "; do
PORT=$((PORT+1))
done

echo $PORT

}

function create_instance(){

echo ""
read -p "Nombre de la nueva instancia: " NAME

DIR="$BASE_DIR/odoo-$NAME"

if [ -d "$DIR" ]; then
echo ""
echo "ERROR: ya existe una instancia con ese nombre"
pause
return
fi

PORT=$(port_available)
LONGPOLL=$((PORT+1))
NGINX=$((PORT+10))

echo ""
echo "Creando instancia $NAME"
echo "Puerto Odoo: $PORT"
echo "Puerto Web: $NGINX"

mkdir -p $DIR/{addons/{desarrollado,enterprise,terceros},config,nginx,backups}

cd $DIR

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
      - "$PORT:8069"
      - "$LONGPOLL:8072"
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
      - "$NGINX:80"
    volumes:
      - ./nginx/odoo.conf:/etc/nginx/conf.d/default.conf

volumes:
  postgres_data:
  odoo_data
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

server {
listen 80;

location / {
proxy_pass http://odoo;
}

location /longpolling {
proxy_pass http://odoo:8072;
}
}
EOF

docker compose up -d

IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')

echo ""
echo "Instancia creada"
echo "Acceso:"
echo "http://$IP:$NGINX"

pause

}

function delete_instance(){

echo ""
echo "Seleccione instancia a borrar:"
echo ""

select NAME in $(ls -d /opt/odoo-* 2>/dev/null | sed 's|/opt/odoo-||'); do

if [ -z "$NAME" ]; then
echo "Opción inválida"
return
fi

DIR="/opt/odoo-$NAME"

echo ""
read -p "CONFIRMAR borrar $NAME (si/no): " CONF

if [ "$CONF" != "si" ]; then
return
fi

cd $DIR

docker compose down -v

cd /opt

rm -rf $DIR

echo ""
echo "Instancia eliminada"

pause

break

done

}

function replace_instance(){

echo ""
echo "Seleccione instancia a reemplazar:"
echo ""

select NAME in $(ls -d /opt/odoo-* 2>/dev/null | sed 's|/opt/odoo-||'); do

DIR="/opt/odoo-$NAME"

cd $DIR

docker compose down

docker compose pull

docker compose up -d

echo ""
echo "Instancia actualizada"

pause

break

done

}

function start_instance(){

select NAME in $(ls -d /opt/odoo-* 2>/dev/null | sed 's|/opt/odoo-||'); do

cd /opt/odoo-$NAME

docker compose up -d

pause
break

done

}

function stop_instance(){

select NAME in $(ls -d /opt/odoo-* 2>/dev/null | sed 's|/opt/odoo-||'); do

cd /opt/odoo-$NAME

docker compose down

pause
break

done

}

function logs_instance(){

select NAME in $(ls -d /opt/odoo-* 2>/dev/null | sed 's|/opt/odoo-||'); do

docker logs -f ${NAME}_odoo

break

done

}

while true; do

clear

echo "================================="
echo "   ODOO SERVER MANAGER"
echo "================================="
echo ""
echo "1) Listar instancias"
echo "2) Crear nueva instancia"
echo "3) Reemplazar / actualizar instancia"
echo "4) Borrar instancia"
echo "5) Iniciar instancia"
echo "6) Detener instancia"
echo "7) Ver logs"
echo "0) Salir"
echo ""

read -p "Seleccione opción: " OPTION

case $OPTION in

1) list_instances ;;
2) create_instance ;;
3) replace_instance ;;
4) delete_instance ;;
5) start_instance ;;
6) stop_instance ;;
7) logs_instance ;;
0) exit ;;
*) echo "Opción inválida"; pause ;;

esac

doneecho "Puertos asignados:"
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
