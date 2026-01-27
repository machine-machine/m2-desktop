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
    # Theme dependencies + fallback themes
    sassc libglib2.0-dev-bin libxml2-utils gtk2-engines-murrine \
    arc-theme papirus-icon-theme dmz-cursor-theme \
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

# WhiteSur GTK Theme (with error handling)
RUN git clone https://github.com/vinceliuice/WhiteSur-gtk-theme.git --depth=1 && \
    cd WhiteSur-gtk-theme && \
    (bash ./install.sh -c Dark -l --tweaks normal || bash ./install.sh -c Dark || echo "WhiteSur GTK install failed") && \
    cd .. && rm -rf WhiteSur-gtk-theme || true

# WhiteSur Icon Theme (with error handling)
RUN git clone https://github.com/vinceliuice/WhiteSur-icon-theme.git --depth=1 && \
    cd WhiteSur-icon-theme && \
    (bash ./install.sh || echo "WhiteSur icons install failed") && \
    cd .. && rm -rf WhiteSur-icon-theme || true

# McMojave Cursors (with error handling)
RUN git clone https://github.com/vinceliuice/McMojave-cursors.git --depth=1 && \
    cd McMojave-cursors && \
    (bash ./install.sh || echo "McMojave cursors install failed") && \
    cd .. && rm -rf McMojave-cursors || true

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
