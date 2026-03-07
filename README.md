# Odoo Server Manager

Herramienta para instalar y administrar múltiples instancias de Odoo usando Docker.

Permite crear, actualizar y eliminar instancias fácilmente mediante un menú interactivo.

Ideal para servidores donde se gestionan múltiples implementaciones de Odoo.

---

# Instalación

En un VPS nuevo ejecutar: 

curl -fsSL https://raw.githubusercontent.com/dualsoftSRL/odoo/main/install_odoo.sh | bash

Esto instalará:

- Docker
- Docker Compose
- Watchtower (actualización automática de contenedores)
- Odoo Manager

---

# Uso

Una vez instalado ejecutar:
odoo-manager

Se mostrará el menú:

ODOO SERVER MANAGER
	1.	Listar instancias
	2.	Crear nueva instancia
	3.	Actualizar instancia
	4.	Borrar instancia
	5.	Salir
