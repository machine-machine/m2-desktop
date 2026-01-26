## 1. Product summary

`clawdbot-desktop` is a GPU-enabled Dockerized GNOME desktop that runs Clawdbot Gateway and exposes a web-based VNC (noVNC) session and Clawdbot UI via Coolify and an external reverse proxy. [docs.clawd](https://docs.clawd.bot/install/docker)

Core outcomes:

- Persistent “AI worker PC” with full Linux GNOME desktop inside a container, remotely accessible from any browser. [github](https://github.com/wwwshwww/novnc-ros-desktop)
- Clawdbot installed and running as a daemon in the same container, with configuration persisted in a dedicated volume. [github](https://github.com/clawdbot/clawdbot)
- GPU access via NVIDIA Container Toolkit and Docker Compose GPU reservations. [stackoverflow](https://stackoverflow.com/questions/74175742/docker-compose-cant-access-gpu-from-compose-but-can-from-run)

## 2. Target users and use cases

- You (and similar power users): AI infra/ML engineers running Coolify on GPU nodes, wanting a GUI “agent box” per project. [coolify](https://coolify.io/docs/applications/build-packs/docker-compose)
- Primary use cases:  
  - Run Clawdbot with sandboxed tools and browser while having a full GNOME desktop the agent and human can share. [clawdbot](https://clawdbot.com/configuration.html)
  - Centralize dev tooling, browser, and automation in a single GPU-enabled desktop behind your own reverse proxy. [coolify](https://coolify.io/docs/knowledge-base/docker/compose)

Non-goals:

- Multi-tenant access control beyond what Coolify/reverse proxy provides.  
- Turnkey Clawdbot onboarding UX for non-technical users; this is infra-first.

## 3. Functional requirements

### 3.1 GNOME desktop with web-based VNC

- Run a GNOME desktop session inside the container on a virtual X display, suitable for headless operation. [stackoverflow](https://stackoverflow.com/questions/44227215/docker-gnome-tightvncserver-novnc)
- Provide VNC access to the display via TigerVNC or similar server. [reddit](https://www.reddit.com/r/Ubuntu/comments/1i45x1u/how_to_set_up_vnc_server_on_ubuntu_2404_with/)
- Wrap VNC in noVNC (HTML5 client + websockify) listening on internal port 6080. [hub.docker](https://hub.docker.com/r/theasp/novnc)
- VNC password configurable via environment variable (`VNC_PASSWORD`). [my.mbuzztech](https://my.mbuzztech.com/portal/en/kb/articles/setup-novnc-on-ubuntu-gnome)

User stories:

- From macOS or Windows, open the Coolify-routed domain (reverse proxy) and see the GNOME desktop in the browser, no additional client needed. [nordlayer](https://nordlayer.com/blog/vnc-vs-rdp-key-differences/)

### 3.2 Clawdbot Gateway and Control UI

- Install Clawdbot globally via Node 22.x in the image. [docs.clawd](https://docs.clawd.bot/cli/docs)
- Run `clawdbot daemon` (or appropriate gateway command) as a supervised process, listening on internal port 18789. [docs.clawd](https://docs.clawd.bot/platforms/linux)
- Store all Clawdbot data (config, logs, state) in `/clawdbot_home`, backed by named Docker volume `clawdbot_home`. [docs.clawd](https://docs.clawd.bot/install/docker)
- On first run, allow onboarding via CLI or through browser-based Control UI; configuration must survive container restarts. [anshuman](https://www.anshuman.ai/posts/my-clawdbot-setup)

User stories:

- I open the Clawdbot UI domain, provide API keys and basic config once, and never lose it across redeploys. [clawd](https://clawd.bot)

### 3.3 GPU access

- Container must see NVIDIA GPUs via NVIDIA Container Toolkit on the host. [reddit](https://www.reddit.com/r/docker/comments/1bdan8q/how_do_i_enable_a_gpu_to_be_used_in_docker_compose/)
- Docker Compose config must request GPU devices using `deploy.resources.reservations.devices` or `runtime: nvidia` + NVIDIA envs for non-Swarm setups. [howtogeek](https://www.howtogeek.com/devops/how-to-run-docker-compose-containers-with-gpu-access/)
- Container should be able to run `nvidia-smi` successfully to verify GPU visibility. [runebook](https://runebook.dev/en/docs/docker/compose/gpu-support/index)

User stories:

- I can run local ML models or GPU-accelerated tools inside the Clawdbot desktop container without additional manual GPU wiring. [blog.roboflow](https://blog.roboflow.com/use-the-gpu-in-docker/)

### 3.4 Sandbox/tooling support

- Optionally mount `/var/run/docker.sock` to allow Clawdbot to spawn sandboxed tool containers, following Clawdbot’s Docker sandboxing conventions. [answeroverflow](https://www.answeroverflow.com/m/1460340476103364851)
- Provide a default sample sandbox configuration (`workdir`, `readOnlyRoot`, `tmpfs`, `network`, `user`, `capDrop`) aligned with Clawdbot docs. [docs.docker](https://docs.docker.com/ai/sandboxes/)

User stories:

- Agent can call tools in isolated containers with controlled filesystem and network access, defined via Clawdbot configuration. [docs.clawd](https://docs.clawd.bot/gateway/sandboxing)

### 3.5 Coolify integration

- Compose file ready for **Docker Compose build pack** and Raw Compose Deployment in Coolify. [github](https://github.com/coollabsio/coolify/issues/1709)
- No host `ports:` mapping; only `expose` internal ports 18789 and 6080, allowing Coolify and external reverse proxy to route traffic. [github](https://github.com/coollabsio/coolify/discussions/3712)
- Define named volumes `clawdbot_home` and `clawdbot_workspace`, to be mapped to Coolify storage. [coolify](https://coolify.io/docs/applications/build-packs/docker-compose)

User stories:

- I select the GitHub repo in Coolify, pick Docker Compose build pack, configure env and storage, deploy once, and then just hit my reverse-proxy domains. [coolify](https://coolify.io/docs/applications/build-packs/overview)

## 4. Non-functional requirements

- **Reliability**:  
  - Use `supervisord` (or equivalent) inside container to manage GNOME session, VNC, noVNC, and Clawdbot as separate programs that autorestart on failure. [oneuptime](https://oneuptime.com/blog/post/2026-01-16-docker-gui-apps-x11-vnc/view)
- **Security**:  
  - No direct host port publishing. All public exposure is via HTTPS reverse proxy with your own auth. [coolify](https://coolify.io/docs/knowledge-base/docker/compose)
  - VNC password must be configurable; default should be non-empty and clearly marked as dev-only in docs. [github](https://github.com/wwwshwww/novnc-ros-desktop)
  - Sandbox defaults use locked-down Docker options (no network, read-only root, dropped capabilities). [clawdbot](https://clawdbot.com/configuration.html)
- **Performance**:  
  - Baseline recommendation: at least 4 vCPU, 8–16 GB RAM, one NVIDIA GPU.  
  - VNC/noVNC tuned for WAN usage (reasonable resolution and compression). [github](https://github.com/prbinu/novnc-desktop)

## 5. Technical design (summary)

- Base image: GPU-ready Ubuntu 22.04 runtime (e.g., CUDA runtime base) with GNOME, TigerVNC, noVNC, Node 22, and Clawdbot installed. [github](https://github.com/wenoptics/ubuntu-desktop-novnc)
- Entry flow: `entrypoint.sh` starts `supervisord`, which runs GNOME (`gnome-session`), VNC, noVNC (6080), and Clawdbot gateway (18789). [stackoverflow](https://stackoverflow.com/questions/44227215/docker-gnome-tightvncserver-novnc)
- Compose: single service `clawdbot-desktop-worker` with GPU reservations, internal `expose`, volumes, and env configuration. [howtogeek](https://www.howtogeek.com/devops/how-to-run-docker-compose-containers-with-gpu-access/)

## 6. Repository layout

- `Dockerfile` – builds GNOME + VNC + noVNC + Clawdbot image. [github](https://github.com/clawdbot/clawdbot)
- `docker-compose.yml` – production-ready stack for Coolify (no host ports, GPU reservations, volumes). [coolify](https://coolify.io/docs/applications/build-packs/docker-compose)
- `scripts/entrypoint.sh` – bootstraps supervisord and environment. [oneuptime](https://oneuptime.com/blog/post/2026-01-16-docker-gui-apps-x11-vnc/view)
- `scripts/supervisord.conf` – defines GNOME, VNC, noVNC, Clawdbot processes. [github](https://github.com/wwwshwww/novnc-ros-desktop)
- `config/clawdbot.config.sample.json` – optional sandbox and workspace defaults aligned with official config docs. [clawdbot](https://clawdbot.com/configuration.html)
- `README.md` – includes run instructions, Coolify integration notes, GPU troubleshooting, and Clawdbot onboarding hints. [anshuman](https://www.anshuman.ai/posts/my-clawdbot-setup)

---


Possible start for iterations:

Here’s a first working version you can drop into `machine-machine/clawdbot-desktop` and iterate on.

## Dockerfile

```Dockerfile
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
      tigervnc-standalone-server tigervnc-xorg-extension \
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
    npm install -g clawdbot@latest

# Prepare directories
RUN mkdir -p ${CLAWDBOT_HOME} ${WORKSPACE}
VOLUME ["${CLAWDBOT_HOME}", "${WORKSPACE}"]

# Copy entrypoint & supervisord configs
USER root
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose internal ports (no direct host bind – Coolify/reverse proxy will route)
EXPOSE 18789 6080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
```

### scripts/entrypoint.sh

```bash
#!/usr/bin/env bash
set -e

# Default VNC password if not set
VNC_PASSWORD="${VNC_PASSWORD:-clawdbot}"

# Ensure runtime dirs
mkdir -p /run/user/1000
chown -R ${USER}:${USER} /run/user/1000

# Set up VNC password
sudo -u ${USER} mkdir -p /home/${USER}/.vnc
echo "${VNC_PASSWORD}" | sudo -u ${USER} vncpasswd -f > /home/${USER}/.vnc/passwd
chmod 600 /home/${USER}/.vnc/passwd
chown ${USER}:${USER} /home/${USER}/.vnc/passwd

# Start supervisord to run:
# - GNOME session on :1
# - TigerVNC on :1
# - noVNC/websockify on 6080
# - Clawdbot gateway
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
```

### scripts/supervisord.conf

```ini
[supervisord]
nodaemon=true
logfile=/var/log/supervisord.log

[program:gnome-session]
command=/bin/bash -lc "export DISPLAY=:1 && /usr/libexec/gnome-session-binary"
user=developer
autorestart=true
priority=10

[program:vncserver]
command=/bin/bash -lc "vncserver :1 -geometry 1920x1080 -depth 24"
user=developer
autorestart=true
priority=20

[program:novnc]
command=/bin/bash -lc "websockify --web=/usr/share/novnc/ 6080 localhost:5901"
user=developer
autorestart=true
priority=30

[program:clawdbot-gateway]
command=/bin/bash -lc "export CLAWDBOT_HOME=/clawdbot_home && clawdbot daemon"
user=developer
autorestart=true
priority=40
environment=CLAWDBOT_HOME="/clawdbot_home",WORKSPACE="/workspace"
```

You can tweak the GNOME command depending on how it behaves in your base image; people often call `gnome-session` or a small wrapper.

## docker-compose.yml

```yaml
version: "3.9"

services:
  clawdbot-desktop-worker:
    build: .
    container_name: clawdbot-desktop-worker
    restart: unless-stopped
    environment:
      # Clawdbot
      CLAWDBOT_HOME: /clawdbot_home
      WORKSPACE: /workspace

      # VNC/noVNC
      VNC_PASSWORD: ${VNC_PASSWORD:-clawdbot}

      # GPU (for non-swarm you can also use NVIDIA_* envs/runtime)
      NVIDIA_VISIBLE_DEVICES: all
      NVIDIA_DRIVER_CAPABILITIES: compute,utility,video

      # Provider keys etc – set in Coolify
      # ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
      # OPENAI_API_KEY: ${OPENAI_API_KEY}

    # GPU access (host must have NVIDIA Container Toolkit)
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: ["gpu"]

    # No direct host port mapping; Coolify/reverse proxy will handle it
    expose:
      - "18789" # Clawdbot UI/API
      - "6080"  # noVNC web VNC

    volumes:
      - clawdbot_home:/clawdbot_home
      - clawdbot_workspace:/workspace
      # Optional: Docker socket for sandboxes
      # - /var/run/docker.sock:/var/run/docker.sock

    # If your Docker requires explicit runtime:
    # runtime: nvidia

volumes:
  clawdbot_home:
  clawdbot_workspace:
```

This is intentionally minimal but hits your constraints:

- GNOME + VNC + web-based VNC (noVNC) in a single container.  
- Internal ports only; Coolify will route 18789 and 6080 to domains.  
- GPU-ready via NVIDIA devices in Compose.  

You can now push this as the initial commit to `machine-machine/clawdbot-desktop` and refine (e.g., swap base image, adjust GNOME start command, wire in sandbox config).
