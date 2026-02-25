# Runbook de Operaciones - Presencia

## Operaciones Diarias

### Verificar estado del sistema
```bash
ssh presencia@<tailscale-ip>
sudo /opt/presencia/presencia-health.sh
```

### Ver logs recientes
```bash
# Watchdog
tail -50 /var/log/presencia/watchdog.log

# Kiosk
tail -50 /var/log/presencia/kiosk.log

# Mode switching
tail -20 /var/log/presencia/mode-switch.log

# Monitor
tail -20 /var/log/presencia/monitor.log
```

## Cambio de Modo Manual

```bash
# Cambiar a media (Kodi)
sudo /opt/presencia/media/presencia-mode-switch.sh media

# Cambiar a telepresencia (Jitsi)
sudo /opt/presencia/media/presencia-mode-switch.sh telepresence

# Ver modo actual
sudo /opt/presencia/media/presencia-mode-switch.sh status
```

## Restart de Servicios

### Reiniciar Chromium kiosk
```bash
systemctl --user restart presencia-kiosk
```

### Reiniciar watchdog
```bash
sudo systemctl restart presencia-watchdog.timer
```

### Reiniciar display manager
```bash
sudo systemctl restart lightdm
```

## Servidor Jitsi

### Ver estado
```bash
ssh user@vps
cd ~/presencia-server
docker compose ps
docker compose logs --tail=50
```

### Reiniciar servidor Jitsi
```bash
docker compose restart
```

### Actualizar Jitsi
```bash
./scripts/update-jitsi.sh
```

### Backup manual
```bash
./scripts/backup-jitsi.sh
```

## Recuperación de Emergencia

### NUC no responde vía SSH

1. **Esperar 5 minutos** - El watchdog puede recuperarlo automáticamente.
2. **Verificar Tailscale** - `tailscale ping <nuc-tailscale-ip>` desde España.
3. **Power cycle Tasmota**:
   ```bash
   ./nuc/resilience/tasmota-power-cycle.sh
   ```
4. **Si Tasmota no responde** - Llamar a alguien en México para desconectar y reconectar el NUC físicamente.

### Jitsi no carga en el NUC

1. Verificar que el servidor Jitsi está running:
   ```bash
   curl -I https://meet.example.com
   ```
2. Si el servidor está caído, reiniciarlo:
   ```bash
   ssh user@vps
   cd ~/presencia-server && docker compose up -d
   ```
3. Si el servidor está bien, forzar refresh en el NUC:
   ```bash
   ssh presencia@<tailscale-ip>
   DISPLAY=:0 xdotool key F5
   ```

### Sin audio

1. Verificar dispositivos de audio:
   ```bash
   /opt/presencia/telepresence/presencia-audio.sh status
   ```
2. Reconfigurar audio:
   ```bash
   /opt/presencia/telepresence/presencia-audio.sh setup
   ```
3. Test de audio:
   ```bash
   /opt/presencia/telepresence/presencia-audio.sh test
   ```

### Sin video (webcam)

1. Verificar que la webcam está conectada:
   ```bash
   ls -la /dev/video*
   v4l2-ctl --list-devices
   ```
2. Si no aparece, puede ser un problema USB. Reiniciar:
   ```bash
   sudo systemctl restart lightdm
   ```

## Mantenimiento Periódico

### Semanal
- Revisar logs por errores recurrentes
- Verificar uso de disco: `df -h`

### Mensual
- Actualizar paquetes del sistema (manual, via Tailscale):
  ```bash
  sudo apt update && sudo apt upgrade -y
  ```
- Actualizar Jitsi en el servidor:
  ```bash
  ./scripts/update-jitsi.sh
  ```
- Limpiar logs antiguos:
  ```bash
  find /var/log/presencia -name "*.log" -mtime +30 -delete
  ```

### Antes de un viaje
- Test completo: `sudo /opt/presencia/presencia-health.sh`
- Verificar que Tasmota es accesible desde España
- Verificar que Tailscale está estable
- Test de video/audio completo
