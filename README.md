# M2 Desktop

A containerized Linux desktop accessible from any browser. Three remote desktop technologies to choose from based on your needs.

## Quick Start

```bash
# Start the desktop (Guacamole - default)
docker compose up -d

# Open in browser
open http://localhost:8080

# Login: developer / m2desktop
```

## Choose Your Variant

| | noVNC | Guacamole | Selkies |
|---|:---:|:---:|:---:|
| **Best for** | Simple setup | Collaboration | Performance |
| **Multi-user** | - | Yes | - |
| **Latency** | ~100ms | ~70ms | ~20ms |
| **Encoding** | CPU | CPU | GPU |
| **Port** | 6080 | 8080 | 8080 |

```bash
# noVNC - Simple VNC-to-web proxy
docker compose -f docker-compose.novnc.yml up -d

# Guacamole - Multi-user sessions (default)
docker compose up -d

# Selkies - Low-latency WebRTC (requires GPU)
docker compose -f docker-compose.selkies.yml up -d
```

## What's Included

- **XFCE Desktop** with WhiteSur macOS theme
- **Plank dock** for quick app launching
- **Google Chrome** pre-installed
- **Cargstore** app store for Flatpak apps
- **M2 Gateway** AI agent interface (port 18789)
- **Persistent storage** - settings survive container restarts

## Architecture

```
┌──────────────────────────────────────────────┐
│  Docker Container                            │
│                                              │
│  ┌─────────┐   ┌─────────┐   ┌──────────┐   │
│  │  Xorg   │ → │  XFCE4  │ → │  Plank   │   │
│  │ :0/:1   │   │ Desktop │   │  Dock    │   │
│  └────┬────┘   └─────────┘   └──────────┘   │
│       │                                      │
│       ▼                                      │
│  ┌─────────────────────────────────────┐    │
│  │  Remote Access (variant-specific)   │    │
│  │  • Guacamole: x11vnc → guacd → web  │    │
│  │  • noVNC: TigerVNC → websockify     │    │
│  │  • Selkies: GStreamer → WebRTC      │    │
│  └─────────────────────────────────────┘    │
│                                              │
│  Ports: 8080 (web) | 18789 (M2 Gateway)     │
└──────────────────────────────────────────────┘
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VNC_PASSWORD` | `m2desktop` | Web login password |
| `ANTHROPIC_API_KEY` | - | For M2 Gateway AI features |

### Persistent Storage

Desktop settings persist across restarts in `/m2_home/`:

```
/m2_home/
├── desktop-config/    # XFCE, Plank, autostart
└── flatpak/           # Installed Flatpak apps
```

Reset to defaults:
```bash
docker compose exec m2-desktop-worker rm -rf /m2_home/desktop-config
docker compose restart
```

## Multi-User Sessions

The Guacamole variant supports multiple simultaneous users:

- Share the URL with collaborators
- Everyone sees the same desktop
- All users can control mouse/keyboard
- Real-time synchronized view

Use cases: pair programming, remote assistance, demos.

## GPU Support

For Selkies variant or GPU-accelerated apps:

```bash
# Requires: NVIDIA GPU + Driver 525+ + Container Toolkit
docker compose exec m2-desktop-worker nvidia-smi
```

## Service Management

```bash
# Check services
docker compose exec m2-desktop-worker supervisorctl status

# Restart desktop
docker compose exec m2-desktop-worker supervisorctl restart xfce4

# View logs
docker compose exec m2-desktop-worker tail -f /var/log/guacamole.log
```

## Full Apache Guacamole

The default compose includes optional enterprise Guacamole (port 8888):

- User management and authentication
- Connection history and audit logs
- Session recording

Default login: `guacadmin / guacadmin`

## Building

```bash
# Build specific variant
docker build -f Dockerfile.guacamole -t m2-desktop:guacamole .
docker build -f Dockerfile.novnc -t m2-desktop:novnc .
docker build -f Dockerfile.selkies -t m2-desktop:selkies .
```

## License

MIT
