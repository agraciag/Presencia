# Arquitectura - Presencia

## Diagrama General

```
┌─────────────────┐         ┌────────────────────────┐         ┌──────────────────────┐
│   ESPAÑA        │         │   VPS (Jitsi Meet)     │         │   MÉXICO             │
│                 │         │                        │         │                      │
│  Laptop/PC      │◄───────►│  Docker Compose:       │◄───────►│  Intel NUC           │
│  + Webcam       │  WebRTC │  - nginx (web)         │  WebRTC │  + USB Webcam        │
│  + Browser      │         │  - prosody (XMPP)      │         │  + TV (HDMI-CEC)     │
│                 │         │  - jicofo (focus)       │         │  + Tasmota plug      │
└────────┬────────┘         │  - jvb (videobridge)   │         └──────────┬───────────┘
         │                  └────────────────────────┘                    │
         │                                                                │
         │                  ┌────────────────────────┐                    │
         └──────────────────┤   Tailscale VPN        ├────────────────────┘
                            │   (mesh network)       │
                            └────────────────────────┘
```

## Flujo de Video

1. **NUC → Jitsi**: Chromium captura video de la webcam USB y audio del micrófono, los envía al JVB vía WebRTC.
2. **JVB relay**: El videobridge retransmite el stream. P2P está deshabilitado para mayor estabilidad en conexiones transcontinentales.
3. **Jitsi → España**: El browser en España recibe el stream del JVB.

## Componentes del NUC

```
┌─────────────────────────────────────────────────────┐
│  Intel NUC (Ubuntu LTS)                             │
│                                                     │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────┐  │
│  │ Openbox WM  │  │ Chromium     │  │ Kodi      │  │
│  │ (auto-login)│  │ (kiosk mode) │  │ (weekends)│  │
│  └──────┬──────┘  └──────┬───────┘  └─────┬─────┘  │
│         │                │                 │        │
│  ┌──────┴────────────────┴─────────────────┴─────┐  │
│  │              mode-switch.sh                    │  │
│  │  telepresence ←→ media                        │  │
│  └────────────────────────────────────────────────┘  │
│                                                     │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────┐  │
│  │ Watchdog    │  │ Monitor      │  │ CEC       │  │
│  │ (2 min)     │  │ (15 min)     │  │ (TV ctrl) │  │
│  └─────────────┘  └──────────────┘  └───────────┘  │
│                                                     │
│  ┌─────────────┐  ┌──────────────┐                  │
│  │ Tailscale   │  │ SSH (2222)   │                  │
│  │ (primary)   │  │ (backup)     │                  │
│  └─────────────┘  └──────────────┘                  │
└─────────────────────────────────────────────────────┘
```

## Jerarquía de Recuperación

```
Nivel 1: Chromium crash
    └─► systemd Restart=always (~10s)

Nivel 2: Jitsi desconecta / display freeze
    └─► Watchdog detecta → xdotool F5 / restart lightdm (~30-45s)

Nivel 3: Sistema no responde
    └─► Hardware watchdog iTCO_wdt → reboot (~90s)

Nivel 4: Kernel panic / total freeze
    └─► Tasmota power cycle desde España (~3 min)
```

## Decisiones Técnicas Clave

### P2P deshabilitado
Las conexiones P2P son inestables para llamadas largas transcontinentales. Forzar todo el tráfico por el JVB agrega un pequeño overhead de latencia pero aumenta significativamente la estabilidad.

### Chromium kiosk vs app nativa
Chromium con `--use-fake-ui-for-media-stream` permite auto-grant de permisos de cámara/micrófono sin interacción. Una app nativa WebRTC sería más eficiente pero requeriría desarrollo y mantenimiento significativo.

### systemd user services
Los servicios de Chromium y CEC corren como servicios de usuario (no root) por seguridad. `loginctl enable-linger` permite que persistan sin sesión activa.

### Tailscale como acceso primario
Tailscale SSH no depende de la configuración SSH local y funciona aunque el firewall bloquee todo tráfico entrante. El SSH tradicional en puerto 2222 es solo backup.

### Refresh preventivo cada 6h
Chromium tiende a consumir más memoria en sesiones largas. Un refresh periódico (F5) mantiene el uso de memoria estable sin interrumpir la llamada por más de unos segundos.
