#!/bin/bash

BASE_DIR="/opt"

pause(){
read -p "Presione ENTER para continuar..."
}

list_instances(){

echo ""
echo "Instancias instaladas:"
echo ""

ls -d /opt/odoo-* 2>/dev/null | sed 's|/opt/odoo-||'

echo ""
pause

}

port_available(){

PORT=8070

while ss -tuln | grep -q ":$PORT "; do
PORT=$((PORT+1))
done

echo $PORT

}

create_instance(){

echo ""
read -p "Nombre de la nueva instancia: " NAME

DIR="$BASE_DIR/odoo-$NAME"

if [ -d "$DIR" ]; then
echo "ERROR: ya existe una instancia con ese nombre"
pause
return
fi

PORT=$(port_available)
LONGPOLL=$((PORT+1))
NGINX=$((PORT+10))

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

delete_instance(){

echo ""
echo "Seleccione instancia a borrar:"
echo ""

select NAME in $(ls -d /opt/odoo-* 2>/dev/null | sed 's|/opt/odoo-||'); do

DIR="/opt/odoo-$NAME"

read -p "CONFIRMAR borrar $NAME (si/no): " CONF

if [ "$CONF" != "si" ]; then
return
fi

cd $DIR

docker compose down -v

cd /opt

rm -rf $DIR

echo "Instancia eliminada"

pause
break

done

}

replace_instance(){

echo ""
echo "Seleccione instancia a actualizar:"
echo ""

select NAME in $(ls -d /opt/odoo-* 2>/dev/null | sed 's|/opt/odoo-||'); do

cd /opt/odoo-$NAME

docker compose down
docker compose pull
docker compose up -d

echo "Instancia actualizada"

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
echo "3) Actualizar instancia"
echo "4) Borrar instancia"
echo "0) Salir"
echo ""

read -p "Seleccione opción: " OPTION

case $OPTION in

1) list_instances ;;
2) create_instance ;;
3) replace_instance ;;
4) delete_instance ;;
0) exit ;;
*) echo "Opción inválida"; pause ;;

esac

done
