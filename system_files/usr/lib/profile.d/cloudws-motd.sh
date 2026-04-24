# CloudWS v0.1.8 — Terminal/TTY dashboard
# Shows fastfetch services panel on interactive login.
# Suppress with:  export CLOUDWS_NO_MOTD=1
if [[ $- == *i* ]] && [ -z "${CLOUDWS_NO_MOTD:-}" ]; then
    if command -v fastfetch &>/dev/null; then
        fastfetch 2>/dev/null || true
    elif [[ -x /usr/libexec/cloudws/motd ]]; then
        /usr/libexec/cloudws/motd 2>/dev/null || true
    fi
fi
