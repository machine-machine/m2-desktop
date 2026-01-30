#!/bin/bash
# =============================================================================
# M2 Desktop - Flatpak + Cargstore Installation
# Installs Flatpak runtime and the Cargstore app store
# =============================================================================
set -e

export DEBIAN_FRONTEND=noninteractive

echo "=== Installing Flatpak ==="

apt-get update
apt-get install -y flatpak
rm -rf /var/lib/apt/lists/*

# Add Flathub repository (system-wide)
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

echo "=== Installing Google Chrome ==="
# Ubuntu's chromium-browser is snap-only, doesn't work in Docker
curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/chrome.deb
apt-get update
apt-get install -y /tmp/chrome.deb
rm /tmp/chrome.deb
rm -rf /var/lib/apt/lists/*

echo "=== Installing Cargstore ==="
CARGSTORE_VERSION="${CARGSTORE_VERSION:-0.2.1}"
mkdir -p /opt/cargstore
curl -fsSL "https://github.com/machine-machine/cargstore/releases/download/v${CARGSTORE_VERSION}/cargstore-${CARGSTORE_VERSION}.tar.gz" \
    | tar -xzf - -C /opt/cargstore --strip-components=1
chmod +x /opt/cargstore/cargstore

# Create desktop entry
cat > /usr/share/applications/cargstore.desktop << 'EOF'
[Desktop Entry]
Name=Cargstore
Comment=App Store for M2 Desktop
Exec=/opt/cargstore/cargstore --no-sandbox %U
Icon=system-software-install
Terminal=false
Type=Application
Categories=System;PackageManager;
StartupWMClass=Cargstore
MimeType=x-scheme-handler/flatpak;
EOF

update-desktop-database /usr/share/applications 2>/dev/null || true

echo "=== Flatpak and Cargstore installed ==="
