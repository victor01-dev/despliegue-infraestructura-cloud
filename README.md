Proyecto de despliegue automatizado con Docker sobre una instancia EC2 en AWS
# Despliegue de Infraestructura Cloud: Nginx sobre Docker en AWS EC2

Este repositorio contiene la documentación técnica y la configuración necesarias para el despliegue de un servidor web Nginx altamente disponible y contenedorizado utilizando Docker sobre una instancia de computación virtualizada Amazon EC2 (Elastic Compute Cloud) de Amazon Web Services (AWS).

Este proyecto ha sido desarrollado como una práctica avanzada en administración de sistemas cloud.

🏛️ Arquitectura del Sistema
El despliegue consta de un modelo clásico de infraestructura en la nube estructurado en capas de red y seguridad:

Host de Computación: Instancia de AWS EC2 de tipo t3.micro corriendo el sistema operativo Ubuntu Server Linux.

Capa de Aislamiento: Docker Engine encargado de la descarga de la imagen oficial y aislamiento en un microentorno mutable.

Servidor Web: Nginx actuando como el backend principal encargado de despachar peticiones de socket en el puerto estándar de HTTP.

Capa DNS Extensiva: Delegación de registros de zona en Namecheap con redireccionamiento global mediante registros maestros A y alias CNAME.

🛠️ Guía de Despliegue Paso a Paso
Paso 1: Configuración del Entorno Local y Conexión SSH
Desde el sistema operativo cliente (Linux), se procedió a la securización de los permisos de la clave criptográfica asimétrica de Amazon (.pem) y a establecer el túnel cifrado SSH hacia la IP pública de la instancia:

chmod 400 mi-clave.pem

ssh -i "mi-clave.pem" ubuntu@18.175.209.144

Paso 2: Aprovisionamiento de Docker en el Servidor Ubuntu
Una vez dentro del entorno de AWS, se actualizaron las firmas de los repositorios y se instaló el motor nativo de contenedores de Linux:

ubuntu@ip-172-31-3-168:~$ sudo apt update && sudo apt upgrade -y

ubuntu@ip-172-31-3-168:~$ sudo apt install docker.io -y

ubuntu@ip-172-31-3-168:~$ sudo systemctl start docker

ubuntu@ip-172-31-3-168:~$ sudo systemctl enable docker

ubuntu@ip-172-31-3-168:~$ sudo usermod -aG docker ubuntu

Nota: Tras la asignación al grupo docker, se procedió a realizar un exit de la terminal y una reconexión por SSH para refrescar los privilegios del token del usuario.

Paso 3: Orquestación del Contenedor Web
Se ejecutó de manera aislada y desvinculada (detached mode) el servidor web mediante los parámetros de direccionamiento de puertos del kernel:

ubuntu@ip-172-31-3-168:~$ docker run -d -p 80:80 --name mi-web nginx

📈 Evidencias del Despliegue y Pruebas de Verificación
A continuación se adjuntan las trazas de comandos y capturas que prueban el funcionamiento e integración de cada elemento del flujo tecnológico:

1. Estado de la Orquestación de Docker
Verificación del estado operativo continuo mediante el comando de control docker ps:

ubuntu@ip-172-31-3-168:~$ docker ps

2. Respuesta de Red por Dirección IP Absoluta
Comprobación de la conectividad en el navegador sobre la IP del host de AWS, retornando de forma exitosa el payload de bienvenida de Nginx:

<img width="1201" height="405" alt="Captura de pantalla_20260603_134202" src="https://github.com/user-attachments/assets/d20d7f2f-2090-4608-b6b4-059e7f953356" />

3. Resolución DNS del Dominio Personalizado
Configuración de los registros autoritativos de la zona maestra en Namecheap apuntando a la infraestructura Cloud:

Registro A (Dominio Raíz): @ mapeado a 18.175.209.144

Registro CNAME (Alias de Red): www mapeado a midominioweb.xyz

Acceso final exitoso mediante resolución de nombres fully qualified domain name (FQDN): http://midominioweb.xyz

<img width="765" height="356" alt="dominio" src="https://github.com/user-attachments/assets/f82a15ed-f1a6-4239-83b5-175b50378a0f" />

🎓 Conclusiones:
Administración Cloud: Creación, configuración y gestión del ciclo de vida de instancias virtuales Linux en AWS.

Seguridad Perimetral: Gestión de políticas de Firewalls (Security Groups) mediante el filtrado selectivo de puertos en entornos de red públicos.

Contenedorización: Virtualización a nivel de sistema operativo aislando servicios web mediante Docker Engines eficientes.

Sistemas de Nombres de Dominio (DNS): Despliegue, configuración y comprensión práctica de registros mutables de internet (A, CNAME) para la traducción de IPs a dominios comprensibles.
