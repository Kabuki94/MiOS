#!/usr/bin/env bash
set -euo pipefail
# MiOS v0.1.1 — Post-boot serial log smoke check
# Usage: smoke-check.sh <serial-log>
#
# Analyzes QEMU serial console output for boot health indicators.

SERIAL_LOG="${1:-}"
ERRORS=0

if [[ -z "$SERIAL_LOG" || ! -f "$SERIAL_LOG" ]]; then
    echo "Usage: $0 <serial-log>"
    exit 2
fi

echo "═══ MiOS Smoke Check ═══"

# Check: systemd reached target
if grep -qE "Reached target (Graphical|Multi-User)" "$SERIAL_LOG"; then
    echo "  ✓ systemd target reached"
else
    echo "  ✗ systemd target NOT reached"
    ERRORS=$((ERRORS + 1))
fi

# Check: no kernel panic
if grep -qi "kernel panic" "$SERIAL_LOG"; then
    echo "  ✗ KERNEL PANIC detected"
    ERRORS=$((ERRORS + 1))
else
    echo "  ✓ no kernel panic"
fi

# Check: no systemd emergency
if grep -qi "emergency.target" "$SERIAL_LOG"; then
    echo "  ✗ emergency target entered"
    ERRORS=$((ERRORS + 1))
else
    echo "  ✓ no emergency mode"
fi

# Check: failed units (warning, not fatal)
FAILED_COUNT=$(grep -ci "Failed to start" "$SERIAL_LOG" 2>/dev/null || echo "0")
if [[ "$FAILED_COUNT" -gt 3 ]]; then
    echo "  ⚠ $FAILED_COUNT failed service starts (check log)"
else
    echo "  ✓ failed starts: $FAILED_COUNT (acceptable)"
fi

# Check: SELinux denials
if grep -qi "avc:.*denied" "$SERIAL_LOG"; then
    AVC_COUNT=$(grep -ci "avc:.*denied" "$SERIAL_LOG" 2>/dev/null || echo "0")
    echo "  ⚠ $AVC_COUNT SELinux denials (review with audit2allow)"
else
    echo "  ✓ no SELinux denials in serial log"
fi

echo "═══ Result: $ERRORS critical errors ═══"
exit "$ERRORS"