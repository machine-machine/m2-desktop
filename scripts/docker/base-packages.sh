#!/bin/bash
# =============================================================================
# M2 Desktop - Base Packages Installation
# Shared across all variants (noVNC, Guacamole, Selkies)
# =============================================================================
set -e

export DEBIAN_FRONTEND=noninteractive

echo "=== Installing M2 Desktop base packages ==="

apt-get update && apt-get install -y --no-install-recommends \
    # Locale
    locales \
    # Core utilities
    sudo ca-certificates curl wget git nano htop software-properties-common \
    # X11 and display
    xserver-xorg-video-dummy xserver-xorg-core x11-utils x11-xserver-utils xdotool xclip xsel \
    # XFCE4 Desktop (lightweight)
    xfce4 xfce4-terminal xfce4-taskmanager thunar mousepad \
    # Plank dock (macOS-style)
    plank \
    # Theme dependencies
    sassc libglib2.0-dev-bin libxml2-utils gtk2-engines-murrine \
    # Fallback themes (in case WhiteSur fails)
    arc-theme papirus-icon-theme dmz-cursor-theme \
    # Fonts
    fonts-inter fonts-noto fonts-noto-color-emoji fonts-dejavu-core \
    # Browser dependencies (Chrome installed separately)
    fonts-liberation libnss3 libxss1 libasound2 libatk-bridge2.0-0 libgtk-3-0 \
    # Process management & audio
    supervisor dbus dbus-x11 pulseaudio

# Generate locale
locale-gen en_US.UTF-8

# Clean up
rm -rf /var/lib/apt/lists/*

echo "=== Base packages installed ==="
