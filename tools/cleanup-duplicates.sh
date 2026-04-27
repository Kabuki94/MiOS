#!/bin/bash
# Remove duplicate files now that bootstrap has native Linux FS structure
set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "MiOS Repository Cleanup - Remove Duplicates"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Files to remove (superseded by prepare-bootstrap-native.sh)
echo ""
echo "▶ Removing superseded bootstrap integration script..."
if [[ -f "tools/log-to-bootstrap.sh" ]]; then
    echo "  Removing: tools/log-to-bootstrap.sh (replaced by prepare-bootstrap-native.sh)"
    rm -f tools/log-to-bootstrap.sh
    echo "  ✓ Removed"
fi

# Remove old wiki/bootstrap structure docs (info now in bootstrap repo)
echo ""
echo "▶ Checking for old Wiki integration files..."
if [[ -f "specs/engineering/2026-04-27-Artifact-ENG-007-Bootstrap-Integration.md" ]]; then
    echo "  Note: specs/engineering/2026-04-27-Artifact-ENG-007-Bootstrap-Integration.md"
    echo "        → Now in bootstrap at /usr/share/doc/mios/MiOSv0.1.2/engineering/"
    echo "        → Keeping in main repo for reference"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Cleanup Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Superseded files removed:"
echo "  - tools/log-to-bootstrap.sh (replaced by prepare-bootstrap-native.sh)"
echo ""
echo "Bootstrap repository now has:"
echo "  - Unified Linux FS native structure"
echo "  - All artifacts in /var/lib/mios/artifacts/"
echo "  - All documentation in /usr/share/doc/mios/"
echo "  - All logs in /var/log/mios/"
echo ""
echo "Main repository keeps:"
echo "  - tools/prepare-bootstrap-native.sh (Linux FS native preparation)"
echo "  - Source files (specs/, automation/, etc.)"
echo "  - Build artifacts (for local compression)"
echo ""
