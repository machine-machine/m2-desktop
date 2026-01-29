# clawdbot-desktop

Multi-user HTML5 remote desktop for Clawdbot, using Apache Guacamole for shared session access.

## Features

- **Multi-User Sessions** - Multiple users can view and control the same desktop simultaneously
- **HTML5 Client** - No plugins, works in any modern browser
- **Pretty XFCE Desktop** - WhiteSur macOS-style theme + Plank dock
- **Clawdbot Gateway** - Installed and running as a daemon
- **Audio Support** - PulseAudio streaming included
- **GPU Acceleration** - For desktop applications (Chrome, etc.)

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Coolify (Deployment & Reverse Proxy)           │
├─────────────────────────────────────────────────┤
│  Docker Container (clawdbot-desktop-worker)     │
│                                                 │
│  Supervisord (Process Manager)                  │
│  ├── Xorg (dummy) (:0 display, 1920x1080)       │
│  ├── XFCE4 + Plank (Desktop environment)        │
│  ├── x11vnc (shares :0 on port 5900)            │
│  ├── guacd (protocol daemon, port 4822)         │
│  ├── Guacamole-Lite (HTML5 client)              │
│  │   └── Port 8080 (HTTP/WebSocket)             │
│  └── Clawdbot Daemon                            │
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
```

## Quick Start

### Production (with GPU)

```bash
docker compose up -d
```

Access: `https://desktop.yourdomain.com`
- Username: `developer`
- Password: value of `VNC_PASSWORD` (default: `clawdbot`)

### Local Development (without GPU)

```bash
docker compose -f docker-compose.local.yml up -d
```

Access: `http://localhost:8080`

## Multi-User Sessions

Guacamole enables **collaborative desktop sessions**:

- Multiple users can connect to the same desktop simultaneously
- All input/output is shared between connected users
- Actions by one user appear on all screens in real-time
- No special configuration needed - just share the URL

This is ideal for:
- Pair programming with AI agents
- Remote assistance and training
- Collaborative design work
- Sharing desktop demos

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VNC_PASSWORD` | `clawdbot` | Password for both VNC and web authentication |
| `ANTHROPIC_API_KEY` | - | For Clawdbot |
| `OPENAI_API_KEY` | - | For Clawdbot (optional) |

## Coolify Configuration

After deploying, configure domains in Coolify UI:
- Desktop: your domain → port **8080**
- Gateway: your domain → port **18789**

## GPU Requirements

- NVIDIA GPU (optional, for desktop apps)
- NVIDIA Driver 525+ on host
- NVIDIA Container Toolkit

Verify GPU access:
```bash
docker compose exec clawdbot-desktop-worker nvidia-smi
```

## Working with the Environment

### Getting a Shell

To get an interactive root shell inside the running container:
```bash
docker compose exec clawdbot-desktop-worker bash
```

### Managing Services

The container uses `supervisor` to manage all internal processes:

- **Check status of all services:**
  ```bash
  supervisorctl status
  ```

- **Restart a specific service:**
  ```bash
  supervisorctl restart xfce4
  supervisorctl restart guacamole
  ```

### Persistent Desktop Settings

Desktop settings (XFCE panels, Plank dock, autostart apps) persist across container restarts and rebuilds. They're stored in `/clawdbot_home/desktop-config/`.

**Reset to Defaults:**

If you want to reset your desktop customizations back to the original defaults:

```bash
# Reset all desktop settings
docker compose exec clawdbot-desktop-worker rm -rf /clawdbot_home/desktop-config

# Or reset only specific configs
docker compose exec clawdbot-desktop-worker rm -rf /clawdbot_home/desktop-config/xfce4   # XFCE panels/theme
docker compose exec clawdbot-desktop-worker rm -rf /clawdbot_home/desktop-config/plank   # Dock settings
docker compose exec clawdbot-desktop-worker rm -rf /clawdbot_home/desktop-config/autostart  # Startup apps

# Restart to apply defaults
docker compose restart
```

### Key Configuration Files

- **/etc/supervisor/conf.d/supervisord.conf**: Defines all services
- **/etc/X11/xorg.conf**: Xorg configuration
- **/usr/local/bin/start-desktop.sh**: XFCE session startup
- **/opt/guacamole-lite/server.js**: Guacamole web server
- **~/.config/xfce4/**: XFCE4 settings (symlinked to persistent storage)

### Viewing Logs

Logs for each supervised service are located in `/var/log/`:

```bash
tail -f /var/log/guacamole.log  # Guacamole-Lite
tail -f /var/log/x11vnc.log     # x11vnc (VNC server)
tail -f /var/log/guacd.log      # guacd (protocol daemon)
tail -f /var/log/xorg.log       # X server
tail -f /var/log/xfce4.log      # XFCE session
tail -f /var/log/clawdbot.log   # Clawdbot Gateway
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

Choose Guacamole for **multi-user collaboration**. Choose Selkies for **lowest latency single-user**.

## License

MIT
