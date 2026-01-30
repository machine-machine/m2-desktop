# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`m2-desktop` (formerly clawdbot-desktop) is a multi-variant HTML5 remote desktop system with three deployment options:

| Variant | Technology | Multi-user | Best For |
|---------|------------|------------|----------|
| **Guacamole** (default) | x11vnc + guacd + guacamole-lite | Yes | Collaboration |
| **noVNC** | TigerVNC + websockify | No | Simple setup |
| **Selkies** | WebRTC + GStreamer | No | Low latency |

All variants include:
- XFCE4 desktop with WhiteSur macOS-style theme
- Plank dock
- M2 Gateway AI agent interface
- Persistent desktop settings

## Architecture

### Directory Structure

```
m2-desktop/
├── Dockerfile.guacamole          # Default - multi-user (Apache Guacamole protocol)
├── Dockerfile.novnc              # TigerVNC + noVNC
├── Dockerfile.selkies            # Selkies-GStreamer WebRTC
├── docker-compose.yml            # Default → guacamole with Full Guacamole services
├── docker-compose.guacamole.yml  # Guacamole with Full Guacamole + ports
├── docker-compose.novnc.yml      # noVNC variant
├── docker-compose.selkies.yml    # Selkies variant
├── docker-compose.local.yml      # Local dev (guacamole, no GPU)
├── scripts/
│   ├── docker/                   # Shared build scripts
│   │   ├── base-packages.sh      # Core apt packages
│   │   ├── setup-desktop.sh      # XFCE + WhiteSur theme
│   │   ├── setup-user.sh         # developer user creation
│   │   ├── setup-node.sh         # Node.js 22 + M2 Gateway
│   │   └── setup-flatpak.sh      # Flatpak + Cargstore
│   ├── supervisord/              # Variant-specific supervisord configs
│   │   ├── guacamole.conf        # x11vnc + guacd + guacamole-lite
│   │   ├── novnc.conf            # TigerVNC + websockify
│   │   └── selkies.conf          # Selkies-GStreamer
│   ├── entrypoint.sh             # Unified, variant-aware
│   ├── start-desktop.sh          # XFCE session startup
│   └── guacamole-server.js       # Guacamole-lite WebSocket server
├── config/
│   ├── xorg.conf                 # Xorg dummy driver config
│   ├── xfce4/                    # XFCE settings
│   ├── plank/                    # Dock configuration
│   ├── autostart/                # Desktop autostart
│   ├── desktop/                  # Desktop icons
│   └── guacamole/
│       └── initdb.sql            # Full Guacamole DB schema
└── CLAUDE.md                     # This file
```

### Data Flow by Variant

**Guacamole:**
```
Browser → Guacamole-Lite (8080) → guacd (4822) → x11vnc (5900) → Xorg :0
```

**noVNC:**
```
Browser → noVNC/websockify (6080) → TigerVNC (5901) → X :1
```

**Selkies:**
```
Browser ←→ Selkies-GStreamer (8080) ←→ WebRTC ←→ Xorg :0
```

## Build and Run

```bash
# Default (Guacamole variant)
docker compose up -d
# Access: http://localhost:8080

# noVNC variant
docker compose -f docker-compose.novnc.yml up -d
# Access: http://localhost:6080/vnc.html

# Selkies variant (requires GPU)
docker compose -f docker-compose.selkies.yml up -d
# Access: http://localhost:8080

# Local development (no GPU)
docker compose -f docker-compose.local.yml up -d

# Rebuild after changes
docker compose build --no-cache

# Shell into container
docker compose exec m2-desktop-worker bash
```

## Debugging

```bash
# Check service status
docker compose exec m2-desktop-worker supervisorctl status

# View logs
docker compose exec m2-desktop-worker tail -f /var/log/guacamole.log  # Guacamole-Lite
docker compose exec m2-desktop-worker tail -f /var/log/x11vnc.log     # x11vnc
docker compose exec m2-desktop-worker tail -f /var/log/guacd.log      # guacd
docker compose exec m2-desktop-worker tail -f /var/log/xorg.log       # Xorg
docker compose exec m2-desktop-worker tail -f /var/log/xfce4.log      # XFCE
docker compose exec m2-desktop-worker tail -f /var/log/m2-gateway.log # M2 Gateway
docker compose exec m2-desktop-worker tail -f /var/log/novnc.log      # noVNC (novnc variant)
docker compose exec m2-desktop-worker tail -f /var/log/selkies.log    # Selkies (selkies variant)

# Restart a specific service
docker compose exec m2-desktop-worker supervisorctl restart xfce4
docker compose exec m2-desktop-worker supervisorctl restart guacamole
```

## Key Files

| File | Purpose |
|------|---------|
| `scripts/entrypoint.sh` | Unified entrypoint, detects M2_VARIANT |
| `scripts/supervisord/*.conf` | Variant-specific service definitions |
| `scripts/docker/*.sh` | Shared Docker build scripts |
| `scripts/start-desktop.sh` | XFCE session startup, theme config |
| `scripts/guacamole-server.js` | Guacamole-Lite WebSocket server |
| `config/xorg.conf` | Xorg dummy driver (1920x1080, virtual 4096x4096) |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VNC_PASSWORD` | `m2desktop` | Password for VNC and web auth |
| `M2_VARIANT` | `guacamole` | Variant (guacamole/novnc/selkies) |
| `M2_HOME` | `/m2_home` | Persistent storage path |
| `WORKSPACE` | `/workspace` | Workspace data path |
| `SELKIES_ENCODER` | `nvh264enc` | Selkies encoder (auto-detected) |

## Persistence Structure

```
/m2_home/                          # Volume mount (ALL variants)
├── desktop-config/
│   ├── xfce4/                     # Symlinked from ~/.config/xfce4
│   ├── plank/                     # Symlinked from ~/.config/plank
│   ├── autostart/                 # Symlinked from ~/.config/autostart
│   └── Desktop/                   # Symlinked from ~/Desktop
└── flatpak/                       # Symlinked from ~/.local/share/flatpak
```

## Multi-User Sessions (Guacamole Only)

The Guacamole variant enables **collaborative desktop sessions**:
- Multiple users can connect to the same desktop simultaneously
- All input/output is shared between connected users
- Actions by one user appear on all screens in real-time

noVNC and Selkies are single-user only.

## Coolify Deployment

**Application Details:**

| Property | Value |
|----------|-------|
| Project | `machine.machine` |
| Application UUID | `zw4sw440w8k80g0s8cw44kkc` |
| Container Name | `m2-desktop-worker-zw4sw440w8k80g0s8cw44kkc-*` |
| Guacamole-Lite Port | 8080 |
| Full Guacamole Port | 8888 |
| M2 Gateway Port | 18789 |
| External URL (Lite) | `https://g1.machinemachine.ai` |
| External URL (Full) | `https://g2.machinemachine.ai/guacamole` |

**Deployment Workflow:**

Pushing to the main branch triggers automatic rebuild and redeploy on Coolify.

```bash
git add <files>
git commit -m "fix: Description of change"
git push origin main
# Deployment starts automatically
```

**Debugging from Coolify Host:**

```bash
# Find the running container
docker ps --filter "name=m2-desktop-worker"

# View logs
docker logs --tail 100 $(docker ps -q --filter "name=m2-desktop-worker")

# Check supervisor status
docker exec $(docker ps -q --filter "name=m2-desktop-worker") supervisorctl status

# Get shell
docker exec -it $(docker ps -q --filter "name=m2-desktop-worker") bash
```

## Common Issues & Fixes

| Issue | Symptom | Fix |
|-------|---------|-----|
| x11vnc crash | `gave up: x11vnc entered FATAL state` | Check Xorg is running first |
| guacd not connecting | `Connection refused` on 4822 | Check `supervisorctl status guacd` |
| Blank screen | Desktop loads but shows nothing | `supervisorctl restart xfce4` |
| Auth issues | Can't login | Check VNC_PASSWORD env var |
| WebSocket error | Browser console errors | Check Traefik WebSocket config |

## Resetting Desktop Settings

```bash
CONTAINER=$(docker ps -q --filter "name=m2-desktop-worker")

# Reset all desktop settings
docker exec $CONTAINER rm -rf /m2_home/desktop-config

# Restart container to reinitialize
docker restart $CONTAINER
```

## Theme System

WhiteSur theme is installed from git during build with fallbacks:
- GTK Theme: WhiteSur-Dark (fallback: Arc)
- Icons: WhiteSur (fallback: Papirus)
- Cursors: McMojave (fallback: DMZ)
- Wallpaper: WhiteSur-dark.png from WhiteSur-wallpapers repo

## Cargstore (App Store)

Cargstore is an Electron-based app store for installing Flatpak applications. Located at `/opt/cargstore/`.

## Variant-Specific Notes

### Guacamole (Default)
- Multi-user capable
- Uses x11vnc + guacd + guacamole-lite
- Full Guacamole available on port 8888 for enterprise features

### noVNC
- Uses TigerVNC on display :1 (not :0)
- Simple setup, no guacd needed
- Access at `/vnc.html`

### Selkies
- Requires GPU for NVENC encoding (falls back to x264enc)
- Single-user WebRTC
- Needs TURN server for external access through firewalls
- Lowest latency (~20ms vs ~50-100ms)

## Full Apache Guacamole (Optional)

The docker-compose files include optional Full Guacamole services:
- **guacamole-db**: MariaDB for user/connection storage
- **guacamole-full**: Official Tomcat-based Guacamole

Access at port 8888 with default login `guacadmin/guacadmin`.

Features over guacamole-lite:
- User management
- Connection history
- Session recording
- Full SFTP support

## Comparison: All Variants

| Feature | Guacamole | noVNC | Selkies |
|---------|-----------|-------|---------|
| Multi-user | Yes | No | No |
| Protocol | VNC/WebSocket | VNC/WebSocket | WebRTC |
| Latency | ~50-100ms | ~80-150ms | ~20ms |
| Encoding | CPU | CPU | GPU (NVENC) |
| TURN servers | Not needed | Not needed | Required |
| Complexity | Moderate | Simple | Complex |
