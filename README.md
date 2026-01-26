# clawdbot-desktop

GPU-enabled Dockerized GNOME desktop that runs Clawdbot Gateway and exposes a web-based VNC (noVNC) session and Clawdbot UI via Coolify and an external reverse proxy.

## Features

- **Persistent AI Worker PC** - Full Linux GNOME desktop inside a container, remotely accessible from any browser
- **Clawdbot Gateway** - Installed and running as a daemon with persistent configuration
- **GPU Access** - NVIDIA Container Toolkit support for ML/AI workloads
- **Web-based VNC** - Access the desktop via noVNC (HTML5) - no client installation required

## Architecture

```
┌─────────────────────────────────────────────┐
│  Coolify (Deployment & Reverse Proxy)       │
├─────────────────────────────────────────────┤
│  Docker Container (clawdbot-desktop-worker) │
│                                             │
│  Supervisord (Process Manager)              │
│  ├── GNOME Session (:1 display)             │
│  ├── TigerVNC Server (localhost:5901)       │
│  ├── noVNC/websockify (0.0.0.0:6080)        │
│  └── Clawdbot Daemon (0.0.0.0:18789)        │
│                                             │
│  Volumes:                                   │
│  ├── /clawdbot_home (config & state)        │
│  └── /workspace (workspace data)            │
└─────────────────────────────────────────────┘
```

## Prerequisites

- Docker with Docker Compose
- NVIDIA Container Toolkit (for GPU support)
- Coolify (for deployment) or any reverse proxy

## Quick Start

### Local Development (without GPU)

A separate compose file is provided for local testing on machines without NVIDIA GPUs:

```bash
# Clone the repository
git clone git@github.com:machine-machine/clawdbot-desktop.git
cd clawdbot-desktop

# Build and run locally (no GPU required)
docker compose -f docker-compose.local.yml up -d
```

Access:
- **noVNC Desktop**: http://localhost:6080/vnc.html (password: `clawdbot`)
- **Clawdbot Gateway**: ws://localhost:18789

### Production Deployment (with GPU)

```bash
# Build the image
docker compose build

# Run (requires NVIDIA Container Toolkit)
docker compose up -d
```

### Coolify Deployment

1. Connect the GitHub repository in Coolify
2. Select **Docker Compose** build pack
3. Configure environment variables:
   - `VNC_PASSWORD` - VNC connection password (default: `clawdbot`)
   - `ANTHROPIC_API_KEY` - Your Anthropic API key
   - `OPENAI_API_KEY` - Your OpenAI API key (optional)
4. Configure storage volumes:
   - `clawdbot_home` - Clawdbot configuration and state
   - `clawdbot_workspace` - Workspace data
5. Deploy

Coolify will handle HTTPS and reverse proxy routing to the exposed ports.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VNC_PASSWORD` | `clawdbot` | VNC connection password |
| `CLAWDBOT_HOME` | `/clawdbot_home` | Clawdbot data directory |
| `WORKSPACE` | `/workspace` | Workspace directory |
| `ANTHROPIC_API_KEY` | - | Anthropic API key for Clawdbot |
| `OPENAI_API_KEY` | - | OpenAI API key for Clawdbot |

## Exposed Ports

| Port | Service | Description |
|------|---------|-------------|
| 6080 | noVNC | Web-based VNC interface |
| 18789 | Clawdbot | Clawdbot UI and API gateway |

## GPU Support

The container is configured to use NVIDIA GPUs via the NVIDIA Container Toolkit. Verify GPU access:

```bash
docker compose exec clawdbot-desktop-worker nvidia-smi
```

### Troubleshooting GPU Access

1. Ensure NVIDIA Container Toolkit is installed on the host:
   ```bash
   nvidia-ctk --version
   ```

2. Verify Docker can see the GPU:
   ```bash
   docker run --rm --gpus all nvidia/cuda:12.4.1-runtime-ubuntu22.04 nvidia-smi
   ```

3. If using Docker Compose without GPU support, uncomment the `runtime: nvidia` line in `docker-compose.yml`

## Sandbox Configuration

For Clawdbot sandboxed tool containers, optionally mount the Docker socket:

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

A sample sandbox configuration is provided in `config/clawdbot.config.sample.json`.

## Clawdbot Onboarding

On first access, configure Clawdbot via the CLI inside the container:

```bash
docker compose exec clawdbot-desktop-worker clawdbot setup
docker compose exec clawdbot-desktop-worker clawdbot configure
```

Or use the interactive onboarding wizard:

```bash
docker compose exec clawdbot-desktop-worker clawdbot onboard
```

## Known Limitations

- **GNOME on non-GPU hosts**: The GNOME desktop may not start properly on hosts without proper GPU/display support. On such hosts, the VNC server will still be accessible but may show a blank screen. This works correctly on Linux hosts with NVIDIA GPUs.
- **ARM architecture**: Tested on both ARM64 (Apple Silicon) and x86_64 (Threadripper). Some GNOME features may behave differently between architectures.

## Resource Requirements

- **CPU**: 4+ vCPU recommended
- **RAM**: 8-16 GB recommended
- **GPU**: NVIDIA GPU(s) - configured to use all available GPUs
- **Storage**: Sufficient for volumes

## License

MIT
