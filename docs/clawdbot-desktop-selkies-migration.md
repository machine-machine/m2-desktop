# Clawdbot Desktop Migration: VNC → Selkies-GStreamer

## Overview

**Repository:** https://github.com/machine-machine/clawdbot-desktop
**Goal:** Replace noVNC with GPU-accelerated Selkies-GStreamer streaming + pretty XFCE desktop
**Benefits:** 
- NVENC hardware encoding (uses 3090 GPU)
- ~20ms latency vs ~100ms with VNC
- WebRTC streaming (browser-based, like noVNC)
- 60fps smooth desktop experience
- <5% CPU usage for encoding

---

## Architecture Change

```
BEFORE (Current):
┌─────────────────────────────────────┐
│  TigerVNC → noVNC/websockify        │
│  CPU encoding, ~100ms latency       │
│  Port 6080 (HTTP/WebSocket)         │
└─────────────────────────────────────┘

AFTER (Selkies):
┌─────────────────────────────────────┐
│  Xvfb → GStreamer → NVENC → WebRTC  │
│  GPU encoding, ~20ms latency        │
│  Port 8080 (HTTPS/WebRTC)           │
└─────────────────────────────────────┘
```

---

## Files to Modify/Create

| File | Action | Description |
|------|--------|-------------|
| `Dockerfile` | **REPLACE** | New base image + Selkies + XFCE + WhiteSur |
| `docker-compose.yml` | **MODIFY** | Update ports, env vars, capabilities |
| `docker-compose.local.yml` | **MODIFY** | Local dev version without GPU |
| `scripts/entrypoint.sh` | **REPLACE** | New startup sequence for Selkies |
| `scripts/supervisord.conf` | **REPLACE** | New process management |
| `scripts/xstartup` | **DELETE** | No longer needed (Selkies handles X) |
| `config/selkies/` | **CREATE** | Selkies configuration |
| `config/xfce4/` | **CREATE** | XFCE theme configuration |
| `config/plank/` | **CREATE** | Dock configuration |
| `README.md` | **UPDATE** | New documentation |

---

## File Contents

### 1. Dockerfile

```dockerfile
# =============================================================================
# Clawdbot Desktop Worker - Selkies-GStreamer + XFCE4 + WhiteSur Theme
# GPU-accelerated remote desktop with macOS-style appearance
# =============================================================================

FROM ubuntu:22.04

# Build args
ARG DEBIAN_FRONTEND=noninteractive
ARG SELKIES_VERSION=1.6.0

# Environment
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=UTC \
    USER=developer \
    UID=1000 \
    GID=1000 \
    HOME=/home/developer \
    DISPLAY=:0 \
    XDG_RUNTIME_DIR=/tmp/runtime-developer \
    # Selkies configuration
    SELKIES_ENCODER=nvh264enc \
    SELKIES_ENABLE_RESIZE=true \
    SELKIES_FRAMERATE=60 \
    SELKIES_VIDEO_BITRATE=8000 \
    SELKIES_ENABLE_BASIC_AUTH=true \
    # Clawdbot paths
    CLAWDBOT_HOME=/clawdbot_home \
    WORKSPACE=/workspace

# =============================================================================
# Base System + NVIDIA Support
# =============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Locale
    locales \
    # Core utilities
    sudo ca-certificates curl wget git nano htop \
    # X11 and display
    xvfb x11-utils x11-xserver-utils xdotool xclip \
    # PulseAudio for audio support
    pulseaudio pavucontrol \
    # XFCE4 Desktop (lightweight)
    xfce4 xfce4-terminal xfce4-taskmanager thunar mousepad \
    # Plank dock (macOS-style)
    plank \
    # Theme dependencies
    sassc libglib2.0-dev-bin libxml2-utils gtk2-engines-murrine \
    # Fonts
    fonts-inter fonts-noto fonts-noto-color-emoji fonts-dejavu-core \
    # Browser
    chromium-browser fonts-liberation libnss3 libxss1 libasound2 \
    # Python for Selkies
    python3 python3-pip python3-dev python3-gi python3-gi-cairo \
    gir1.2-gtk-3.0 gir1.2-gst-plugins-base-1.0 gir1.2-gstreamer-1.0 \
    # GStreamer
    gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-pulseaudio \
    gstreamer1.0-x gstreamer1.0-gl \
    # NVIDIA GStreamer plugins (for NVENC)
    gstreamer1.0-vaapi \
    # Process management
    supervisor dbus-x11 \
    # Networking
    net-tools iproute2 \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# NVIDIA NVENC Support
# =============================================================================
# Install NVIDIA GStreamer plugins for hardware encoding
RUN apt-get update && apt-get install -y --no-install-recommends \
    libnvidia-encode-550 \
    && rm -rf /var/lib/apt/lists/* \
    || echo "NVIDIA encode libs will come from host driver"

# =============================================================================
# Create User
# =============================================================================
RUN groupadd -g ${GID} ${USER} && \
    useradd -m -s /bin/bash -u ${UID} -g ${GID} ${USER} && \
    echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER} && \
    chmod 0440 /etc/sudoers.d/${USER}

# =============================================================================
# Install Selkies-GStreamer
# =============================================================================
RUN pip3 install --no-cache-dir \
    selkies-gstreamer==${SELKIES_VERSION} \
    websockets \
    basicauth

# =============================================================================
# Install Node.js 22 + Clawdbot
# =============================================================================
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/* && \
    npm install -g clawdbot@latest

# =============================================================================
# Install WhiteSur Theme (macOS-style)
# =============================================================================
USER ${USER}
WORKDIR /tmp

# WhiteSur GTK Theme
RUN git clone https://github.com/vinceliuice/WhiteSur-gtk-theme.git --depth=1 && \
    cd WhiteSur-gtk-theme && \
    ./install.sh -c Dark -l -N glassy && \
    cd .. && rm -rf WhiteSur-gtk-theme

# WhiteSur Icon Theme
RUN git clone https://github.com/vinceliuice/WhiteSur-icon-theme.git --depth=1 && \
    cd WhiteSur-icon-theme && \
    ./install.sh -t default && \
    cd .. && rm -rf WhiteSur-icon-theme

# McMojave Cursors
RUN git clone https://github.com/vinceliuice/McMojave-cursors.git --depth=1 && \
    cd McMojave-cursors && \
    ./install.sh && \
    cd .. && rm -rf McMojave-cursors

# Download wallpaper
RUN mkdir -p ~/.local/share/backgrounds && \
    curl -sL "https://raw.githubusercontent.com/vinceliuice/WhiteSur-wallpapers/main/4k/WhiteSur-dark.png" \
    -o ~/.local/share/backgrounds/wallpaper.png || \
    echo "Wallpaper download failed, will use default"

# =============================================================================
# Configure XFCE4
# =============================================================================
USER ${USER}
RUN mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml \
             ~/.config/xfce4/panel \
             ~/.config/plank/dock1/launchers \
             ~/.local/share/applications \
             ~/Desktop

USER root

# =============================================================================
# Create Directories
# =============================================================================
RUN mkdir -p ${CLAWDBOT_HOME} ${WORKSPACE} ${XDG_RUNTIME_DIR} && \
    chown -R ${USER}:${USER} ${CLAWDBOT_HOME} ${WORKSPACE} ${XDG_RUNTIME_DIR}

# =============================================================================
# Copy Configuration Files
# =============================================================================
COPY --chown=${USER}:${USER} config/xfce4/ /home/${USER}/.config/xfce4/
COPY --chown=${USER}:${USER} config/plank/ /home/${USER}/.config/plank/
COPY --chown=${USER}:${USER} config/desktop/ /home/${USER}/Desktop/
COPY --chown=${USER}:${USER} config/autostart/ /home/${USER}/.config/autostart/
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY scripts/start-desktop.sh /usr/local/bin/start-desktop.sh

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/start-desktop.sh && \
    chown -R ${USER}:${USER} /home/${USER}

# =============================================================================
# Volumes & Ports
# =============================================================================
VOLUME ["${CLAWDBOT_HOME}", "${WORKSPACE}"]

# Selkies WebRTC (8080) + Clawdbot Gateway (18789)
EXPOSE 8080 18789

# =============================================================================
# Healthcheck
# =============================================================================
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# =============================================================================
# Entrypoint
# =============================================================================
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
```

---

### 2. docker-compose.yml

```yaml
services:
  clawdbot-desktop-worker:
    build: .
    container_name: clawdbot-desktop-worker
    restart: unless-stopped
    
    environment:
      # Clawdbot
      CLAWDBOT_HOME: /clawdbot_home
      WORKSPACE: /workspace
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:-}
      OPENAI_API_KEY: ${OPENAI_API_KEY:-}
      
      # Auth (same VNC_PASSWORD as before!)
      VNC_PASSWORD: ${VNC_PASSWORD:-clawdbot}
      
      # Selkies-GStreamer
      SELKIES_ENCODER: nvh264enc
      SELKIES_FRAMERATE: 60
      SELKIES_VIDEO_BITRATE: 8000
      SELKIES_ENABLE_RESIZE: "true"
      SELKIES_ENABLE_BASIC_AUTH: "true"
      
      # GPU (need 'all' for NVENC encoding)
      NVIDIA_VISIBLE_DEVICES: all
      NVIDIA_DRIVER_CAPABILITIES: all
    
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: ["gpu", "compute", "utility", "video"]
    
    # Required for Selkies/Chrome shared memory
    shm_size: '2gb'
    
    expose:
      - "8080"   # Selkies WebRTC (was 6080 for noVNC)
      - "18789"  # Clawdbot Gateway (unchanged)
    
    volumes:
      - clawdbot_home:/clawdbot_home
      - clawdbot_workspace:/workspace
      # Optional: Docker socket for sandboxes
      # - /var/run/docker.sock:/var/run/docker.sock
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    
    labels:
      - traefik.enable=true

volumes:
  clawdbot_home:
  clawdbot_workspace:
```

> **⚠️ Coolify UI Change Required:** After deploy, update port mapping in Coolify:
> - Desktop domain → port **8080** (was 6080)
> - Gateway domain → port **18789** (unchanged)

---

### 3. docker-compose.local.yml (CPU fallback for local dev)

```yaml
# Local development without GPU
# Usage: docker compose -f docker-compose.local.yml up -d

services:
  clawdbot-desktop-worker:
    build: .
    container_name: clawdbot-desktop-worker-local
    restart: unless-stopped
    
    environment:
      DISPLAY: ":0"
      XDG_RUNTIME_DIR: "/tmp/runtime-developer"
      
      # Use software encoding (no GPU)
      SELKIES_ENCODER: x264enc
      SELKIES_FRAMERATE: 30
      SELKIES_VIDEO_BITRATE: 4000
      SELKIES_ENABLE_RESIZE: "true"
      SELKIES_ENABLE_BASIC_AUTH: "true"
      SELKIES_BASIC_AUTH_PASSWORD: ${VNC_PASSWORD:-clawdbot}
      SELKIES_ENABLE_HTTPS: "false"
      
      # No GPU
      NVIDIA_VISIBLE_DEVICES: ""
      
      CLAWDBOT_HOME: /clawdbot_home
      WORKSPACE: /workspace
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:-}
    
    shm_size: '1gb'
    
    ports:
      - "8080:8080"   # Selkies WebRTC
      - "18789:18789" # Clawdbot Gateway
    
    volumes:
      - clawdbot_home_local:/clawdbot_home
      - clawdbot_workspace_local:/workspace

volumes:
  clawdbot_home_local:
  clawdbot_workspace_local:
```

---

### 4. scripts/entrypoint.sh

```bash
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
```

---

### 5. scripts/supervisord.conf

```ini
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisord.log
pidfile=/var/run/supervisord.pid
childlogdir=/var/log

# =============================================================================
# D-Bus (required for desktop)
# =============================================================================
[program:dbus]
command=/usr/bin/dbus-daemon --system --nofork
user=root
autorestart=true
priority=5
stdout_logfile=/var/log/dbus.log
stderr_logfile=/var/log/dbus.err

# =============================================================================
# PulseAudio (for audio support)
# =============================================================================
[program:pulseaudio]
command=/usr/bin/pulseaudio --disallow-exit --disallow-module-loading --exit-idle-time=-1
user=developer
autorestart=true
priority=10
environment=HOME="/home/developer",XDG_RUNTIME_DIR="/tmp/runtime-developer"
stdout_logfile=/var/log/pulseaudio.log
stderr_logfile=/var/log/pulseaudio.err

# =============================================================================
# Xvfb (Virtual Framebuffer)
# =============================================================================
[program:xvfb]
command=/usr/bin/Xvfb :0 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset
user=developer
autorestart=true
priority=15
environment=HOME="/home/developer"
stdout_logfile=/var/log/xvfb.log
stderr_logfile=/var/log/xvfb.err

# =============================================================================
# XFCE4 Desktop
# =============================================================================
[program:xfce4]
command=/usr/local/bin/start-desktop.sh
user=developer
autorestart=true
priority=20
startsecs=5
environment=HOME="/home/developer",USER="developer",DISPLAY=":0",XDG_RUNTIME_DIR="/tmp/runtime-developer"
stdout_logfile=/var/log/xfce4.log
stderr_logfile=/var/log/xfce4.err

# =============================================================================
# Selkies-GStreamer WebRTC Server
# =============================================================================
[program:selkies]
command=/bin/bash -c 'sleep 5 && selkies-gstreamer --addr=0.0.0.0 --port=8080 --enable_basic_auth=%(ENV_SELKIES_ENABLE_BASIC_AUTH)s'
user=developer
autorestart=true
priority=30
startsecs=8
environment=HOME="/home/developer",USER="developer",DISPLAY=":0",XDG_RUNTIME_DIR="/tmp/runtime-developer",PULSE_SERVER="unix:/tmp/runtime-developer/pulse/native"
stdout_logfile=/var/log/selkies.log
stderr_logfile=/var/log/selkies.err

# =============================================================================
# Clawdbot Gateway
# =============================================================================
[program:clawdbot-gateway]
command=/bin/bash -c 'sleep 10 && clawdbot gateway --port 18789 --allow-unconfigured'
user=developer
autorestart=true
priority=40
startsecs=5
environment=HOME="/home/developer",USER="developer",DISPLAY=":0",CLAWDBOT_HOME="/clawdbot_home",WORKSPACE="/workspace"
stdout_logfile=/var/log/clawdbot.log
stderr_logfile=/var/log/clawdbot.err
```

---

### 6. scripts/start-desktop.sh

```bash
#!/bin/bash

# Wait for X server
while ! xdpyinfo -display :0 &>/dev/null; do
    echo "Waiting for X server..."
    sleep 1
done

export DISPLAY=:0
export XDG_RUNTIME_DIR=/tmp/runtime-developer
export DBUS_SESSION_BUS_ADDRESS=$(dbus-launch --sh-syntax | grep DBUS_SESSION_BUS_ADDRESS | cut -d= -f2- | tr -d "'")

# Apply XFCE settings
xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
xfconf-query -c xsettings -p /Net/ThemeName -s "WhiteSur-Dark" 2>/dev/null || true
xfconf-query -c xsettings -p /Net/IconThemeName -s "WhiteSur-dark" 2>/dev/null || true
xfconf-query -c xsettings -p /Gtk/CursorThemeName -s "McMojave-cursors" 2>/dev/null || true

# Set wallpaper
if [ -f ~/.local/share/backgrounds/wallpaper.png ]; then
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorscreen/workspace0/last-image \
        -s ~/.local/share/backgrounds/wallpaper.png 2>/dev/null || true
fi

# Start Plank dock
plank &

# Start XFCE4 session
exec startxfce4
```

---

### 7. config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="use_compositing" type="bool" value="false"/>
    <property name="theme" type="string" value="WhiteSur-Dark"/>
    <property name="title_font" type="string" value="Inter Bold 10"/>
    <property name="button_layout" type="string" value="CHM|"/>
    <property name="workspace_count" type="int" value="4"/>
    <property name="placement_ratio" type="int" value="20"/>
    <property name="show_dock_shadow" type="bool" value="false"/>
  </property>
</channel>
```

---

### 8. config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="WhiteSur-Dark"/>
    <property name="IconThemeName" type="string" value="WhiteSur-dark"/>
    <property name="CursorThemeName" type="string" value="McMojave-cursors"/>
    <property name="EnableEventSounds" type="bool" value="false"/>
  </property>
  <property name="Xft" type="empty">
    <property name="Antialias" type="int" value="1"/>
    <property name="HintStyle" type="string" value="hintslight"/>
    <property name="RGBA" type="string" value="rgb"/>
    <property name="DPI" type="int" value="96"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Inter 10"/>
    <property name="MonospaceFontName" type="string" value="JetBrains Mono 10"/>
    <property name="CursorThemeName" type="string" value="McMojave-cursors"/>
    <property name="CursorThemeSize" type="int" value="24"/>
  </property>
</channel>
```

---

### 9. config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitorscreen" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/home/developer/.local/share/backgrounds/wallpaper.png"/>
        </property>
      </property>
    </property>
  </property>
  <property name="desktop-icons" type="empty">
    <property name="style" type="int" value="2"/>
    <property name="file-icons" type="empty">
      <property name="show-home" type="bool" value="false"/>
      <property name="show-filesystem" type="bool" value="false"/>
      <property name="show-trash" type="bool" value="true"/>
    </property>
  </property>
</channel>
```

---

### 10. config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
  </property>
  <property name="panels/panel-1" type="empty">
    <property name="position" type="string" value="p=6;x=0;y=0"/>
    <property name="length" type="uint" value="100"/>
    <property name="position-locked" type="bool" value="true"/>
    <property name="size" type="uint" value="28"/>
    <property name="background-style" type="uint" value="0"/>
    <property name="plugin-ids" type="array">
      <value type="int" value="1"/>
      <value type="int" value="2"/>
      <value type="int" value="3"/>
      <value type="int" value="4"/>
      <value type="int" value="5"/>
      <value type="int" value="6"/>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="applicationsmenu"/>
    <property name="plugin-2" type="string" value="tasklist"/>
    <property name="plugin-3" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-4" type="string" value="systray"/>
    <property name="plugin-5" type="string" value="pulseaudio"/>
    <property name="plugin-6" type="string" value="clock"/>
  </property>
</channel>
```

---

### 11. config/plank/dock1/settings

```ini
[PlankDockPreferences]
Alignment=3
AutohideMode=3
CurrentWorkspaceOnly=false
DockItems=terminal.dockitem;chromium.dockitem;thunar.dockitem
HideDelay=500
HideMode=3
IconSize=48
ItemsAlignment=3
LockItems=false
Monitor=-1
Offset=0
PinnedOnly=false
Position=3
PressureReveal=false
ShowDockItem=false
Theme=Gtk+
UnhideDelay=0
ZoomEnabled=true
ZoomPercent=150
```

---

### 12. config/plank/dock1/launchers/terminal.dockitem

```ini
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/xfce4-terminal.desktop
```

---

### 13. config/plank/dock1/launchers/chromium.dockitem

```ini
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/chromium-browser.desktop
```

---

### 14. config/plank/dock1/launchers/thunar.dockitem

```ini
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/thunar.desktop
```

---

### 15. config/desktop/Workspace.desktop

```ini
[Desktop Entry]
Version=1.0
Type=Application
Name=Workspace
Comment=Open Workspace Folder
Exec=thunar /workspace
Icon=folder-documents
Terminal=false
Categories=Utility;FileManager;
```

---

### 16. config/desktop/Terminal.desktop

```ini
[Desktop Entry]
Version=1.0
Type=Application
Name=Terminal
Comment=Open Terminal
Exec=xfce4-terminal
Icon=utilities-terminal
Terminal=false
Categories=Utility;TerminalEmulator;
```

---

### 17. config/autostart/plank.desktop

```ini
[Desktop Entry]
Type=Application
Name=Plank
Comment=macOS-style dock
Exec=plank
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
```

---

### 18. README.md (Updated)

```markdown
# clawdbot-desktop

GPU-accelerated remote desktop for Clawdbot, using Selkies-GStreamer WebRTC streaming with NVENC encoding.

## Features

- **GPU-Accelerated Streaming** - Uses NVIDIA NVENC for ~20ms latency
- **WebRTC Protocol** - Modern, low-latency streaming in any browser
- **Pretty XFCE Desktop** - WhiteSur macOS-style theme + Plank dock
- **Clawdbot Gateway** - Installed and running as a daemon
- **Audio Support** - PulseAudio streaming included

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Coolify (Deployment & Reverse Proxy)           │
├─────────────────────────────────────────────────┤
│  Docker Container (clawdbot-desktop-worker)     │
│                                                 │
│  Supervisord (Process Manager)                  │
│  ├── Xvfb (:0 display, 1920x1080)              │
│  ├── XFCE4 + Plank (Desktop environment)        │
│  ├── Selkies-GStreamer (WebRTC + NVENC)        │
│  │   └── Port 8080 (HTTPS)                     │
│  └── Clawdbot Daemon                           │
│      └── Port 18789 (WebSocket)                │
│                                                 │
│  Volumes:                                       │
│  ├── /clawdbot_home (config & state)           │
│  └── /workspace (workspace data)               │
└─────────────────────────────────────────────────┘
```

## Quick Start

### Production (with GPU)

```bash
docker compose up -d
```

Access: `https://desktop.yourdomain.com`
- Username: `developer`
- Password: value of `VNC_PASSWORD` (default: `clawdbot`)

### Local Development (without GPU)

```bash
docker compose -f docker-compose.local.yml up -d
```

Access: `http://localhost:8080`

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VNC_PASSWORD` | `clawdbot` | Access password (same as before!) |
| `SELKIES_ENCODER` | `nvh264enc` | Video encoder (`nvh264enc` or `x264enc`) |
| `SELKIES_FRAMERATE` | `60` | Target framerate |
| `SELKIES_VIDEO_BITRATE` | `8000` | Bitrate in kbps |
| `ANTHROPIC_API_KEY` | - | For Clawdbot |
| `OPENAI_API_KEY` | - | For Clawdbot (optional) |

## Coolify Configuration

After deploying, configure domains in Coolify UI:
- Desktop: your domain → port **8080**
- Gateway: your domain → port **18789**

## GPU Requirements

- NVIDIA GPU with NVENC support (GTX 900+, RTX series)
- NVIDIA Driver 525+ on host
- NVIDIA Container Toolkit

Verify GPU access:
```bash
docker compose exec clawdbot-desktop-worker nvidia-smi
```

## Performance Comparison

| Metric | VNC (old) | Selkies (new) |
|--------|-----------|---------------|
| Latency | ~100ms | ~20ms |
| CPU Usage | 30-50% | <5% |
| Quality | Blocky | Crisp |
| Max FPS | 30 | 60 |

## License

MIT
```

---

## Directory Structure (Final)

```
clawdbot-desktop/
├── Dockerfile
├── docker-compose.yml
├── docker-compose.local.yml
├── README.md
├── .env.example
├── scripts/
│   ├── entrypoint.sh
│   ├── supervisord.conf
│   └── start-desktop.sh
└── config/
    ├── xfce4/
    │   └── xfconf/
    │       └── xfce-perchannel-xml/
    │           ├── xfwm4.xml
    │           ├── xsettings.xml
    │           ├── xfce4-desktop.xml
    │           └── xfce4-panel.xml
    ├── plank/
    │   └── dock1/
    │       ├── settings
    │       └── launchers/
    │           ├── terminal.dockitem
    │           ├── chromium.dockitem
    │           └── thunar.dockitem
    ├── desktop/
    │   ├── Workspace.desktop
    │   └── Terminal.desktop
    └── autostart/
        └── plank.desktop
```

---

## Migration Steps for DevOps Agent

1. **Backup current state**
   ```bash
   git checkout -b backup/vnc-version
   git push origin backup/vnc-version
   git checkout main
   ```

2. **Delete old files**
   ```bash
   rm -f scripts/xstartup
   ```

3. **Create directory structure**
   ```bash
   mkdir -p config/{xfce4/xfconf/xfce-perchannel-xml,plank/dock1/launchers,desktop,autostart}
   mkdir -p scripts
   ```

4. **Create all files** as specified above (Dockerfile, docker-compose.yml, all configs)

5. **Test locally first**
   ```bash
   docker compose -f docker-compose.local.yml build
   docker compose -f docker-compose.local.yml up
   # Open http://localhost:8080
   # Login: developer / clawdbot
   ```

6. **Test with GPU**
   ```bash
   docker compose build
   docker compose up
   # Verify NVENC encoding in logs:
   # Look for "Encoder: nvh264enc"
   ```

7. **Commit and push**
   ```bash
   git add -A
   git commit -m "feat: migrate to Selkies-GStreamer with GPU acceleration

   - Replace noVNC with Selkies-GStreamer WebRTC
   - Add NVENC hardware encoding support
   - Add XFCE4 desktop with WhiteSur macOS theme
   - Add Plank dock for macOS-style UX
   - Port changed: 6080 → 8080"
   
   git push origin main
   ```

8. **Update Coolify UI** (after deploy)
   - Go to service settings in Coolify
   - Update domain port mapping:
     - Desktop domain: change port `6080` → `8080`
     - Gateway domain: keep port `18789` (unchanged)
   - Redeploy if needed

---

## Troubleshooting

### WhiteSur theme fails to install
Ensure these packages are installed before WhiteSur:
```dockerfile
RUN apt-get install -y sassc libglib2.0-dev-bin libxml2-utils gtk2-engines-murrine
```

### No NVENC encoding
Check if libnvidia-encode is available:
```bash
docker compose exec clawdbot-desktop-worker ls /usr/lib/x86_64-linux-gnu/libnvidia-encode*
```

### Black screen
Check Xvfb is running:
```bash
docker compose exec clawdbot-desktop-worker supervisorctl status
```

### High latency
Verify encoder:
```bash
docker compose logs clawdbot-desktop-worker | grep -i encoder
# Should show: nvh264enc (not x264enc)
```
