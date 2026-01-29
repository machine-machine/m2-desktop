# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`clawdbot-desktop` is a GPU-accelerated Dockerized XFCE4 desktop that runs Clawdbot Gateway and exposes a web-based remote desktop session via Selkies-GStreamer WebRTC streaming. It provides a persistent "AI worker PC" with a full Linux desktop inside a container, remotely accessible from any browser with ~20ms latency using NVENC hardware encoding.

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Coolify (Deployment & Reverse Proxy)           │
├─────────────────────────────────────────────────┤
│  Docker Container (clawdbot-desktop-worker)     │
│                                                 │
│  Supervisord (Process Manager)                  │
│  ├── D-Bus (priority 5)                         │
│  ├── PulseAudio (priority 10)                   │
│  ├── Xorg + dummy driver (priority 15)          │
│  ├── XFCE4 + Plank dock (priority 20)           │
│  ├── Selkies-GStreamer (priority 30)            │
│  │   └── Port 8080 (WebRTC)                     │
│  └── Clawdbot Gateway (priority 40)             │
│      └── Port 18789 (WebSocket)                 │
│                                                 │
│  Volumes:                                       │
│  ├── /clawdbot_home (config & state)            │
│  └── /workspace (workspace data)                │
└─────────────────────────────────────────────────┘
```

**Key Components:**
- Base Image: `ghcr.io/selkies-project/selkies-gstreamer/gstreamer:main-ubuntu20.04`
- Streaming: Selkies-GStreamer v1.6.0 with NVENC hardware encoding
- Desktop: XFCE4 with WhiteSur macOS-style theme + Plank dock
- Display: Xorg with dummy driver at 1920x1080
- Process Manager: Supervisord
- AI Agent: Clawdbot Gateway (Node.js 22.x)

## Build and Run

```bash
# Local development (no GPU, software encoding)
docker compose -f docker-compose.local.yml up -d
# Access: http://localhost:8080

# Production (requires NVIDIA Container Toolkit)
docker compose up -d

# Rebuild after changes
docker compose build --no-cache

# Verify GPU access inside container
docker compose exec clawdbot-desktop-worker nvidia-smi

# Get a shell inside the container
docker compose exec clawdbot-desktop-worker bash
```

## Debugging

```bash
# Check service status
supervisorctl status

# View logs
tail -f /var/log/selkies.log    # Selkies-GStreamer
tail -f /var/log/xorg.log       # X server
tail -f /var/log/xfce4.log      # XFCE session
tail -f /var/log/clawdbot.log   # Clawdbot Gateway

# Restart a specific service
supervisorctl restart xfce4
supervisorctl restart selkies
```

## Key Files

| File | Purpose |
|------|---------|
| `scripts/supervisord.conf` | Process definitions and startup order |
| `scripts/entrypoint.sh` | GPU detection, auth setup, starts supervisord |
| `scripts/start-desktop.sh` | XFCE session startup, theme config, Plank launch |
| `config/xorg.conf` | Xorg dummy driver config (1920x1080 resolution) |
| `config/xfce4/` | XFCE panel, theme, and window manager settings |
| `config/plank/` | Plank dock configuration and launcher items |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VNC_PASSWORD` | `clawdbot` | Maps to `SELKIES_BASIC_AUTH_PASSWORD` |
| `SELKIES_ENCODER` | `nvh264enc` | Video encoder (`nvh264enc` for GPU, `x264enc` for CPU) |
| `SELKIES_FRAMERATE` | `60` | Target framerate (30 for CPU encoding) |
| `SELKIES_VIDEO_BITRATE` | `8000` | Bitrate in kbps |

The entrypoint auto-detects GPU and falls back to `x264enc` with 30fps if no NVIDIA GPU is found.

## Coolify Deployment (selkies branch)

**This section is specific to the `selkies` branch deployment on Coolify.**

### Application Details

| Property | Value |
|----------|-------|
| Project | `machine.machine` |
| Application UUID | `t44s0oww0sc4koko88ocs84w` |
| Coolify URL Path | `/project/q8w4cwskgwkgg0cg00k00coo/environment/tkgkkwc0w0cso4ooc48848c4/application/t44s0oww0sc4koko88ocs84w` |
| Container Name Pattern | `clawdbot-desktop-worker-oksko*` |
| Desktop Port | 8080 (Selkies WebRTC) |
| Gateway Port | 18789 (Clawdbot WebSocket) |

### Deployment Workflow

Commits pushed to the `selkies` branch automatically trigger a rebuild and redeploy on Coolify.

```bash
# Make changes, commit, and push to trigger deployment
git add <files>
git commit -m "fix: Description of change"
git push origin selkies

# Wait ~2-3 minutes for build and deploy
# Then check logs to verify
```

### Debugging from Host (Coolify Server)

The repo is checked out at `/home/hi/coolify-repos/clawdbot-desktop` on the Coolify host.

```bash
# Find the running container
docker ps --filter "name=clawdbot-desktop-worker"

# View container logs (most recent)
docker logs --tail 100 $(docker ps -q --filter "name=clawdbot-desktop-worker")

# Follow logs in real-time
docker logs -f $(docker ps -q --filter "name=clawdbot-desktop-worker")

# Check supervisor status inside container
docker exec $(docker ps -q --filter "name=clawdbot-desktop-worker") supervisorctl status

# View specific service logs inside container
docker exec $(docker ps -q --filter "name=clawdbot-desktop-worker") cat /var/log/selkies.log
docker exec $(docker ps -q --filter "name=clawdbot-desktop-worker") cat /var/log/xorg.log
docker exec $(docker ps -q --filter "name=clawdbot-desktop-worker") cat /var/log/xfce4.log
docker exec $(docker ps -q --filter "name=clawdbot-desktop-worker") cat /var/log/clawdbot.log

# Get shell into container
docker exec -it $(docker ps -q --filter "name=clawdbot-desktop-worker") bash
```

### Coolify MCP (When Available)

The Coolify MCP tools can be used when API access is configured:

```
mcp__coolify__get_application         uuid: t44s0oww0sc4koko88ocs84w
mcp__coolify__get_application_logs    uuid: t44s0oww0sc4koko88ocs84w
mcp__coolify__restart_application     uuid: t44s0oww0sc4koko88ocs84w
```

Note: If MCP returns 403 errors, check the Coolify API token configuration.

### Common Issues & Fixes

| Issue | Symptom | Fix |
|-------|---------|-----|
| Old version deployed | Logs show `vncserver`/`novnc` instead of `selkies` | Push to selkies branch to trigger redeploy |
| vncserver FATAL | `gave up: vncserver entered FATAL state` | Check if using Selkies (expected) or VNC (outdated) |
| Xorg won't start | No display available | Check `/var/log/xorg.log` for driver issues |
| Selkies not connecting | WebSocket errors | Verify Traefik labels and port 8080 exposure |
| Container unhealthy | Healthcheck fails | Check if port 8080 is responding |

### Port Mapping

The docker-compose.yml uses Traefik labels for routing:
- Desktop domain → port **8080** (Selkies WebRTC)
- Gateway domain → port **18789** (Clawdbot API)

WebSocket middleware is configured in `docker-compose.yml` Traefik labels for WebRTC signaling.

## Theme System

WhiteSur theme is installed from git during build with fallbacks:
- GTK Theme: WhiteSur-Dark (fallback: Arc)
- Icons: WhiteSur (fallback: Papirus)
- Cursors: McMojave (fallback: DMZ)
- Wallpaper: Downloaded from WhiteSur-wallpapers repo

Theme settings are applied at runtime in `start-desktop.sh` via `xfconf-query`.
