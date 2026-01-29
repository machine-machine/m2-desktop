#!/bin/bash
set -e

echo "=============================================="
echo " Clawdbot Desktop Worker - Selkies-GStreamer"
echo "=============================================="

# Create runtime directories
mkdir -p /tmp/runtime-developer
chmod 700 /tmp/runtime-developer
chown developer:developer /tmp/runtime-developer

# Create D-Bus socket directory (required for dbus-daemon)
mkdir -p /var/run/dbus
chown messagebus:messagebus /var/run/dbus 2>/dev/null || chown root:root /var/run/dbus

# Ensure volumes are owned by developer
chown -R developer:developer ${CLAWDBOT_HOME} ${WORKSPACE} 2>/dev/null || true

# =============================================================================
# Initialize Flatpak user directory (persistent storage for apps)
# =============================================================================
export FLATPAK_USER_DIR="${CLAWDBOT_HOME}/flatpak"
mkdir -p "${FLATPAK_USER_DIR}"
chown -R developer:developer "${FLATPAK_USER_DIR}"

# Symlink developer's flatpak dir to persistent volume (for XFCE session)
# This ensures apps installed via Cargstore persist across container rebuilds
mkdir -p /home/developer/.local/share
rm -rf /home/developer/.local/share/flatpak
ln -sf "${FLATPAK_USER_DIR}" /home/developer/.local/share/flatpak
chown -h developer:developer /home/developer/.local/share/flatpak

# Add Flathub for user if not exists (first run)
if [ ! -d "${FLATPAK_USER_DIR}/repo" ]; then
    echo "Initializing Flatpak user installation..."
    su developer -c "flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo" || true
fi

# =============================================================================
# Register Cargstore as flatpak: URI handler
# =============================================================================
mkdir -p /home/developer/.config
cat > /home/developer/.config/mimeapps.list << 'EOF'
[Default Applications]
x-scheme-handler/flatpak=cargstore.desktop
EOF
chown -R developer:developer /home/developer/.config/mimeapps.list

# =============================================================================
# Map VNC_PASSWORD to Selkies auth (backwards compatibility)
# =============================================================================
export SELKIES_BASIC_AUTH_USER="${SELKIES_BASIC_AUTH_USER:-developer}"
export SELKIES_BASIC_AUTH_PASSWORD="${VNC_PASSWORD:-clawdbot}"

echo "Authentication:"
echo "  Username: ${SELKIES_BASIC_AUTH_USER}"
echo "  Password: [set from VNC_PASSWORD]"
echo ""

# =============================================================================
# Detect GPU and configure encoder
# =============================================================================
if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
    echo "✓ NVIDIA GPU detected:"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
    export SELKIES_ENCODER="${SELKIES_ENCODER:-nvh264enc}"
else
    echo "⚠ No NVIDIA GPU detected, using software encoding"
    export SELKIES_ENCODER="x264enc"
    export SELKIES_FRAMERATE="${SELKIES_FRAMERATE:-30}"
fi

# =============================================================================
# Configure ICE servers for WebRTC (STUN/TURN for NAT traversal)
# =============================================================================
# STUN helps discover public IPs, but TURN is required for relay when direct
# P2P connections fail (restrictive firewalls, symmetric NAT, etc.)
#
# Environment variables for TURN:
#   TURN_HOST     - TURN server hostname (e.g., turn.example.com)
#   TURN_PORT     - TURN server port (default: 3478)
#   TURN_USERNAME - TURN authentication username
#   TURN_PASSWORD - TURN authentication password
#
rm -f /tmp/rtc.json

# Build ICE servers JSON
ICE_SERVERS='{"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]}'

if [ -n "${TURN_HOST}" ]; then
    TURN_PORT="${TURN_PORT:-3478}"
    TURN_URLS="turn:${TURN_HOST}:${TURN_PORT}"
    TURNS_URLS="turns:${TURN_HOST}:${TURN_PORT}"

    if [ -n "${TURN_USERNAME}" ] && [ -n "${TURN_PASSWORD}" ]; then
        TURN_SERVER="{\"urls\": [\"${TURN_URLS}\", \"${TURNS_URLS}\"], \"username\": \"${TURN_USERNAME}\", \"credential\": \"${TURN_PASSWORD}\"}"
    else
        TURN_SERVER="{\"urls\": [\"${TURN_URLS}\", \"${TURNS_URLS}\"]}"
    fi
    ICE_SERVERS="${ICE_SERVERS}, ${TURN_SERVER}"
    echo "✓ TURN server configured: ${TURN_HOST}:${TURN_PORT}"
else
    echo "⚠ No TURN server configured (set TURN_HOST, TURN_USERNAME, TURN_PASSWORD)"
    echo "  External users behind restrictive NATs may not be able to connect"
fi

cat > /tmp/rtc.json << EOF
{
  "lifetimeDuration": "86400s",
  "iceServers": [
    ${ICE_SERVERS}
  ],
  "blockStatus": "NOT_BLOCKED",
  "iceTransportPolicy": "all"
}
EOF
chown developer:developer /tmp/rtc.json

echo ""
echo "Streaming Configuration:"
echo "  Encoder: ${SELKIES_ENCODER}"
echo "  Framerate: ${SELKIES_FRAMERATE:-60} fps"
echo "  Bitrate: ${SELKIES_VIDEO_BITRATE:-8000} kbps"
echo "  Resolution: auto (resizable)"
echo "  ICE: Google STUN + ${TURN_HOST:-'no TURN (add TURN_HOST env var)'}"
echo ""

# Start supervisord
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
