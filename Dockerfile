# =============================================================================
# Clawdbot Desktop Worker - Selkies-GStreamer + XFCE4 + WhiteSur Theme
# GPU-accelerated remote desktop with macOS-style appearance
# =============================================================================

# Selkies base image (includes GStreamer, NVENC, WebRTC, PulseAudio, Xvfb)
FROM ghcr.io/selkies-project/selkies-gstreamer:24.04-20240701

# Environment
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
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
# Install Desktop Environment + Dependencies
# =============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Locale
    locales \
    # Core utilities
    sudo ca-certificates curl wget git nano htop \
    # XFCE4 Desktop (lightweight)
    xfce4 xfce4-terminal xfce4-taskmanager thunar mousepad \
    # Plank dock (macOS-style)
    plank \
    # Theme dependencies
    sassc libglib2.0-dev-bin libxml2-utils gtk2-engines-murrine \
    # Fallback themes (in case WhiteSur fails)
    arc-theme papirus-icon-theme dmz-cursor-theme \
    # Fonts
    fonts-inter fonts-noto fonts-noto-color-emoji fonts-dejavu-core \
    # Browser
    chromium-browser fonts-liberation libnss3 libxss1 libasound2 \
    # Process management
    supervisor dbus-x11 \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Create User
# =============================================================================
RUN groupadd -g ${GID} ${USER} 2>/dev/null || true && \
    useradd -m -s /bin/bash -u ${UID} -g ${GID} ${USER} 2>/dev/null || true && \
    echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER} && \
    chmod 0440 /etc/sudoers.d/${USER}

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
    cd .. && rm -rf WhiteSur-gtk-theme || \
    echo "WhiteSur GTK theme install failed, using fallback"

# WhiteSur Icon Theme
RUN git clone https://github.com/vinceliuice/WhiteSur-icon-theme.git --depth=1 && \
    cd WhiteSur-icon-theme && \
    ./install.sh -t default && \
    cd .. && rm -rf WhiteSur-icon-theme || \
    echo "WhiteSur icon theme install failed, using fallback"

# McMojave Cursors
RUN git clone https://github.com/vinceliuice/McMojave-cursors.git --depth=1 && \
    cd McMojave-cursors && \
    ./install.sh && \
    cd .. && rm -rf McMojave-cursors || \
    echo "McMojave cursors install failed, using fallback"

# Download wallpaper
RUN mkdir -p ~/.local/share/backgrounds && \
    curl -sL "https://raw.githubusercontent.com/vinceliuice/WhiteSur-wallpapers/main/4k/WhiteSur-dark.png" \
    -o ~/.local/share/backgrounds/wallpaper.png || \
    echo "Wallpaper download failed, will use default"

# =============================================================================
# Configure XFCE4 directories
# =============================================================================
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
