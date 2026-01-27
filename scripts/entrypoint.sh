#!/bin/bash
set -e

echo "=============================================="
echo " Clawdbot Desktop Worker - Selkies-GStreamer"
echo "=============================================="

# Create runtime directories
mkdir -p /tmp/runtime-developer
chmod 700 /tmp/runtime-developer
chown developer:developer /tmp/runtime-developer

# Ensure volumes are owned by developer
chown -R developer:developer ${CLAWDBOT_HOME} ${WORKSPACE} 2>/dev/null || true

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

echo ""
echo "Streaming Configuration:"
echo "  Encoder: ${SELKIES_ENCODER}"
echo "  Framerate: ${SELKIES_FRAMERATE:-60} fps"
echo "  Bitrate: ${SELKIES_VIDEO_BITRATE:-8000} kbps"
echo "  Resolution: auto (resizable)"
echo ""

# Start supervisord
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
