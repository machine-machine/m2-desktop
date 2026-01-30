#!/bin/bash
# =============================================================================
# M2 Desktop - Unified Entrypoint
# Handles initialization for all variants (noVNC, Guacamole, Selkies)
# =============================================================================
set -e

M2_VARIANT="${M2_VARIANT:-guacamole}"
M2_HOME="${M2_HOME:-/m2_home}"
WORKSPACE="${WORKSPACE:-/workspace}"

echo "=============================================="
echo " M2 Desktop Worker - ${M2_VARIANT} variant"
echo "=============================================="

# =============================================================================
# Common Initialization
# =============================================================================

# Create runtime directories
mkdir -p /tmp/runtime-developer
chmod 700 /tmp/runtime-developer
chown developer:developer /tmp/runtime-developer

# Create D-Bus socket directory
mkdir -p /var/run/dbus
chown messagebus:messagebus /var/run/dbus 2>/dev/null || chown root:root /var/run/dbus

# Ensure volumes are owned by developer
chown -R developer:developer ${M2_HOME} ${WORKSPACE} 2>/dev/null || true

# =============================================================================
# Persistent Desktop Config (survives container rebuilds)
# =============================================================================
DESKTOP_CONFIG="${M2_HOME}/desktop-config"
mkdir -p "${DESKTOP_CONFIG}"

# List of config directories to persist
PERSIST_CONFIGS=(
    "/home/developer/.config/xfce4:xfce4"
    "/home/developer/.config/plank:plank"
    "/home/developer/.config/autostart:autostart"
    "/home/developer/Desktop:Desktop"
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
# Persistent Flatpak Directory
# =============================================================================
export FLATPAK_USER_DIR="${M2_HOME}/flatpak"
mkdir -p "${FLATPAK_USER_DIR}"
chown -R developer:developer "${FLATPAK_USER_DIR}"

# Symlink developer's flatpak dir to persistent volume
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
# Variant-Specific Configuration
# =============================================================================
VNC_PASSWORD="${VNC_PASSWORD:-m2desktop}"

case "${M2_VARIANT}" in
    novnc)
        echo ""
        echo "Variant: noVNC (TigerVNC + websockify)"
        echo "=========================================="

        # Create VNC password for TigerVNC
        mkdir -p /home/developer/.vnc
        echo "${VNC_PASSWORD}" | vncpasswd -f > /home/developer/.vnc/passwd
        chmod 600 /home/developer/.vnc/passwd
        chown -R developer:developer /home/developer/.vnc

        echo "Authentication:"
        echo "  Username: developer"
        echo "  Password: [set from VNC_PASSWORD]"
        echo ""
        echo "Access:"
        echo "  noVNC: http://localhost:6080/vnc.html"
        echo "  M2 Gateway: ws://localhost:18789"
        echo ""
        ;;

    guacamole)
        echo ""
        echo "Variant: Guacamole (x11vnc + guacd + guacamole-lite)"
        echo "====================================================="

        # Create VNC password for x11vnc
        mkdir -p /tmp
        x11vnc -storepasswd "${VNC_PASSWORD}" /tmp/.vnc_passwd
        chmod 644 /tmp/.vnc_passwd

        # Export for guacamole-lite
        export GUAC_AUTH_ENABLED="${GUAC_AUTH_ENABLED:-true}"
        export GUAC_AUTH_USER="${GUAC_AUTH_USER:-developer}"
        export GUAC_AUTH_PASSWORD="${GUAC_AUTH_PASSWORD:-${VNC_PASSWORD}}"

        echo "Authentication:"
        echo "  Username: ${GUAC_AUTH_USER}"
        echo "  Password: [set from VNC_PASSWORD]"
        echo ""
        echo "Architecture:"
        echo "  Browser -> Guacamole-Lite (8080) -> guacd (4822) -> x11vnc (5900) -> Xorg :0"
        echo ""
        echo "Access:"
        echo "  Web: http://localhost:8080"
        echo "  M2 Gateway: ws://localhost:18789"
        echo ""
        echo "Multi-user: enabled (all users share same session)"
        echo ""
        ;;

    selkies)
        echo ""
        echo "Variant: Selkies-GStreamer (WebRTC)"
        echo "===================================="

        # GPU detection
        if nvidia-smi &>/dev/null; then
            export SELKIES_ENCODER="${SELKIES_ENCODER:-nvh264enc}"
            echo "GPU: NVIDIA detected, using hardware encoding (${SELKIES_ENCODER})"
        else
            export SELKIES_ENCODER="${SELKIES_ENCODER:-x264enc}"
            echo "GPU: None detected, using software encoding (${SELKIES_ENCODER})"
        fi

        export SELKIES_ENABLE_BASIC_AUTH="${SELKIES_ENABLE_BASIC_AUTH:-true}"

        echo ""
        echo "Authentication:"
        echo "  Username: developer (if basic auth enabled)"
        echo "  Password: [set from VNC_PASSWORD]"
        echo ""
        echo "Architecture:"
        echo "  Browser <-> Selkies-GStreamer (8080) <-> WebRTC <-> Xorg :0"
        echo ""
        echo "Access:"
        echo "  Web: http://localhost:8080"
        echo "  M2 Gateway: ws://localhost:18789"
        echo ""
        echo "NOTE: Single-user only (WebRTC is 1:1)"
        echo ""
        ;;

    *)
        echo "ERROR: Unknown M2_VARIANT: ${M2_VARIANT}"
        echo "Valid variants: novnc, guacamole, selkies"
        exit 1
        ;;
esac

# =============================================================================
# Start Supervisord
# =============================================================================
echo "Starting services via supervisord..."
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
