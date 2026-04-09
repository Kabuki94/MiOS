#!/bin/sh
# CloudWS — xRDP session launcher
# Bypasses xRDP login screen, launches GNOME session directly.
# For Hyper-V Enhanced Session (vsock).

# Source system and user profile
if [ -r /etc/profile ]; then
    . /etc/profile
fi

# Set GNOME environment
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=GNOME
export XDG_SESSION_DESKTOP=gnome
export GNOME_SHELL_SESSION_MODE=gnome

# Cursor theme (prevents grey box fallback)
export XCURSOR_THEME=Bibata-Modern-Classic
export XCURSOR_SIZE=24

# Launch GNOME session on X11 (xRDP requires X11 backend)
exec gnome-session
