#!/bin/bash

OS=$(uname)

if [ "$OS" = "Darwin" ]; then
BASE_DIR="$HOME/odoo"
else
BASE_DIR="/opt"
fi

ADDONS_REPO="https://github.com/dualsoftSRL/dualsoft-odoo-addons.git"

pause(){
read -p "Presione ENTER para continuar..." </dev/tty
}

get_ip(){

IP=$(curl -4 -s ifconfig.me 2>/dev/null)

if [ -z "$IP" ]; then
IP=$(hostname -I | awk '{print $1}')
fi

echo $IP

}

get_instances(){

docker ps --format "{{.Names}}" | grep -E "_odoo|_app" | sed 's/_odoo//g' | sed 's/_app//g' | sort -u

}

get_odoo_port(){

NAME=$1

docker ps --format "{{.Names}} {{.Ports}}" \
| grep "$NAME" \
| grep -oE "0.0.0.0:[0-9]+" \
| head -1 \
| cut -d: -f2

}

list_instances(){

IP=$(get_ip)

echo ""
echo "Instancias instaladas:"
echo ""

INSTANCES=$(get_instances)

for NAME in $INSTANCES
do

PORT=$(get_odoo_port $NAME)

echo "$NAME  →  http://$IP:$PORT"

done

echo ""
pause

}

port_available(){

PORT=8070

while lsof -i :$PORT >/dev/null 2>&1
do
PORT=$((PORT+1))
done

echo $PORT

}

create_instance(){

echo ""
read -p "Nombre de la nueva instancia: " NAME </dev/tty

DIR="$BASE_DIR/$NAME"

if [ -d "$DIR" ]; then

echo ""
echo "ERROR: ya existe una instancia con ese nombre"
pause
return

fi

PORT=$(port_available)

LONGPOLL=$((PORT+1))
NGINX=$((PORT+10))

mkdir -p $DIR/addons
mkdir -p $DIR/config
mkdir -p $DIR/nginx
mkdir -p $DIR/backups

echo ""
echo "Descargando addons base..."
git clone $ADDONS_REPO $DIR/addons

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
      - ./addons:/mnt/addons

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
echo "Seleccione instancia a borrar:"
echo ""

INSTANCES=$(get_instances)

select NAME in $INSTANCES
do

if [ -z "$NAME" ]; then
echo "Opción inválida"
return
fi

read -p "CONFIRMAR borrar $NAME (si/no): " CONF </dev/tty

if [ "$CONF" != "si" ]; then
return
fi

docker stop ${NAME}_odoo ${NAME}_app ${NAME}_nginx ${NAME}_postgres 2>/dev/null
docker rm ${NAME}_odoo ${NAME}_app ${NAME}_nginx ${NAME}_postgres 2>/dev/null

DIR="$BASE_DIR/$NAME"

if [ -d "$DIR" ]; then
rm -rf $DIR
fi

echo ""
echo "Instancia eliminada"
echo ""

pause
break

done

}

update_addons(){

echo ""
echo "Seleccione instancia para actualizar addons:"
echo ""

INSTANCES=$(get_instances)

select NAME in $INSTANCES
do

if [ -z "$NAME" ]; then
echo "Opción inválida"
return
fi

DIR="$BASE_DIR/$NAME/addons"

if [ ! -d "$DIR" ]; then

echo ""
echo "La instancia no tiene carpeta addons"
pause
return

fi

echo ""
echo "Actualizando addons en $NAME..."
echo ""

cd $DIR

git pull $ADDONS_REPO

echo ""
echo "Addons actualizados correctamente"
echo ""

pause
break

done

}

while true
do

clear

echo "================================="
echo "      ODOO SERVER MANAGER"
echo "================================="
echo ""
echo "1) Listar instancias"
echo "2) Crear nueva instancia"
echo "3) Borrar instancia"
echo "4) Actualizar addons"
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

4)
update_addons
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
