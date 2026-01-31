#!/bin/bash
# =============================================================================
# M2 Desktop - Node.js + OpenClaw Installation
# Installs Node.js 22.x and the OpenClaw Gateway CLI tool
# =============================================================================
set -e

export DEBIAN_FRONTEND=noninteractive

echo "=== Installing Node.js 22.x ==="

# Install Node.js from nodesource
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs
rm -rf /var/lib/apt/lists/*

# Verify installation
node --version
npm --version

# Install OpenClaw Gateway
echo "=== Installing OpenClaw Gateway ==="
npm install -g openclaw@latest

# Create OpenClaw home directory for persistence
mkdir -p /m2_home/openclaw
chown -R developer:developer /m2_home/openclaw 2>/dev/null || true

echo "=== Node.js and OpenClaw Gateway installed ==="
