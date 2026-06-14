# Despliegue de Infraestructura Cloud con Docker y AWS EC2

Proyecto de despliegue de un servidor web sobre infraestructura cloud real, con seguridad multicapa y proxy inverso. El sitio está disponible en producción en [midominioweb.xyz](https://midominioweb.xyz/).

## Arquitectura

```
                         INTERNET
                            │
                            ▼
                    ┌───────────────┐
                    │  Cloudflare   │  ← Proxy inverso + WAF + SSL/TLS
                    │  (CDN / WAF)  │    Oculta IP de origen
                    └───────┬───────┘
                            │ HTTPS → HTTP (modo Flexible)
                            ▼
               ┌────────────────────────┐
               │      AWS EC2           │
               │   Ubuntu 22.04 LTS     │
               │                        │
               │  ┌──────────────────┐  │
               │  │   UFW Firewall   │  │  ← Solo IPs de Cloudflare en :80
               │  └────────┬─────────┘  │    SSH abierto en :22
               │           │            │
               │  ┌────────▼─────────┐  │
               │  │  AWS Security    │  │  ← Filtro a nivel de red (VPC)
               │  │     Groups       │  │
               │  └────────┬─────────┘  │
               │           │            │
               │  ┌────────▼─────────┐  │
               │  │ Docker: nginx    │  │  ← Servidor web en contenedor
               │  │   (alpine)  :80  │  │    Volumen persistente para web/
               │  └──────────────────┘  │
               └────────────────────────┘
```

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| DNS / Proxy / WAF | Cloudflare |
| Cloud | AWS EC2 (t2.micro, Ubuntu 22.04) |
| Firewall host | UFW (con reglas iptables subyacentes) |
| Firewall red | AWS Security Groups |
| Contenedor | Docker (nginx:alpine) |
| Orquestación | Docker Compose |

## Estructura del repositorio

```
.
├── docker-compose.yml     # Definición del servicio Docker
├── setup.sh               # Script de instalación y despliegue desde cero
├── nginx/
│   └── nginx.conf         # Configuración de Nginx con cabeceras de seguridad
│                          # y restricción de IPs a Cloudflare
└── web/
    └── index.html         # Contenido del sitio web
```

## Despliegue

### Requisitos previos
- Instancia EC2 con Ubuntu 22.04 LTS
- Dominio con zona DNS gestionada en Cloudflare
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

# Actualizar contenido web (sin reiniciar)
# Editar archivos en web/ — el volumen se refleja automáticamente
```

## Capas de seguridad

### 1. Cloudflare (perímetro)
- Proxy inverso que oculta la IP real del servidor
- SSL/TLS en modo Flexible (HTTPS entre cliente y Cloudflare)
- WAF básico activo en plan gratuito
- Protección DDoS integrada

> **Limitación conocida:** El modo Flexible cifra solo el tramo cliente→Cloudflare. El tramo Cloudflare→servidor va en HTTP. El siguiente paso sería modo **Full (Strict)** con certificado en el servidor (Let's Encrypt).

### 2. UFW (host)
- Política por defecto: `deny incoming`
- Puerto 22 abierto para SSH
- Puerto 80 restringido exclusivamente a rangos IP de Cloudflare

### 3. AWS Security Groups (red)
- Puerto 22: SSH
- Puerto 80: HTTP (tráfico de Cloudflare)
- Todo lo demás: denegado por defecto

### 4. Nginx
- `server_tokens off` — oculta versión del servidor
- Cabeceras de seguridad: `X-Frame-Options`, `X-Content-Type-Options`
- Acceso a archivos ocultos (`.env`, `.git`) denegado
- Restricción de IPs de Cloudflare a nivel de servidor web

## Resolución de problemas durante el proyecto

### Error 521 (Web server is down)
Cloudflare no podía conectar con el servidor. Causas investigadas:
- UFW bloqueaba las IPs de Cloudflare → solucionado añadiendo reglas por rango CIDR
- El contenedor no estaba escuchando en `0.0.0.0:80` sino solo en `127.0.0.1:80` → corregido en la configuración del puerto en Docker

### Error 522 (Connection timed out)
El paquete llegaba a la instancia pero no recibía respuesta. Causa: reglas de `iptables` residuales que descartaban el tráfico antes de que UFW lo procesara → solucionado con `iptables -F` y reinicio de UFW.

## Mejoras futuras

- [ ] SSL/TLS modo Full (Strict) con Let's Encrypt en el servidor
- [ ] Pipeline CI/CD con GitHub Actions para despliegue automático al hacer push
- [ ] Monitorización con Prometheus + Grafana
- [ ] Gestión de secretos con AWS Secrets Manager o Variables de entorno cifradas
