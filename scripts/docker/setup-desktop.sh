#!/bin/bash
# =============================================================================
# M2 Desktop - WhiteSur Theme Installation
# Installs macOS-style GTK theme, icons, and cursors
# =============================================================================
set -e

USER_NAME="${M2_USER:-developer}"

echo "=== Installing WhiteSur theme (as ${USER_NAME}) ==="

# Run theme installation as the target user
su - ${USER_NAME} -c '
set -e
cd /tmp

# WhiteSur GTK Theme
echo "Installing WhiteSur GTK theme..."
if git clone https://github.com/vinceliuice/WhiteSur-gtk-theme.git --depth=1 2>/dev/null; then
    cd WhiteSur-gtk-theme
    ./install.sh -c Dark -l -N glassy || echo "WhiteSur GTK install failed, using fallback"
    cd .. && rm -rf WhiteSur-gtk-theme
else
    echo "WhiteSur GTK theme clone failed, using fallback"
fi

# WhiteSur Icon Theme
echo "Installing WhiteSur icon theme..."
if git clone https://github.com/vinceliuice/WhiteSur-icon-theme.git --depth=1 2>/dev/null; then
    cd WhiteSur-icon-theme
    ./install.sh -t default || echo "WhiteSur icon install failed, using fallback"
    cd .. && rm -rf WhiteSur-icon-theme
else
    echo "WhiteSur icon theme clone failed, using fallback"
fi

# McMojave Cursors
echo "Installing McMojave cursors..."
if git clone https://github.com/vinceliuice/McMojave-cursors.git --depth=1 2>/dev/null; then
    cd McMojave-cursors
    ./install.sh || echo "McMojave cursors install failed, using fallback"
    cd .. && rm -rf McMojave-cursors
else
    echo "McMojave cursors clone failed, using fallback"
fi

# Download wallpaper
echo "Downloading WhiteSur wallpaper..."
mkdir -p ~/.local/share/backgrounds
curl -sL "https://raw.githubusercontent.com/vinceliuice/WhiteSur-wallpapers/main/4k/WhiteSur-dark.png" \
    -o ~/.local/share/backgrounds/wallpaper.png || \
    echo "Wallpaper download failed, will use default"

# Create XFCE config directories
mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml
mkdir -p ~/.config/xfce4/panel
mkdir -p ~/.config/plank/dock1/launchers
mkdir -p ~/.local/share/applications
mkdir -p ~/Desktop
'

echo "=== WhiteSur theme installed ==="
