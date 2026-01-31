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

# Install Claude Code CLI
echo "=== Installing Claude Code CLI ==="
npm install -g @anthropic-ai/claude-code

# Configure npm to use user-local directory for global packages (avoids permission issues)
echo "=== Configuring npm for user installs ==="
mkdir -p /home/developer/.npm-global
chown -R developer:developer /home/developer/.npm-global
su - developer -c 'npm config set prefix /home/developer/.npm-global'

# Add npm-global to PATH in bashrc
echo '' >> /home/developer/.bashrc
echo '# npm global packages' >> /home/developer/.bashrc
echo 'export PATH="/home/developer/.npm-global/bin:$PATH"' >> /home/developer/.bashrc

# Create OpenClaw home directory for persistence
mkdir -p /m2_home/openclaw
chown -R developer:developer /m2_home/openclaw 2>/dev/null || true

echo "=== Node.js and OpenClaw Gateway installed ==="
