#!/bin/bash

BASE_DIR="/opt"

pause(){
read -p "Presione ENTER para continuar..." </dev/tty
}

get_ip(){

IP=$(curl -4 -s ifconfig.me)

if [ -z "$IP" ]; then
IP=$(hostname -I | tr ' ' '\n' | grep -E '^[0-9]+\.' | head -1)
fi

echo $IP

}

list_instances(){

IP=$(get_ip)

echo ""
echo "Instancias instaladas:"
echo ""

docker ps --format "{{.Names}} {{.Ports}}" | grep odoo | while read line; do

NAME=$(echo $line | awk '{print $1}' | sed 's/_odoo//g' | sed 's/_app//g')

PORT=$(echo $line | grep -oE '0.0.0.0:[0-9]+' | head -1 | cut -d: -f2)

if [ ! -z "$PORT" ]; then
echo "$NAME  →  http://$IP:$PORT"
fi

done

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
read -p "Nombre de la nueva instancia: " NAME </dev/tty

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

mkdir -p $DIR/{addons/{desarrollado,enterprise,terceros},config,nginx,backups}

cd $DIR

cat <<EOF > docker-compose.yml
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

  nginx:
    image: nginx:latest
    container_name: ${NAME}_nginx
    restart: always
    depends_on:
      - odoo
    ports:
      - "$NGINX:80"
    volumes:
      - ./nginx:/etc/nginx/conf.d

volumes:
  postgres_data:
  odoo_data
EOF

docker compose up -d

IP=$(get_ip)

echo ""
echo "Instancia creada correctamente"
echo ""
echo "Acceso:"
echo "http://$IP:$PORT"
echo ""

pause

}

delete_instance(){

echo ""
echo "Instancias disponibles para borrar:"
echo ""

INSTANCES=$(docker ps --format "{{.Names}}" | grep -E "_odoo|_app")

select CONTAINER in $INSTANCES; do

if [ -z "$CONTAINER" ]; then
echo "Opción inválida"
return
fi

NAME=$(echo $CONTAINER | sed 's/_odoo//g' | sed 's/_app//g')

read -p "CONFIRMAR borrar la instancia '$NAME' (si/no): " CONF </dev/tty

if [ "$CONF" != "si" ]; then
echo "Cancelado"
pause
return
fi

echo ""
echo "Deteniendo contenedores..."

docker stop ${NAME}_odoo ${NAME}_app ${NAME}_nginx ${NAME}_postgres 2>/dev/null
docker rm ${NAME}_odoo ${NAME}_app ${NAME}_nginx ${NAME}_postgres 2>/dev/null

echo ""

if [ -d "/opt/odoo-$NAME" ]; then
rm -rf /opt/odoo-$NAME
echo "Carpeta eliminada /opt/odoo-$NAME"
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

1)
list_instances
;;

2)
create_instance
;;

3)
delete_instance
;;

0)
exit
;;

*)
echo ""
echo "Opción inválida"
sleep 1
;;

esac

done