#!/bin/bash
# =============================================================================
# M2 Desktop - Node.js + M2 Gateway Installation
# Installs Node.js 22.x and the M2 Gateway CLI tool
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

# Install M2 Gateway (formerly clawdbot)
# Note: The npm package is still 'clawdbot' until renamed
echo "=== Installing M2 Gateway ==="
npm install -g clawdbot@latest

echo "=== Node.js and M2 Gateway installed ==="
