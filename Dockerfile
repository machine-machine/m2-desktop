# GNOME + noVNC + Clawdbot desktop worker
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    USER=developer \
    VNC_PASSWORD=clawdbot \
    DISPLAY=:1 \
    CLAWDBOT_HOME=/clawdbot_home \
    WORKSPACE=/workspace

# Base packages, locales, GNOME, VNC, noVNC, Node
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      locales \
      sudo \
      dbus-x11 \
      gnome-shell gnome-session gnome-terminal gnome-control-center nautilus \
      gdm3 \
      tigervnc-standalone-server tigervnc-tools tigervnc-xorg-extension \
      novnc websockify \
      x11-xserver-utils \
      curl ca-certificates \
      git \
      bash \
      supervisor \
    && locale-gen en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash ${USER} && \
    echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER}

USER ${USER}
WORKDIR /home/${USER}

# Install Node 22 (via NodeSource) and Clawdbot
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && \
    sudo apt-get update && \
    sudo apt-get install -y nodejs && \
    sudo rm -rf /var/lib/apt/lists/* && \
    sudo npm install -g clawdbot@latest

# Prepare directories
RUN sudo mkdir -p ${CLAWDBOT_HOME} ${WORKSPACE} && \
    sudo chown -R ${USER}:${USER} ${CLAWDBOT_HOME} ${WORKSPACE}
VOLUME ["${CLAWDBOT_HOME}", "${WORKSPACE}"]

# Copy entrypoint & supervisord configs
USER root
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose internal ports (no direct host bind – Coolify/reverse proxy will route)
EXPOSE 18789 6080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
