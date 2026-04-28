#!/usr/bin/env bash
# MiOS: QEMU Boot Validation
# Validates that a disk image boots successfully and reaches graphical.target.
set -euo pipefail

DISK_IMG="${1:-}"
if [[ -z "$DISK_IMG" || ! -f "$DISK_IMG" ]]; then
    echo "Usage: $0 <disk-image.qcow2>"
    exit 1
fi

TIMEOUT=300
LOG_FILE="qemu-boot.log"

echo "Starting QEMU boot test for $DISK_IMG (Timeout: ${TIMEOUT}s)..."

# Run QEMU in the background with serial output to log
# -nographic: no VGA window
# -serial mon:stdio: multiplexed monitor and serial on stdio
# -m 4G: 4GB RAM
# -snapshot: don't modify the original image
qemu-system-x86_64 \
    -m 4G \
    -smp 2 \
    -cpu host \
    -enable-kvm \
    -drive file="$DISK_IMG",format=qcow2,if=virtio \
    -net nic,model=virtio -net user \
    -nographic \
    -serial file:"$LOG_FILE" \
    -snapshot \
    -device virtio-rng-pci &
QEMU_PID=$!

# Function to kill QEMU on exit
cleanup() {
    echo "Cleaning up QEMU..."
    kill $QEMU_PID 2>/dev/null || true
}
trap cleanup EXIT

echo "Waiting for 'Reached target graphical.target' in serial log..."
START_TIME=$(date +%s)
while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    if grep -q "Reached target graphical.target" "$LOG_FILE" 2>/dev/null; then
        echo "[OK] SUCCESS: graphical.target reached in ${ELAPSED}s"
        exit 0
    fi

    if grep -q "Entering emergency mode" "$LOG_FILE" 2>/dev/null; then
        echo "[FAIL] FAILURE: System entered emergency mode"
        tail -n 20 "$LOG_FILE"
        exit 1
    fi

    if [[ $ELAPSED -gt $TIMEOUT ]]; then
        echo "[FAIL] FAILURE: Boot timed out after ${TIMEOUT}s"
        echo "Last 20 lines of serial log:"
        tail -n 20 "$LOG_FILE"
        exit 1
    fi

    sleep 5
done
