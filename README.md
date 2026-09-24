# Despliegue de Infraestructura Cloud con Docker y AWS EC2

Proyecto de despliegue de un servidor web sobre infraestructura cloud real, con seguridad multicapa, proxy inverso y cifrado HTTPS extremo a extremo. El sitio está disponible en producción en https://victor01-dev.github.io/despliegue-infraestructura-cloud/.

## Arquitectura

```
                         INTERNET
                            │
                            ▼
                    ┌───────────────┐
                    │  Cloudflare   │  ← Proxy inverso + WAF + SSL/TLS
                    │  (CDN / WAF)  │    Oculta IP de origen
                    └───────┬───────┘
                            │ HTTPS (Origin CA — cifrado extremo a extremo)
                            ▼
               ┌────────────────────────┐
               │      AWS EC2           │
               │   Ubuntu 22.04 LTS     │
               │                        │
               │  ┌──────────────────┐  │
               │  │   UFW Firewall   │  │  ← Solo IPs de Cloudflare en :80/:443
               │  └────────┬─────────┘  │    SSH abierto en :22
               │           │            │
               │  ┌────────▼─────────┐  │
               │  │  AWS Security    │  │  ← Filtro a nivel de red (VPC)
               │  │     Groups       │  │
               │  └────────┬─────────┘  │
               │           │            │
               │  ┌────────▼─────────┐  │
               │  │ Docker: nginx    │  │  ← :80 redirige a :443
               │  │   (alpine)       │  │    Certificado Origin CA montado
               │  │  :80 → :443 ssl  │  │    en /etc/nginx/ssl/
               │  └──────────────────┘  │
               └────────────────────────┘
```

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| DNS / Proxy / WAF | Cloudflare |
| Certificados SSL | Cloudflare Origin CA |
| Cloud | AWS EC2 (t2.micro, Ubuntu 22.04) |
| Firewall host | UFW |
| Firewall red | AWS Security Groups |
| Contenedor | Docker (nginx:alpine) |
| Orquestación | Docker Compose |

## Estructura del repositorio

```
.
├── docker-compose.yml     # Definición del servicio Docker (puertos 80 y 443)
├── setup.sh               # Script de instalación y despliegue desde cero
├── nginx/
│   └── nginx.conf         # Configuración de Nginx con SSL y redirección HTTP→HTTPS
└── web/
    └── index.html         # Contenido del sitio web
```

## Configuración de Nginx

El servidor escucha en los puertos 80 y 443. Todo el tráfico HTTP es redirigido automáticamente a HTTPS mediante un `301`. El cifrado usa los certificados Origin CA de Cloudflare montados dentro del contenedor.

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name localhost;
    # Redirigir todo el tráfico HTTP a HTTPS automáticamente
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name localhost;

    # Certificados Origin CA de Cloudflare (montados en el contenedor)
    ssl_certificate     /etc/nginx/ssl/cloudflare.pem;
    ssl_certificate_key /etc/nginx/ssl/cloudflare.key;

    # Protocolos y cifrados seguros
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        root  /usr/share/nginx/html;
        index index.html index.htm;
    }

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
```

## Despliegue

### Requisitos previos
- Instancia EC2 con Ubuntu 22.04 LTS
- Dominio con zona DNS gestionada en Cloudflare
- Certificado Origin CA generado en Cloudflare y guardado en `/etc/ssl/` en la EC2
- Acceso SSH a la instancia

### Instalación automática

```bash
git clone https://github.com/victor01-dev/despliegue-infraestructura-cloud.git
cd despliegue-infraestructura-cloud
chmod +x setup.sh
./setup.sh
```

El script instala Docker, configura UFW con las IPs de Cloudflare, clona el repo y levanta el contenedor.

### Gestión del contenedor

```bash
# Arrancar
docker compose up -d

# Ver estado
docker compose ps

# Ver logs en tiempo real
docker compose logs -f

# Parar
docker compose down
```

## Capas de seguridad

### 1. Cloudflare (perímetro)
- Proxy inverso que oculta la IP real del servidor
- SSL/TLS en modo **Full (Strict)** — cifrado extremo a extremo con certificado Origin CA
- WAF básico activo en plan gratuito
- Protección DDoS integrada

### 2. Certificado Origin CA de Cloudflare
- Certificado oficial emitido por Cloudflare para el tramo Cloudflare → servidor
- Instalado en `/etc/ssl/` en la EC2 y montado dentro del contenedor Docker
- El tráfico viaja cifrado en **todo el recorrido**: cliente → Cloudflare → servidor

### 3. UFW (host)
- Política por defecto: `deny incoming`
- Puerto 22 abierto para SSH
- Puertos 80 y 443 restringidos exclusivamente a rangos IP de Cloudflare

### 4. AWS Security Groups (red)
- Puerto 22: SSH
- Puerto 80: HTTP (redirige a HTTPS)
- Puerto 443: HTTPS
- Todo lo demás: denegado por defecto

### 5. Nginx
- Redirección automática HTTP → HTTPS (código 301)
- TLS 1.2 y 1.3 únicamente
- Cifrados débiles desactivados (`!aNULL:!MD5`)

## Resolución de problemas durante el proyecto

### Error 521 (Web server is down)
Cloudflare no podía conectar con el servidor. Causas investigadas:
- UFW bloqueaba las IPs de Cloudflare → solucionado añadiendo reglas por rango CIDR
- El contenedor no estaba escuchando en `0.0.0.0:80` → corregido en la configuración de puertos de Docker

### Error 522 (Connection timed out)
El paquete llegaba a la instancia pero no recibía respuesta. Causa: reglas de `iptables` residuales que descartaban el tráfico antes de que UFW lo procesara → solucionado con `iptables -F` y reinicio de UFW.
