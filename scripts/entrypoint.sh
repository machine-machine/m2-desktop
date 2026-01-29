#!/bin/bash
set -e

echo "=============================================="
echo " Clawdbot Desktop Worker - Apache Guacamole"
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
# Initialize persistent desktop config (survives container rebuilds)
# =============================================================================
DESKTOP_CONFIG="${CLAWDBOT_HOME}/desktop-config"
mkdir -p "${DESKTOP_CONFIG}"

# List of config directories to persist
# Format: "source_in_container:name_in_persistent_storage"
PERSIST_CONFIGS=(
    "/home/developer/.config/xfce4:xfce4"
    "/home/developer/.config/plank:plank"
    "/home/developer/.config/autostart:autostart"
)

for config_pair in "${PERSIST_CONFIGS[@]}"; do
    SRC="${config_pair%%:*}"
    NAME="${config_pair##*:}"
    PERSIST_DIR="${DESKTOP_CONFIG}/${NAME}"

    if [ ! -d "${PERSIST_DIR}" ]; then
        # First run: copy defaults from container to persistent storage
        echo "Initializing persistent ${NAME} config..."
        if [ -d "${SRC}" ]; then
            cp -a "${SRC}" "${PERSIST_DIR}"
        else
            mkdir -p "${PERSIST_DIR}"
        fi
    fi

    # Symlink container path to persistent storage
    rm -rf "${SRC}"
    mkdir -p "$(dirname "${SRC}")"
    ln -sf "${PERSIST_DIR}" "${SRC}"
    chown -h developer:developer "${SRC}"
done

chown -R developer:developer "${DESKTOP_CONFIG}"
echo "Desktop settings persistent at ${DESKTOP_CONFIG}"

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
# Configure VNC password for x11vnc
# =============================================================================
VNC_PASSWORD="${VNC_PASSWORD:-clawdbot}"
mkdir -p /tmp
x11vnc -storepasswd "${VNC_PASSWORD}" /tmp/.vnc_passwd
chmod 644 /tmp/.vnc_passwd

echo ""
echo "Authentication:"
echo "  Username: developer"
echo "  Password: [set from VNC_PASSWORD]"
echo ""

# =============================================================================
# Configure Guacamole environment
# =============================================================================
export GUAC_AUTH_ENABLED="${GUAC_AUTH_ENABLED:-true}"
export GUAC_AUTH_USER="${GUAC_AUTH_USER:-developer}"
export GUAC_AUTH_PASSWORD="${GUAC_AUTH_PASSWORD:-${VNC_PASSWORD}}"

echo "Remote Desktop Configuration (Guacamole):"
echo "  Web interface: port 8080"
echo "  Multi-user: enabled (all users share same session)"
echo "  VNC backend: x11vnc on port 5900"
echo "  Protocol: guacd on port 4822"
echo ""
echo "Architecture:"
echo "  Browser -> Guacamole-Lite (8080) -> guacd (4822) -> x11vnc (5900) -> Xorg :0"
echo ""

# Start supervisord
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
