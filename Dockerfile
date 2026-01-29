# =============================================================================
# Clawdbot Desktop Worker - Apache Guacamole + XFCE4 + WhiteSur Theme
# Multi-user HTML5 remote desktop with macOS-style appearance
# =============================================================================

FROM ubuntu:22.04

# Build args
ARG DEBIAN_FRONTEND=noninteractive
ARG GUACAMOLE_VERSION=1.5.5

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
    # Clawdbot paths
    CLAWDBOT_HOME=/clawdbot_home \
    WORKSPACE=/workspace \
    # Flatpak user installation to persistent volume
    FLATPAK_USER_DIR=/clawdbot_home/flatpak \
    # Guacamole settings
    GUACD_LOG_LEVEL=info

# =============================================================================
# Install Desktop Environment + Dependencies
# =============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Locale
    locales \
    # Core utilities
    sudo ca-certificates curl wget git nano htop software-properties-common \
    # X11 and display
    xserver-xorg-video-dummy xserver-xorg-core x11-utils x11-xserver-utils xdotool xclip xsel \
    # VNC for X11 sharing
    x11vnc \
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
    # Browser dependencies (Chrome installed separately)
    fonts-liberation libnss3 libxss1 libasound2 libatk-bridge2.0-0 libgtk-3-0 \
    # Process management & audio
    supervisor dbus dbus-x11 pulseaudio \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Install guacd (Guacamole Server) from PPA
# =============================================================================
RUN add-apt-repository -y ppa:remmina-ppa-team/remmina-next && \
    apt-get update && \
    apt-get install -y guacd libguac-client-vnc && \
    rm -rf /var/lib/apt/lists/*

# =============================================================================
# Install newer Flatpak from PPA
# =============================================================================
RUN add-apt-repository -y ppa:flatpak/stable && \
    apt-get update && \
    apt-get install -y flatpak && \
    rm -rf /var/lib/apt/lists/*

# Add Flathub repository (system-wide, user apps go to persistent volume)
RUN flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Install Google Chrome (Ubuntu's chromium-browser is snap-only, doesn't work in Docker)
RUN curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/chrome.deb && \
    apt-get update && \
    apt-get install -y /tmp/chrome.deb && \
    rm /tmp/chrome.deb && \
    rm -rf /var/lib/apt/lists/*

# =============================================================================
# Create User
# =============================================================================
RUN groupadd -g ${GID} ${USER} 2>/dev/null || true && \
    useradd -m -s /bin/bash -u ${UID} -g ${GID} ${USER} 2>/dev/null || true && \
    echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER} && \
    chmod 0440 /etc/sudoers.d/${USER}

# =============================================================================
# Install Node.js 22 + Clawdbot + guacamole-lite
# =============================================================================
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/* && \
    npm install -g clawdbot@latest

# Install guacamole-lite (lightweight HTML5 client)
RUN mkdir -p /opt/guacamole-lite && \
    cd /opt/guacamole-lite && \
    npm init -y && \
    npm install guacamole-lite express

# =============================================================================
# Install Cargstore (App Store)
# =============================================================================
ARG CARGSTORE_VERSION=0.2.1
RUN mkdir -p /opt/cargstore && \
    curl -fsSL "https://github.com/machine-machine/cargstore/releases/download/v${CARGSTORE_VERSION}/cargstore-${CARGSTORE_VERSION}.tar.gz" \
    | tar -xzf - -C /opt/cargstore --strip-components=1 && \
    chmod +x /opt/cargstore/cargstore && \
    printf '%s\n' \
        '[Desktop Entry]' \
        'Name=Cargstore' \
        'Comment=App Store for Clawdbot Desktop' \
        'Exec=/opt/cargstore/cargstore --no-sandbox %U' \
        'Icon=system-software-install' \
        'Terminal=false' \
        'Type=Application' \
        'Categories=System;PackageManager;' \
        'StartupWMClass=Cargstore' \
        'MimeType=x-scheme-handler/flatpak;' \
    > /usr/share/applications/cargstore.desktop && \
    update-desktop-database /usr/share/applications 2>/dev/null || true

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
COPY config/xorg.conf /etc/X11/xorg.conf
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY scripts/start-desktop.sh /usr/local/bin/start-desktop.sh
COPY scripts/guacamole-server.js /opt/guacamole-lite/server.js

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/start-desktop.sh && \
    chown -R ${USER}:${USER} /home/${USER}

# =============================================================================
# Volumes & Ports
# =============================================================================
VOLUME ["${CLAWDBOT_HOME}", "${WORKSPACE}"]

# Guacamole Web (8080) + Clawdbot Gateway (18789)
EXPOSE 8080 18789

# =============================================================================
# Healthcheck - check if guacamole-lite is responding
# =============================================================================
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/ | grep -qE '^(200|401)$' || exit 1

# =============================================================================
# Entrypoint
# =============================================================================
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
