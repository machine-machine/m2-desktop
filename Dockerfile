# VNC + noVNC + Clawdbot desktop worker (minimal X session)
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    USER=developer \
    VNC_PASSWORD=clawdbot \
    DISPLAY=:1 \
    CLAWDBOT_HOME=/clawdbot_home \
    WORKSPACE=/workspace

# Base packages, locales, VNC, noVNC, Browser
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      locales \
      sudo \
      dbus-x11 \
      xterm \
      tigervnc-standalone-server tigervnc-tools \
      novnc websockify \
      x11-xserver-utils \
      curl ca-certificates \
      git \
      bash \
      supervisor \
      # Browser for Claude Max / Clawdbot browser auth
      chromium-browser \
      fonts-liberation \
      libnss3 \
      libxss1 \
      libasound2 \
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
COPY scripts/xstartup /home/developer/.vnc/xstartup
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    chmod +x /home/developer/.vnc/xstartup && \
    chown -R developer:developer /home/developer/.vnc

# Create Xtigervnc-session for minimal X session (avoids GNOME/systemd dependency)
RUN mkdir -p /etc/X11 && \
    printf '#!/bin/bash\nexport DISPLAY=:1\n/usr/bin/x-terminal-emulator -e /bin/bash &\ntail -f /dev/null\n' > /etc/X11/Xtigervnc-session && \
    chmod +x /etc/X11/Xtigervnc-session

# Create index.html to redirect root to vnc.html (avoids directory listing)
RUN echo '<!DOCTYPE html><html><head><meta http-equiv="refresh" content="0; url=/vnc.html"><script>window.location.href="/vnc.html";</script></head></html>' > /usr/share/novnc/index.html

# Expose internal ports (no direct host bind – Coolify/reverse proxy will route)
EXPOSE 18789 6080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
