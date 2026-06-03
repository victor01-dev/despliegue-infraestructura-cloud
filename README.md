Despliegue de Infraestructura Cloud: Servidor Web Personalizado sobre Docker en AWS EC2, Securizado con Cloudflare

Este repositorio contiene la documentación técnica y la configuración necesarias para el despliegue de un servidor web Nginx altamente disponible y contenedorizado utilizando Docker sobre una instancia de computación virtualizada Amazon EC2 (Elastic Compute Cloud) de Amazon Web Services (AWS). El proyecto cuenta con un sitio web personalizado en modo oscuro mediante el uso de volúmenes persistentes y está completamente securizado mediante el proxy inverso y certificado SSL de Cloudflare.

Este proyecto ha sido desarrollado como una práctica avanzada en administración de sistemas cloud.

🏛️ Arquitectura del Sistema
El despliegue consta de un modelo de infraestructura en la nube estructurado en capas de red, rendimiento y seguridad:

Host de Computación: Instancia de AWS EC2 de tipo t2.micro corriendo el sistema operativo Ubuntu Server Linux.

Capa de Aislamiento: Docker Engine encargado de la descarga de la imagen oficial y aislamiento en un microentorno mutable.

Persistencia de Datos (Bind Mount): Enlace directo desde el espacio de usuario del host hacia el directorio de publicación del contenedor para servir contenido propio en caliente.

Servidor Web: Nginx actuando como el backend principal encargado de despachar peticiones de socket.

Capa de Seguridad Perimetral y SSL: Proxy Inverso de Cloudflare encargado de mitigar amenazas, ocultar la IP real de AWS y forzar el cifrado de extremo a extremo mediante el protocolo HTTPS (Puerto 443).

Capa DNS Extensiva: Delegación de registros de zona desde Namecheap hacia los servidores de nombres maestros de Cloudflare.

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

Nota: Tras la asignación al grupo docker, se procedió a realizar un exit de la terminal y una reconexión por SSH para refrescar los privilegios del usuario.

Paso 3: Estructuración del Sitio Web Personalizado
Para evitar servir la página por defecto de Nginx, se estructuró un directorio local en el host de AWS y se generó un fichero index.html a medida utilizando el editor nano, aplicando estilos CSS personalizados para implementar una interfaz en modo oscuro:

ubuntu@ip-172-31-3-168:~$ mkdir sitio-web

ubuntu@ip-172-31-3-168:~$ cd sitio-web

ubuntu@ip-172-31-3-168:~/sitio-web$ nano index.html

Paso 4: Orquestación del Contenedor Web con Persistencia
Se ejecutó de manera aislada y desvinculada (detached mode) el servidor web vinculando el volumen del sistema de archivos mediante el flag -v para mapear nuestra carpeta local con la raíz de Nginx:

ubuntu@ip-172-31-3-168:~/sitio-web$ docker run -d -p 80:80 --name mi-web -v $(pwd):/usr/share/nginx/html nginx

Explicación técnica de modificadores:

-d: Ejecución en segundo plano permanente (Daemon).

-p 80:80: Redireccionamiento del puerto 80 expuesto en la interfaz de la instancia hacia el puerto 80 del contenedor.

-v $(pwd):/usr/share/nginx/html: Mapeo síncrono del directorio actual del servidor AWS hacia la ruta de lectura de Nginx, permitiendo modificaciones en caliente sin necesidad de reiniciar el contenedor.

Paso 5: Delegación de DNS y Securización con Cloudflare
Se dio de alta el dominio en la red de Cloudflare bajo el plan Free.

Se configuraron los registros en la zona DNS apuntando a la infraestructura Cloud:

Registro A (Dominio Raíz): @ mapeado a 18.175.209.144 (Con estado Proxied activado).

Registro CNAME (Alias de Red): www mapeado a midominioweb.xyz (Con estado Proxied activado).

Se modificaron los Nameservers en el panel de Namecheap, sustituyéndolos por las DNS autoritativas de Cloudflare para delegar la gestión del tráfico.

Se activó la directiva Always Use HTTPS y el cifrado Flexible SSL/TLS en Cloudflare para mitigar conexiones inseguras y forzar el candado SSL en los clientes.

📈 Evidencias del Despliegue y Pruebas de Verificación
A continuación se adjuntan las trazas de comandos y capturas que prueban el funcionamiento e integración de cada elemento del flujo tecnológico:

1. Estado de la Orquestación de Docker
Verificación del estado operativo continuo mediante el comando de control docker ps:

ubuntu@ip-172-31-3-168:~$ docker ps

CONTAINER ID   IMAGE     COMMAND                  CREATED         STATUS         PORTS                               NAMES
42774cad898a   nginx     "/docker-entrypoint.…"   2 minutes ago   Up 2 minutes   0.0.0.0:80->80/tcp, :::80->80/tcp   mi-web

2. Resolución DNS y Carga de la Web en Modo Oscuro con HTTPS
Acceso final exitoso mediante resolución de nombres fully qualified domain name (FQDN): https://midominioweb.xyz utilizando el cifrado SSL de Cloudflare.

(Nota: Aquí puedes arrastrar también tu otra captura en modo oscuro para que se vean ambas pruebas juntas).

🎓 Conclusiones (Competencias Adquiridas)

Administración Cloud: Creación, configuración y gestión del ciclo de vida de instancias virtuales Linux en AWS EC2.

Seguridad Perimetral y Cifrado: Implementación de políticas de protección de datos, mitigación de ataques y despliegue de certificados SSL/TLS mediante capas intermedias de seguridad (Cloudflare Proxied).

Contenedorización Avanzada: Virtualización a nivel de sistema operativo acoplando almacenamiento persistente local a través de Bind Mounts en Docker.

Sistemas de Nombres de Dominio (DNS): Despliegue, migración de zonas autoritativas y comprensión práctica de registros maestros de internet (A, CNAME) para entornos de producción serios.
