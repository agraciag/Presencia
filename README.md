# Presencia

Sistema de telepresencia familiar para mantener presencia visual diaria entre España y México.

Un Intel NUC conectado a una TV en México se une automáticamente a una sala Jitsi auto-alojada, permitiendo videollamadas siempre activas sin interacción técnica del lado de México.

## Arquitectura

```
┌─────────────┐       ┌──────────────────┐       ┌─────────────┐
│  España     │       │  VPS (Jitsi)     │       │  México     │
│  Laptop/PC  │◄─────►│  Docker Compose  │◄─────►│  Intel NUC  │
│  + Webcam   │       │  NYC / Montreal  │       │  + TV + Cam │
└─────────────┘       └──────────────────┘       └─────────────┘
                              ▲
                              │ Tailscale
                              ▼
                      ┌──────────────────┐
                      │  Monitoreo       │
                      │  Telegram Bot    │
                      └──────────────────┘
```

## Componentes

| Directorio | Descripción |
|-----------|-------------|
| `server/` | Stack Jitsi Meet (Docker Compose) para el VPS |
| `nuc/base/` | Setup base: Ubuntu, Tailscale, SSH, firewall |
| `nuc/telepresence/` | Chromium kiosk + HDMI-CEC para auto-join Jitsi |
| `nuc/resilience/` | Watchdog multi-nivel, health checks, Tasmota |
| `nuc/media/` | Modo Kodi para fines de semana + switching automático |
| `nuc/monitoring/` | Notificaciones Telegram + reportes de salud |

## Requisitos

### Servidor (VPS)
- 2 vCPU, 4 GB RAM
- Docker + Docker Compose
- Dominio con DNS apuntando al VPS
- Datacenter entre España y México (Ashburn, NYC, Montreal)

### NUC (México)
- Intel NUC con Ubuntu LTS
- Webcam USB
- TV con HDMI (+ adaptador Pulse-Eight USB-CEC si el NUC no tiene CEC nativo)
- Conexión a internet estable
- Smart plug Tasmota (para power cycle remoto)

### Red
- Tailscale instalado en NUC y en dispositivo de administración en España

## Quick Start

### 1. Desplegar servidor Jitsi
```bash
# En el VPS
cd server/
cp .env.example .env
./gen-passwords.sh    # Genera passwords y actualiza .env
# Editar .env con tu dominio y email
docker compose up -d
```

### 2. Configurar NUC
```bash
# En el NUC (con acceso físico inicial)
cd nuc/
cp config/presencia.conf.example config/presencia.conf
# Editar presencia.conf con tus valores
sudo ./install.sh
```

### 3. Verificar
- TV se enciende automáticamente
- Chromium abre Jitsi en pantalla completa
- Video y audio funcionan
- Desde España, unirse a la misma sala Jitsi

## Modos de Operación

- **Telepresencia** (lunes a viernes): Chromium kiosk con Jitsi auto-join
- **Media** (fines de semana): Kodi para contenido multimedia

El switching es automático vía cron, configurable en `nuc/media/presencia-mode-cron`.

## Administración Remota

Todo se administra desde España vía Tailscale:
```bash
# SSH al NUC
ssh presencia@<tailscale-ip>

# Ver estado
sudo /opt/presencia/presencia-health.sh

# Cambiar modo manualmente
sudo /opt/presencia/presencia-mode-switch.sh media
sudo /opt/presencia/presencia-mode-switch.sh telepresence

# Power cycle de emergencia (desde España, vía Tasmota)
./nuc/resilience/tasmota-power-cycle.sh
```

## Documentación

- [Arquitectura](docs/architecture.md)
- [Runbook de operaciones](docs/runbook.md)
- [Troubleshooting](docs/troubleshooting.md)
