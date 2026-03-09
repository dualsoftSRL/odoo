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
echo "================================="
echo " INSTALACIÓN COMPLETA"
echo "================================="
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

if ! command -v docker >/dev/null 2>&1; then

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

else

echo "Docker ya está instalado"

fi

install_manager
}

install_mac() {

echo "Sistema detectado: macOS"

if ! command -v docker >/dev/null 2>&1; then

echo ""
echo "Debe instalar Docker Desktop primero:"
echo "https://www.docker.com/products/docker-desktop/"
echo ""
exit 1

fi

install_manager
}

# Detectar sistema

if [ "$OS" = "Linux" ]; then

install_linux

elif [ "$OS" = "Darwin" ]; then

install_mac

else

echo "Sistema operativo no soportado: $OS"
exit 1

fi
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

fidone

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
