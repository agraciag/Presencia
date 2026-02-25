#!/usr/bin/env bash
# Presencia - Base system setup for Intel NUC
# Installs essential packages, configures timezone, disables suspend/sleep.
set -euo pipefail

PRESENCIA_USER="${PRESENCIA_USER:-presencia}"

echo "── Base System Setup ──"

# ─── Essential packages ─────────────────────────────────────────
echo "Installing packages..."
apt-get update -qq
apt-get install -y -qq \
    chromium-browser \
    cec-utils \
    xdotool \
    unclutter \
    pulseaudio \
    alsa-utils \
    curl \
    jq \
    net-tools \
    htop \
    v4l-utils \
    xinput \
    xdg-utils \
    x11-xserver-utils \
    lightdm \
    openbox \
    2>/dev/null

# ─── Timezone ───────────────────────────────────────────────────
echo "Setting timezone to America/Mexico_City..."
timedatectl set-timezone America/Mexico_City

# ─── Disable suspend/sleep/hibernate ───────────────────────────
echo "Disabling suspend and sleep..."
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Disable screen blanking via logind
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/presencia.conf << 'LOGIND'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
IdleAction=ignore
LOGIND

# ─── Auto-login ────────────────────────────────────────────────
echo "Configuring auto-login for ${PRESENCIA_USER}..."
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-presencia.conf << AUTOLOGIN
[Seat:*]
autologin-user=${PRESENCIA_USER}
autologin-user-timeout=0
user-session=openbox
AUTOLOGIN

# ─── Openbox autostart (launches user services) ────────────────
PRESENCIA_HOME="$(eval echo ~${PRESENCIA_USER})"
OPENBOX_DIR="${PRESENCIA_HOME}/.config/openbox"
mkdir -p "$OPENBOX_DIR"

cat > "${OPENBOX_DIR}/autostart" << 'OPENBOX_AUTO'
# Presencia - Openbox autostart
# Disable screen saver and DPMS
xset s off
xset -dpms
xset s noblank

# Hide mouse cursor after 3 seconds of inactivity
unclutter -idle 3 -root &
OPENBOX_AUTO

chown -R "$PRESENCIA_USER":"$PRESENCIA_USER" "${PRESENCIA_HOME}/.config"

# ─── Disable automatic updates ─────────────────────────────────
echo "Disabling automatic updates..."
if [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
    sed -i 's/APT::Periodic::Update-Package-Lists "1"/APT::Periodic::Update-Package-Lists "0"/' \
        /etc/apt/apt.conf.d/20auto-upgrades
    sed -i 's/APT::Periodic::Unattended-Upgrade "1"/APT::Periodic::Unattended-Upgrade "0"/' \
        /etc/apt/apt.conf.d/20auto-upgrades
fi

echo "Base setup complete."
