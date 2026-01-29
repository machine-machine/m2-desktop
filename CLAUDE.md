# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`clawdbot-desktop` is a multi-user HTML5 remote desktop that runs Clawdbot Gateway and exposes a web-based desktop session via Apache Guacamole. It provides a persistent "AI worker PC" with a full Linux desktop inside a container, remotely accessible from any browser with **multi-user session sharing** - multiple users can view and control the same desktop simultaneously.

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
│  ├── x11vnc (priority 25)                       │
│  │   └── Port 5900 (VNC, localhost only)        │
│  ├── guacd (priority 28)                        │
│  │   └── Port 4822 (Guacamole protocol)         │
│  ├── Guacamole-Lite (priority 30)               │
│  │   └── Port 8080 (HTML5 web client)           │
│  └── Clawdbot Gateway (priority 40)             │
│      └── Port 18789 (WebSocket)                 │
│                                                 │
│  Volumes:                                       │
│  ├── /clawdbot_home (config & state)            │
│  │   ├── desktop-config/ (XFCE, Plank)          │
│  │   └── flatpak/ (installed apps)              │
│  └── /workspace (workspace data)                │
└─────────────────────────────────────────────────┘
```

### Data Flow

```
Browser → Guacamole-Lite (8080) → guacd (4822) → x11vnc (5900) → Xorg :0
        WebSocket              Guacamole protocol   VNC protocol   X11
```

**Key Components:**
- Base Image: Ubuntu 22.04
- Remote Desktop: Apache Guacamole (guacd + guacamole-lite)
- VNC Server: x11vnc (shares existing X11 display)
- Desktop: XFCE4 with WhiteSur macOS-style theme + Plank dock
- Display: Xorg with dummy driver at 1920x1080
- Process Manager: Supervisord
- AI Agent: Clawdbot Gateway (Node.js 22.x)

## Build and Run

```bash
# Local development (no GPU, software encoding)
docker compose -f docker-compose.local.yml up -d
# Access: http://localhost:8080

# Production (with GPU for desktop apps)
docker compose up -d

# Rebuild after changes
docker compose build --no-cache

# Get a shell inside the container
docker compose exec clawdbot-desktop-worker bash
```

## Debugging

```bash
# Check service status
supervisorctl status

# View logs
tail -f /var/log/guacamole.log  # Guacamole-Lite
tail -f /var/log/x11vnc.log     # x11vnc VNC server
tail -f /var/log/guacd.log      # guacd protocol daemon
tail -f /var/log/xorg.log       # X server
tail -f /var/log/xfce4.log      # XFCE session
tail -f /var/log/clawdbot.log   # Clawdbot Gateway

# Restart a specific service
supervisorctl restart xfce4
supervisorctl restart guacamole
```

## Key Files

| File | Purpose |
|------|---------|
| `scripts/supervisord.conf` | Process definitions and startup order |
| `scripts/entrypoint.sh` | VNC password setup, starts supervisord |
| `scripts/start-desktop.sh` | XFCE session startup, theme config, Plank launch |
| `scripts/guacamole-server.js` | Guacamole-Lite WebSocket server |
| `config/xorg.conf` | Xorg dummy driver config (1920x1080 resolution) |
| `config/xfce4/` | XFCE panel, theme, and window manager settings |
| `config/plank/` | Plank dock configuration and launcher items |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VNC_PASSWORD` | `clawdbot` | Password for VNC and web authentication |

## Multi-User Session Behavior

Guacamole enables **collaborative desktop sessions**:

- Multiple users can connect to the same desktop simultaneously
- All input/output is shared between connected users
- Actions by one user appear on all screens in real-time

This is different from Selkies which only allows one user at a time. With Guacamole:
- User A connects → sees desktop
- User B connects → sees same desktop, can control it too
- Both see each other's cursor movements and actions

## Coolify Deployment (guacamole branch)

**This section is specific to the `guacamole` branch deployment on Coolify.**

### Network Architecture

The deployment uses **Cloudflare Tunnel** for HTTPS access:

```
┌─────────────┐                         ┌─────────────────┐
│   Browser   │──── WebSocket ─────────▶│ Cloudflare      │──▶ Coolify/Guacamole
│   Client    │                         │ Tunnel          │    (port 8080)
│             │                         │ m2.machinemachine.ai
└─────────────┘                         └─────────────────┘
```

**Key Points:**
- Cloudflare Tunnel proxies HTTP/WebSocket (simpler than Selkies)
- No TURN/STUN servers needed (Guacamole uses WebSocket, not WebRTC)
- Multi-user works through the same connection

### Application Details

| Property | Value |
|----------|-------|
| Project | `machine.machine` |
| Application UUID | `t44s0oww0sc4koko88ocs84w` |
| Container Name Pattern | `clawdbot-desktop-worker-t44s0oww0sc4koko88ocs84w-*` |
| Desktop Port | 8080 (Guacamole HTML5) |
| Gateway Port | 18789 (Clawdbot WebSocket) |
| External URL | `https://m2.machinemachine.ai` (via Cloudflare Tunnel) |

### Deployment Workflow

Commits pushed to the `guacamole` branch trigger a rebuild and redeploy on Coolify.

```bash
# Make changes, commit, and push to trigger deployment
git add <files>
git commit -m "fix: Description of change"
git push origin guacamole

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
docker exec $(docker ps -q --filter "name=clawdbot-desktop-worker") cat /var/log/guacamole.log
docker exec $(docker ps -q --filter "name=clawdbot-desktop-worker") cat /var/log/x11vnc.log
docker exec $(docker ps -q --filter "name=clawdbot-desktop-worker") cat /var/log/guacd.log
docker exec $(docker ps -q --filter "name=clawdbot-desktop-worker") cat /var/log/xfce4.log

# Get shell into container
docker exec -it $(docker ps -q --filter "name=clawdbot-desktop-worker") bash
```

### Common Issues & Fixes

| Issue | Symptom | Fix |
|-------|---------|-----|
| x11vnc crash | `gave up: x11vnc entered FATAL state` | Check Xorg is running first, increase sleep time |
| guacd not connecting | `Connection refused` on 4822 | Check guacd is running: `supervisorctl status guacd` |
| Blank screen | Desktop loads but shows nothing | Check XFCE: `supervisorctl restart xfce4` |
| Auth issues | Can't login with password | Check VNC_PASSWORD env var is set |
| WebSocket error | Browser console WebSocket errors | Check Traefik WebSocket middleware labels |

### Port Mapping

The docker-compose.yml uses Traefik labels for routing:
- Desktop domain → port **8080** (Guacamole HTML5)
- Gateway domain → port **18789** (Clawdbot API)

## Persistent Desktop Settings

Desktop settings (XFCE, Plank dock, autostart apps) persist across container rebuilds.

### How It Works

On container startup, `entrypoint.sh` creates symlinks from the normal config locations to the persistent volume:

```
/home/developer/.config/xfce4/    → /clawdbot_home/desktop-config/xfce4/
/home/developer/.config/plank/    → /clawdbot_home/desktop-config/plank/
/home/developer/.config/autostart/ → /clawdbot_home/desktop-config/autostart/
```

### Resetting to Defaults

```bash
CONTAINER=$(docker ps -q --filter "name=clawdbot-desktop-worker")

# Reset all desktop settings
docker exec $CONTAINER rm -rf /clawdbot_home/desktop-config

# Restart container to reinitialize
docker restart $CONTAINER
```

## Theme System

WhiteSur theme is installed from git during build with fallbacks:
- GTK Theme: WhiteSur-Dark (fallback: Arc)
- Icons: WhiteSur (fallback: Papirus)
- Cursors: McMojave (fallback: DMZ)
- Wallpaper: Downloaded from WhiteSur-wallpapers repo

## Cargstore (App Store)

Cargstore is an Electron-based app store for installing Flatpak applications. It's bundled into the container at `/opt/cargstore/`.

### Persistent Storage

```
/clawdbot_home/
├── desktop-config/             (XFCE, Plank, autostart settings)
│   ├── xfce4/                  (symlinked from ~/.config/xfce4/)
│   ├── plank/                  (symlinked from ~/.config/plank/)
│   └── autostart/              (symlinked from ~/.config/autostart/)
└── flatpak/                    (symlinked from ~/.local/share/flatpak/)
```

## Comparison: Guacamole vs Selkies

| Feature | Guacamole (this branch) | Selkies (selkies branch) |
|---------|-------------------------|--------------------------|
| Multi-user | Yes - shared session | No - single user only |
| Protocol | VNC over WebSocket | WebRTC |
| Latency | ~50-100ms | ~20ms |
| Video encoding | CPU (x11vnc) | GPU (NVENC) |
| TURN servers | Not needed | Required for external users |
| Complexity | Simpler | More complex |
| Cloudflare compatible | Yes, easily | Yes, but needs TURN |

Choose this branch for **multi-user collaboration**. Choose selkies branch for **lowest latency single-user**.
