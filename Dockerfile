# VNC + noVNC + Clawdbot desktop worker (Pretty XFCE4 with dark theme)
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    USER=developer \
    VNC_PASSWORD=clawdbot \
    DISPLAY=:1 \
    CLAWDBOT_HOME=/clawdbot_home \
    WORKSPACE=/workspace

# Base packages + XFCE4 desktop environment + themes
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      locales \
      sudo \
      dbus-x11 \
      # VNC stack
      tigervnc-standalone-server tigervnc-tools \
      novnc websockify \
      x11-xserver-utils \
      # XFCE4 desktop environment (lightweight, VNC-friendly)
      xfce4 \
      xfce4-terminal \
      xfce4-taskmanager \
      xfce4-screenshooter \
      thunar \
      mousepad \
      # macOS-style dock
      plank \
      # Themes (apt-installable, reliable)
      arc-theme \
      papirus-icon-theme \
      dmz-cursor-theme \
      # Core utilities
      curl ca-certificates wget \
      git \
      bash \
      supervisor \
      htop \
      nano \
      # Browser for Claude Max / Clawdbot browser auth
      chromium-browser \
      fonts-liberation fonts-dejavu-core fonts-noto-color-emoji \
      libnss3 libxss1 libasound2 \
      # VS Code dependencies (optional, for future)
      libsecret-1-0 \
    && locale-gen en_US.UTF-8 && \
    # Clean up
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* /tmp/*

# Create non-root user
RUN useradd -m -s /bin/bash ${USER} && \
    echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER}

USER ${USER}
WORKDIR /home/${USER}

# Download a nice dark wallpaper
RUN mkdir -p ~/.local/share/backgrounds && \
    curl -sL "https://images.unsplash.com/photo-1518837695005-2083093ee35b?w=1920&q=80" \
    -o ~/.local/share/backgrounds/wallpaper.jpg || \
    curl -sL "https://picsum.photos/1920/1080" -o ~/.local/share/backgrounds/wallpaper.jpg || true

# Install Node 22 (via NodeSource) and Clawdbot
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && \
    sudo apt-get update && \
    sudo apt-get install -y nodejs && \
    sudo rm -rf /var/lib/apt/lists/* && \
    sudo npm install -g clawdbot@latest

# Prepare directories
RUN sudo mkdir -p ${CLAWDBOT_HOME} ${WORKSPACE} && \
    sudo chown -R ${USER}:${USER} ${CLAWDBOT_HOME} ${WORKSPACE}

# Configure XFCE4 for VNC (disable compositing, set theme)
RUN mkdir -p /home/${USER}/.config/xfce4/xfconf/xfce-perchannel-xml && \
    mkdir -p /home/${USER}/.config/xfce4/panel && \
    mkdir -p /home/${USER}/.config/plank/dock1/launchers && \
    mkdir -p /home/${USER}/Desktop

VOLUME ["${CLAWDBOT_HOME}", "${WORKSPACE}"]

# Copy configs
USER root
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY scripts/xstartup /home/developer/.vnc/xstartup
COPY config/xfce4/ /home/developer/.config/xfce4/
COPY config/plank/ /home/developer/.config/plank/
COPY config/desktop/ /home/developer/Desktop/

RUN chmod +x /usr/local/bin/entrypoint.sh && \
    chmod +x /home/developer/.vnc/xstartup && \
    chown -R developer:developer /home/developer

# Create index.html redirect
RUN echo '<!DOCTYPE html><html><head><meta http-equiv="refresh" content="0; url=/vnc.html"></head></html>' > /usr/share/novnc/index.html

EXPOSE 18789 6080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
