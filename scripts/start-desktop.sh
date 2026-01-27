#!/bin/bash

# Wait for X server
while ! xdpyinfo -display :0 &>/dev/null; do
    echo "Waiting for X server..."
    sleep 1
done

export DISPLAY=:0
export XDG_RUNTIME_DIR=/tmp/runtime-developer
export DBUS_SESSION_BUS_ADDRESS=$(dbus-launch --sh-syntax | grep DBUS_SESSION_BUS_ADDRESS | cut -d= -f2- | tr -d "'")

# Apply XFCE settings
xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
xfconf-query -c xsettings -p /Net/ThemeName -s "WhiteSur-Dark" 2>/dev/null || true
xfconf-query -c xsettings -p /Net/IconThemeName -s "WhiteSur-dark" 2>/dev/null || true
xfconf-query -c xsettings -p /Gtk/CursorThemeName -s "McMojave-cursors" 2>/dev/null || true

# Set wallpaper
if [ -f ~/.local/share/backgrounds/wallpaper.png ]; then
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorscreen/workspace0/last-image \
        -s ~/.local/share/backgrounds/wallpaper.png 2>/dev/null || true
fi

# Start Plank dock
plank &

# Start XFCE4 session
exec startxfce4
