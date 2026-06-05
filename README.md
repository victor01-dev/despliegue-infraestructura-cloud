Documentación de Despliegue: Servidor Web en Docker (AWS EC2) con Seguridad Perimetral en Cloudflare

Este documento detalla los pasos técnicos seguidos para el aprovisionamiento, contenedorización y securización perimetral de un sitio web personalizado. La arquitectura final garantiza alta disponibilidad, aislamiento de procesos mediante contenedores y mitigación de amenazas a través de un proxy inverso con cifrado SSL/TLS.

🏛️ Diseño de la Arquitectura de Red y Seguridad

El flujo de tráfico de la infraestructura se distribuye en varias capas independientes que trabajan de forma coordinada. En primer lugar, la capa de resolución y proxy controlada por Cloudflare actúa como la primera línea de defensa de la infraestructura. Esta capa recibe las peticiones de los clientes a través del protocolo seguro HTTPS por el puerto 443, oculta la dirección IP pública real de nuestro servidor en la nube y reenvía el tráfico hacia el origen. 

En segundo lugar, se encuentra el cortafuegos perimetral gestionado mediante los AWS Security Groups, encargado de filtrar los accesos a nivel de red externa en la nube de Amazon, permitiendo conexiones entrantes únicamente en los puertos parametrizados. Tras superar esta barrera, el tráfico llega al cortafuegos del sistema operativo a través del servicio UFW de Linux, el cual controla las interfaces de red internas de la máquina virtual antes de derivar los paquetes a los sockets de destino. 

Por último, se sitúa la capa de aislamiento y persistencia gobernada por Docker Engine, un motor de virtualización que corre el servidor Nginx de forma totalmente aislada y acoplada a un volumen local del sistema de archivos mediante un Bind Mount.

🛠️ Fase 1: Conexión Inicial y Preparación del Host

En primer lugar, se configuran las credenciales SSH en la máquina local para establecer un túnel cifrado hacia la instancia virtual de AWS EC2, aplicando restricciones estrictas de lectura sobre la clave privada:

chmod 400 accesoawslinuxserver.pem
ssh -i "accesoawslinuxserver.pem" ubuntu@18.175.209.144

🛠️ Fase 2: Aprovisionamiento del Entorno Docker

Una vez dentro de la máquina virtual con Ubuntu Server, se realiza el mantenimiento del sistema operativo actualizando los repositorios de firmas y los paquetes de software. Posteriormente, se procede con la instalación del motor de contenedores Docker, la inicialización de su demonio y la asignación del usuario actual al grupo de seguridad de Docker para permitir la administración del entorno sin necesidad de anteponer el comando sudo de forma redundante:

sudo apt update && sudo apt upgrade -y

sudo apt install docker.io -y

sudo systemctl start docker

sudo systemctl enable docker

sudo usermod -aG docker ubuntu

exit

(Nota: Tras la ejecución del comando exit, se efectúa una nueva reconexión por SSH hacia la máquina para que la terminal del usuario herede correctamente los privilegios del nuevo grupo de Docker recién asignado).

🛠️ Fase 3: Persistencia y Despliegue del Contenedor Web

Se genera un directorio dedicado en el espacio de usuario del host para albergar de forma persistente los ficheros que compondrán el sitio web. A través del editor de texto del terminal, se define la estructura y estilos CSS del index.html. Una vez preparados los datos de origen, se inicializa el contenedor Nginx en segundo plano mediante el modo daemon, enlazando el puerto 80 del host con el del contenedor y montando de forma síncrona el volumen local en caliente dentro de la ruta por defecto que utiliza el servidor web para despachar contenido:

mkdir sitio-web && cd sitio-web

nano index.html

docker run -d -p 80:80 --name mi-web -v $(pwd):/usr/share/nginx/html nginx

Para verificar de manera local que el servidor responde de forma correcta dentro de la propia máquina y comprobar el estado de las cabeceras HTTP que despacha el contenedor, se realiza una petición interna de bucle de retorno:

curl -I http://localhost

🛠️ Fase 4: Apertura de Cortafuegos y Resolución de Conflictos

Durante el despliegue se identificaron dos niveles de cortafuegos restrictivos aplicados por defecto que denegaban las peticiones entrantes del proxy inverso (manifestándose como Errores 521 y 522 en los clientes). Para subsanar esto, se aplicaron medidas de mitigación tanto en las reglas perimetrales de AWS como en las tablas internas del kernel de Linux. En primer lugar, se ejecutó una limpieza completa de las cadenas de filtrado de paquetes de red para eliminar cualquier descarte intermitente que pudiese interferir entre la interfaz de red pública de AWS y el puente virtual de comunicación de Docker:

sudo iptables -F

En segundo lugar, se gestionó el estado del firewall nativo del sistema operativo Ubuntu (UFW). Dado que la seguridad perimetral a gran escala está completamente delegada y controlada en los paneles de AWS Security Groups, se procedió a habilitar explícitamente el socket TCP del puerto web y a deshabilitar el servicio interno para evitar solapamientos y bloqueos de tiempo de espera hacia Cloudflare:

sudo ufw allow 80/tcp

sudo ufw disable

🛠️ Fase 5: Configuración DNS y SSL Perimetral

Finalmente, la gestión de la zona DNS del dominio se migró desde el registrador original hacia la infraestructura global de Cloudflare para completar el flujo de enrutamiento y seguridad. Los pasos realizados incluyeron la delegación completa de los servidores de nombres autoritativos, introduciendo las direcciones maestras provistas por la plataforma en el panel de control del dominio:

kehlani.ns.cloudflare.com

neil.ns.cloudflare.com

Posteriormente, se dio de alta un registro maestro de tipo A asignando el nombre del dominio principal hacia la dirección IP pública fija del servidor cloud de Amazon Web Services (18.175.209.144), manteniendo el estado de Proxy (Nube Naranja) activado de forma permanente. Para concluir el flujo, se parametrizó la directiva de cifrado SSL/TLS dentro de Cloudflare en modo Flexible. Esta configuración establece un canal de cifrado asimétrico seguro mediante HTTPS entre el navegador del usuario y el nodo de Cloudflare por el puerto 443, mientras que Cloudflare realiza la traducción y entrega de datos hacia la infraestructura de AWS a través del puerto 80 estándar, logrando compatibilidad directa con el contenedor Nginx sin necesidad de instalar certificados locales en la instancia.

<img width="1083" height="257" alt="image" src="https://github.com/user-attachments/assets/18916d6f-2dae-4933-a0ea-1ad214efdedb" />

