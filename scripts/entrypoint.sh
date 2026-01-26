#!/usr/bin/env bash
set -e

# Default VNC password if not set
VNC_PASSWORD="${VNC_PASSWORD:-clawdbot}"

# Ensure runtime dirs
mkdir -p /run/user/1000
chown -R ${USER}:${USER} /run/user/1000

# Set up VNC password
sudo -u ${USER} mkdir -p /home/${USER}/.vnc
echo "${VNC_PASSWORD}" | sudo -u ${USER} vncpasswd -f > /home/${USER}/.vnc/passwd
chmod 600 /home/${USER}/.vnc/passwd
chown ${USER}:${USER} /home/${USER}/.vnc/passwd

# Start supervisord to run:
# - GNOME session on :1
# - TigerVNC on :1
# - noVNC/websockify on 6080
# - Clawdbot gateway
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
