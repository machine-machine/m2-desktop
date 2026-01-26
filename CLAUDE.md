# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`clawdbot-desktop` is a GPU-enabled Dockerized GNOME desktop that runs Clawdbot Gateway and exposes a web-based VNC (noVNC) session and Clawdbot UI via Coolify and an external reverse proxy. It provides a persistent "AI worker PC" with a full Linux GNOME desktop inside a container, remotely accessible from any browser.

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
│                                             │
│  GPU Access (NVIDIA devices)                │
└─────────────────────────────────────────────┘
```

**Key Technology Stack:**
- Base Image: `nvidia/cuda:12.4.1-runtime-ubuntu22.04`
- Desktop: GNOME with TigerVNC and noVNC (HTML5 VNC client)
- Runtime: Docker + Docker Compose deployed via Coolify
- Process Manager: Supervisord (manages GNOME, VNC, noVNC, Clawdbot)
- AI Agent: Clawdbot Gateway (Node.js 22.x)

## Repository Layout

- `Dockerfile` - Builds GNOME + VNC + noVNC + Clawdbot image
- `docker-compose.yml` - Production stack for Coolify (no host ports, GPU reservations, volumes)
- `docker-compose.local.yml` - Local development (no GPU, with port mappings)
- `scripts/entrypoint.sh` - Bootstraps supervisord and environment
- `scripts/supervisord.conf` - Defines Xvnc, GNOME, noVNC, Clawdbot processes
- `config/clawdbot.config.sample.json` - Optional sandbox and workspace defaults
- `docs/prd.md` - Product requirements document

## Build and Run

```bash
# Local development (no GPU)
docker compose -f docker-compose.local.yml up -d

# Production (requires NVIDIA Container Toolkit)
docker compose up -d

# Verify GPU access inside container
docker compose exec clawdbot-desktop-worker nvidia-smi
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VNC_PASSWORD` | `clawdbot` | VNC connection password |
| `CLAWDBOT_HOME` | `/clawdbot_home` | Clawdbot data directory |
| `WORKSPACE` | `/workspace` | Workspace directory |
| `ANTHROPIC_API_KEY` | - | Set in Coolify for Clawdbot |
| `OPENAI_API_KEY` | - | Set in Coolify for Clawdbot |

## Exposed Ports (Internal)

- `6080` - noVNC web interface (routed via Coolify reverse proxy)
- `18789` - Clawdbot UI/API gateway (routed via Coolify reverse proxy)

## Coolify Deployment

1. Connect GitHub repo in Coolify
2. Select Docker Compose build pack
3. Configure environment variables and storage volumes
4. Deploy - Coolify handles HTTPS and reverse proxy routing

## Supervisord Process Priority

Processes start in this order (lower number = higher priority):
1. `xvnc` (priority 10) - Xtigervnc on :1 (port 5901)
2. `gnome-session` (priority 20) - GNOME desktop (sleeps 2s for Xvnc)
3. `novnc` (priority 30) - websockify on 6080 (sleeps 3s)
4. `clawdbot-gateway` (priority 40) - Clawdbot Gateway on 18789 (sleeps 5s)

All processes are configured with `autorestart=true`.
