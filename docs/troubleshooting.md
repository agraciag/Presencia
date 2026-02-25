# Troubleshooting - Presencia

## Problemas Comunes

### "Chromium didn't shut down correctly" dialog
**Causa:** Chromium no se cerró limpiamente y muestra un dialog de restauración.

**Solución:** El script `presencia-kiosk.sh` limpia los crash flags automáticamente. Si persiste:
```bash
# Limpiar manualmente
find ~/.config/chromium -name "Preferences" -exec \
    sed -i 's/"exited_cleanly":false/"exited_cleanly":true/g; s/"exit_type":"Crashed"/"exit_type":"Normal"/g' {} +
systemctl --user restart presencia-kiosk
```

### Chromium consume demasiada memoria
**Causa:** Memory leak en sesiones largas de WebRTC.

**Mitigación:**
- El servicio systemd tiene `MemoryMax=2G` que mata Chromium si excede el límite (se reinicia automáticamente).
- El watchdog hace refresh preventivo cada 6 horas.
- Para forzar un refresh:
  ```bash
  DISPLAY=:0 xdotool key F5
  ```

### TV no enciende automáticamente (CEC)
**Causa:** Muchos Intel NUC no tienen CEC nativo en su puerto HDMI.

**Solución:**
1. Verificar si CEC funciona: `echo "scan" | cec-client -s -d 1`
2. Si no hay dispositivos: necesitas un adaptador **Pulse-Eight USB-CEC** (~$35).
3. Con adaptador, verificar: `echo "pow 0" | cec-client -s -d 1`
4. Si CEC no es opción, la TV se puede encender manualmente. Chromium seguirá funcionando en background.

### No hay audio en la llamada
**Diagnóstico:**
```bash
# Ver dispositivos
/opt/presencia/telepresence/presencia-audio.sh status

# Verificar que PulseAudio corre
pulseaudio --check && echo "running" || echo "not running"

# Si no corre, iniciar
pulseaudio --start
```

**Causas comunes:**
- HDMI audio seleccionado pero no soportado por la TV → cambiar a salida analógica/USB
- PulseAudio no inició → `pulseaudio --start`
- Micrófono muteado → `pactl set-source-mute @DEFAULT_SOURCE@ 0`

### Jitsi muestra "Connecting..." indefinidamente
**Diagnóstico:**
```bash
# Verificar servidor
curl -I https://meet.example.com

# Verificar puertos
nc -zvu meet.example.com 10000  # JVB UDP
```

**Causas:**
- Puerto UDP 10000 bloqueado → verificar firewall del VPS
- JVB_ADVERTISE_IPS incorrecto → debe ser la IP pública del VPS
- SSL expirado → verificar Let's Encrypt: `docker compose logs web | grep -i cert`

### Tailscale desconectado
**Diagnóstico:**
```bash
tailscale status
sudo systemctl status tailscaled
```

**Solución:**
```bash
sudo systemctl restart tailscaled
# Si pide re-autenticación:
sudo tailscale up --ssh
```

### NUC no arranca al conectar corriente
**Causa:** La BIOS del NUC no está configurada para auto-power-on.

**Solución:** En BIOS del NUC:
1. `Power` → `After Power Failure` → `Power On`
2. Esto es necesario para que el Tasmota power cycle funcione.

### Display congelado (pantalla negra o freeze)
**Diagnóstico:**
```bash
# Desde SSH
DISPLAY=:0 xdpyinfo  # Si falla, el display está muerto

# Ver estado de lightdm
systemctl status lightdm
```

**Solución:**
```bash
sudo systemctl restart lightdm
# Esperar 15 segundos, Chromium se reiniciará automáticamente
```

### Watchdog no detecta problemas
**Verificar:**
```bash
# Timer activo?
systemctl status presencia-watchdog.timer

# Última ejecución?
journalctl -u presencia-watchdog.service --since "1 hour ago"

# Logs del watchdog
tail -30 /var/log/presencia/watchdog.log
```

### Notificaciones de Telegram no llegan
**Verificar:**
```bash
# Test manual
/opt/presencia/monitoring/presencia-notify.sh "Test message"

# Verificar config
grep TELEGRAM /opt/presencia/presencia.conf

# Test directo con curl
curl -s "https://api.telegram.org/bot<TOKEN>/getMe"
```

**Causas:**
- Token del bot incorrecto
- Chat ID incorrecto (usar @userinfobot en Telegram para obtener tu chat ID)
- Bot no fue iniciado (enviar `/start` al bot en Telegram)

## Logs Importantes

| Log | Ubicación | Descripción |
|-----|-----------|-------------|
| Kiosk | `/var/log/presencia/kiosk.log` | Stdout/stderr de Chromium |
| Watchdog | `/var/log/presencia/watchdog.log` | Resultados de health checks |
| Mode switch | `/var/log/presencia/mode-switch.log` | Cambios de modo |
| Monitor | `/var/log/presencia/monitor.log` | Reportes periódicos |
| System | `journalctl -u presencia-*` | Todos los servicios systemd |

## Comandos Útiles de Diagnóstico

```bash
# Estado completo
sudo /opt/presencia/presencia-health.sh

# Procesos de Chromium y su memoria
ps aux | grep chromium

# Uso de red en tiempo real
sudo iftop -i eth0

# Webcam info
v4l2-ctl --list-devices
v4l2-ctl --device=/dev/video0 --all

# CEC debug
echo "scan" | cec-client -s -d 4

# Servicios systemd del usuario
systemctl --user list-units 'presencia-*'

# Timers del sistema
systemctl list-timers 'presencia-*'
```
