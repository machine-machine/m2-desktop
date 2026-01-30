# clawdbot-desktop

Multi-user HTML5 remote desktop for Clawdbot, using Apache Guacamole for shared session access.

## Features

- **Multi-User Sessions** - Multiple users can view and control the same desktop simultaneously
- **HTML5 Client** - No plugins, works in any modern browser
- **Two Guacamole Options** - Lightweight (guacamole-lite) or Full (Apache Guacamole with user management)
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

**Guacamole-Lite (lightweight, port 8080):**
```
Browser → Guacamole-Lite (8080) → guacd (4822) → x11vnc (5900) → Xorg :0
```

**Full Apache Guacamole (with user management, port 8888):**
```
Browser → Guacamole Full (8888) → guacd (4822) → x11vnc (5900) → Xorg :0
              ↓
         MariaDB (user/connection storage)
```

## Quick Start

### Production (with GPU)

```bash
docker compose up -d
```

**Access Options:**

| Client | URL | Credentials |
|--------|-----|-------------|
| Guacamole-Lite | `https://g1.yourdomain.com` | `developer` / `VNC_PASSWORD` |
| Full Guacamole | `https://g2.yourdomain.com/guacamole` | `guacadmin` / `guacadmin` |

### Local Development (without GPU)

```bash
docker compose -f docker-compose.local.yml up -d
```

**Access Options:**

| Client | URL | Credentials |
|--------|-----|-------------|
| Guacamole-Lite | `http://localhost:8080` | `developer` / `clawdbot` |
| Full Guacamole | `http://localhost:8888/guacamole` | `guacadmin` / `guacadmin` |

> **Important:** Change the default `guacadmin` password immediately after first login!

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
| `VNC_PASSWORD` | `clawdbot` | Password for VNC and guacamole-lite web auth |
| `ANTHROPIC_API_KEY` | - | For Clawdbot |
| `OPENAI_API_KEY` | - | For Clawdbot (optional) |
| `GUAC_DB_ROOT_PASSWORD` | `guacamole_root_pass` | MariaDB root password (Full Guacamole) |
| `GUAC_DB_PASSWORD` | `guacamole_pass` | MariaDB user password (Full Guacamole) |

> **Note:** The Full Guacamole admin user (`guacadmin/guacadmin`) is created in the database init script. Change it via the web UI after first login.

## Coolify Configuration

After deploying, configure domains in Coolify UI:
- Guacamole-Lite: `g1.yourdomain.com` → port **8080**
- Full Guacamole: `g2.yourdomain.com` → port **8888**
- Gateway: `gateway.yourdomain.com` → port **18789**

## Guacamole-Lite vs Full Guacamole

| Feature | Guacamole-Lite (8080) | Full Guacamole (8888) |
|---------|----------------------|----------------------|
| User management | None (token-based) | Full (DB-backed) |
| Connection history | No | Yes |
| Session recording | No | Yes |
| File transfer | Limited | Full SFTP support |
| Multi-user sharing | Yes | Yes (with sharing profiles) |
| Memory footprint | ~50MB (Node.js) | ~500MB (Tomcat/Java) |
| Startup time | Fast | Slower (JVM warmup) |

Use **guacamole-lite** for simple, fast access. Use **full Guacamole** when you need user management, audit logs, or session recording.

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

Desktop settings (XFCE panels, Plank dock, autostart apps, desktop icons) persist across container restarts and rebuilds. They're stored in `/clawdbot_home/desktop-config/`.

**Reset to Defaults:**

If you want to reset your desktop customizations back to the original defaults:

```bash
# Reset all desktop settings
docker compose exec clawdbot-desktop-worker rm -rf /clawdbot_home/desktop-config

# Or reset only specific configs
docker compose exec clawdbot-desktop-worker rm -rf /clawdbot_home/desktop-config/xfce4     # XFCE panels/theme
docker compose exec clawdbot-desktop-worker rm -rf /clawdbot_home/desktop-config/plank     # Dock settings
docker compose exec clawdbot-desktop-worker rm -rf /clawdbot_home/desktop-config/autostart # Startup apps
docker compose exec clawdbot-desktop-worker rm -rf /clawdbot_home/desktop-config/Desktop   # Desktop icons

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
