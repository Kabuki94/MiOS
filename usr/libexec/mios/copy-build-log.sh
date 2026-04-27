#!/usr/bin/env bash
set -euo pipefail

# This script runs on boot to copy the embedded build log to the mios user's home directory.

SOURCE_LOG="/usr/share/mios/build-logs/latest-build.log"
DEST_DIR="/home/mios/logs"
DEST_LOG="${DEST_DIR}/last-build.log"

if [ ! -f "$SOURCE_LOG" ]; then
    # Source log doesn't exist, nothing to do.
    # This might happen on images that weren't built with an embedded log.
    exit 0
fi

# Ensure the destination directory exists
mkdir -p "$DEST_DIR"

# Copy the log and set ownership
cp "$SOURCE_LOG" "$DEST_LOG"
chown mios:mios "$DEST_DIR"
chown mios:mios "$DEST_LOG"

# Make it read-only for the user to prevent accidental deletion
chmod 0444 "$DEST_LOG"
