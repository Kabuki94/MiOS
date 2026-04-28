# MiOS Flatpak Layering System

**Version:** 1.0.0
**Script:** [mios-flatpak-install.sh](../usr/libexec/mios-flatpak-install.sh)
**System Defaults:** [flatpak-list](../usr/share/mios/flatpak-list)
**User Template:** [flatpaks.list](../etc/mios/templates/flatpaks.list)

---

## Overview

MiOS implements a **4-tier Flatpak layering system** that automatically merges:

1. **User-space lists** (`~/.config/mios/flatpaks.list`) - Highest priority
2. **User environment variables** (`~/.env.mios`) - User-defined
3. **System environment variables** (`/usr/lib/mios/env.d/flatpaks.env`) - Build-time
4. **System defaults** (`/usr/share/mios/flatpak-list`) - **MiOS baseline apps**

All layers are **merged together** (not replaced) and deduplicated before installation.

---

## MiOS Default Flatpaks (System Layer)

**Location:** `/usr/share/mios/flatpak-list`

These are the **baseline apps** shipped with every MiOS image:

```
org.mozilla.firefox            # Web browser
org.libreoffice.LibreOffice    # Office suite
org.gnome.Ptyxis               # Terminal
io.missioncenter.MissionCenter # System monitor
com.mattjakeman.ExtensionManager # GNOME extensions
org.gnome.Loupe                # Image viewer
org.gnome.TextEditor           # Text editor
org.gnome.Calculator           # Calculator
org.gnome.clocks               # Clock/timer
```

**Total:** 9 default apps

---

## Priority & Merge Behavior

### Installation Priority (Highest → Lowest)

```
┌─────────────────────────────────────────────────────┐
│ A. USER SPACE (~/.config/mios/flatpaks.list)       │  ← HIGHEST PRIORITY
│    Per-user customization                          │
└─────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────┐
│ B. USER ENV (~/.env.mios)                          │
│    MIOS_FLATPAKS="app1,app2,app3"                  │
└─────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────┐
│ C. SYSTEM ENV (/usr/lib/mios/env.d/flatpaks.env)   │
│    Build-time MIOS_FLATPAKS (from --build-arg)     │
└─────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────┐
│ D. SYSTEM DEFAULT (/usr/share/mios/flatpak-list)   │  ← LOWEST PRIORITY
│    MiOS baseline apps (9 apps)                     │  (ALWAYS INCLUDED)
└─────────────────────────────────────────────────────┘
                    │
                    ▼
              ┌─────────────┐
              │ MERGE + DEDUP│
              └─────────────┘
                    │
                    ▼
           ┌──────────────────┐
           │ flatpak install  │
           └──────────────────┘
```

### Merge Algorithm

```bash
# From mios-flatpak-install.sh lines 41-86

FINAL_LIST=$(mktemp)

# A. User space lists
for user in $(all users with uid >= 1000); do
    if [ -f ~/.config/mios/flatpaks.list ]; then
        cat ~/.config/mios/flatpaks.list >> $FINAL_LIST
    fi
done

# B. User environment files
for user in $(all users); do
    if [ -f ~/.env.mios ]; then
        grep "MIOS_FLATPAKS=" ~/.env.mios | extract_value | tr ',' '\n' >> $FINAL_LIST
    fi
done

# C. System environment variables
if [ -n "${MIOS_FLATPAKS:-}" ]; then
    echo "$MIOS_FLATPAKS" | tr ',' '\n' >> $FINAL_LIST
fi

# D. System defaults
if [ -f /usr/share/mios/flatpak-list ]; then
    cat /usr/share/mios/flatpak-list >> $FINAL_LIST
fi

# Deduplicate (keeps first occurrence)
sort -u "$FINAL_LIST" -o "$FINAL_LIST"

# Install all unique apps
flatpak install -y --system flathub $(cat $FINAL_LIST)
```

**Key Points:**
- ✅ All layers are **additive** (merged, not replaced)
- ✅ Duplicates are **automatically removed**
- ✅ System defaults are **always included** unless explicitly uninstalled later
- ✅ Users can add apps without losing defaults

---

## Usage Examples

### Example 1: User Adds Apps to Defaults

**System default** (`/usr/share/mios/flatpak-list`):
```
org.mozilla.firefox
org.libreoffice.LibreOffice
org.gnome.Ptyxis
```

**User adds** (`~/.config/mios/flatpaks.list`):
```
com.visualstudio.code
org.blender.Blender
```

**Final result** (merged):
```
org.mozilla.firefox
org.libreoffice.LibreOffice
org.gnome.Ptyxis
com.visualstudio.code
org.blender.Blender
```

**Total:** 5 apps (3 defaults + 2 user)

---

### Example 2: Build-Time + User-Space Layering

**Build-time** (via `podman build --build-arg MIOS_FLATPAKS="org.gnome.Boxes,com.github.tchx84.Flatseal"`):
```
org.gnome.Boxes
com.github.tchx84.Flatseal
```

**User adds** (`~/.config/mios/flatpaks.list`):
```
org.signal.Signal
com.discordapp.Discord
```

**System defaults** (`/usr/share/mios/flatpak-list`):
```
org.mozilla.firefox
org.libreoffice.LibreOffice
[... 7 more defaults]
```

**Final result** (merged):
```
org.mozilla.firefox            # From system default
org.libreoffice.LibreOffice    # From system default
org.gnome.Ptyxis               # From system default
[... 6 more defaults]
org.gnome.Boxes                # From build-time arg
com.github.tchx84.Flatseal     # From build-time arg
org.signal.Signal              # From user space
com.discordapp.Discord         # From user space
```

**Total:** 13 apps (9 defaults + 2 build-time + 2 user)

---

### Example 3: Duplicate Handling

**Build-time**:
```
MIOS_FLATPAKS="org.mozilla.firefox,com.visualstudio.code"
```

**User space** (`~/.config/mios/flatpaks.list`):
```
org.mozilla.firefox
org.blender.Blender
```

**System defaults**:
```
org.mozilla.firefox
[... 8 more defaults]
```

**Final result** (deduplicated):
```
org.mozilla.firefox            # Only installed ONCE (from first occurrence)
org.libreoffice.LibreOffice    # From system default
[... 7 more defaults]
com.visualstudio.code          # From build-time
org.blender.Blender            # From user space
```

**Total:** 11 apps (duplicate `firefox` removed)

---

## Build-Time Flatpak Injection

### Via Containerfile ARG

```dockerfile
ARG MIOS_FLATPAKS=

RUN if [[ -n "${MIOS_FLATPAKS}" ]]; then \
        echo "${MIOS_FLATPAKS}" | tr ',' '\n' > /ctx/usr/share/mios/flatpak-list; \
    fi
```

**Behavior:**
- If `MIOS_FLATPAKS` is provided, it **overwrites** `/usr/share/mios/flatpak-list` in the image
- This becomes the new "system default" for that image
- Users can still add more via `~/.config/mios/flatpaks.list`

---

### Via Justfile

```bash
just build
# Uses env_var_or_default("MIOS_FLATPAKS", "")

# Custom build with Flatpaks
MIOS_FLATPAKS="org.gnome.Boxes,com.github.tchx84.Flatseal" just build
```

---

### Via build-mios.sh (Fedora Server Ignition)

**Interactive prompt:**
```bash
Enter Flatpak app IDs (comma-separated, optional): org.gnome.Boxes,com.visualstudio.code
```

**Script creates** (`~/.config/mios/flatpaks.list`):
```
org.gnome.Boxes
com.visualstudio.code
```

**On first boot:**
- mios-flatpak-install.service runs
- Merges user list + system defaults
- Installs all unique apps

---

## User Configuration Workflow

### Step 1: Initialize User Space

```bash
# Run once to create user config directory
mios init

# Or manually
mkdir -p ~/.config/mios
cp /etc/mios/templates/flatpaks.list ~/.config/mios/flatpaks.list
```

---

### Step 2: Edit User Flatpak List

```bash
vim ~/.config/mios/flatpaks.list
```

**Example:**
```
# My Custom Apps
com.visualstudio.code
org.blender.Blender
org.gimp.GIMP
com.discordapp.Discord
org.signal.Signal

# Development Tools
io.podman_desktop.PodmanDesktop
com.github.GradienceTeam.Gradience

# Media
org.kde.kdenlive
org.audacityteam.Audacity
```

---

### Step 3: Trigger Installation

**Method 1: Wait for next boot**
```bash
# mios-flatpak-install.service runs automatically on boot
sudo reboot
```

**Method 2: Manual installation**
```bash
# Run the installer script directly
sudo /usr/libexec/mios-flatpak-install.sh
```

**Method 3: Via systemd service**
```bash
# Restart the one-shot service
sudo systemctl start mios-flatpak-install.service
```

---

## Environment Variable Method

### User Environment File (`~/.env.mios`)

```bash
# Create user environment file
cat > ~/.env.mios << 'EOF'
MIOS_FLATPAKS="org.gnome.Boxes,com.github.tchx84.Flatseal,org.signal.Signal"
EOF

# Trigger installation
sudo /usr/libexec/mios-flatpak-install.sh
```

**Advantages:**
- Single-line definition
- Easier for scripts to parse
- Compatible with dotenv tooling

**Disadvantages:**
- Less readable than multi-line list
- Harder to comment out individual apps

---

## System Environment File (Build-Time)

**Location:** `/usr/lib/mios/env.d/flatpaks.env`

**Created by:** `automation/37-flatpak-env.sh` during image build

**Contents:**
```bash
# MiOS System Environment Definition
# Generated at build time: 2026-04-28T12:00:00Z
MIOS_FLATPAKS="org.gnome.Boxes,com.github.tchx84.Flatseal"
```

**Purpose:**
- Captures `MIOS_FLATPAKS` build-arg
- Baked into OCI image at `/usr/lib/mios/env.d/flatpaks.env`
- Read by `mios-flatpak-install.sh` on first boot
- Merged with user lists and system defaults

---

## Automatic Installation Flow

### First Boot Sequence

```
System Boot
    │
    ▼
┌────────────────────────────────────────┐
│ mios-flatpak-install.service (oneshot) │
│ ExecStart=/usr/libexec/mios-flatpak-  │
│           install.sh                   │
└────────────────────────────────────────┘
    │
    ▼
┌────────────────────────────────────────┐
│ 1. Source system environment           │
│    /usr/lib/mios/env.d/flatpaks.env    │
└────────────────────────────────────────┘
    │
    ▼
┌────────────────────────────────────────┐
│ 2. Configure Flatpak remotes           │
│    - Add flathub                       │
│    - Disable fedora/fedora-testing     │
└────────────────────────────────────────┘
    │
    ▼
┌────────────────────────────────────────┐
│ 3. Aggregate all Flatpak lists         │
│    A. ~/.config/mios/flatpaks.list     │
│    B. ~/.env.mios (MIOS_FLATPAKS)      │
│    C. System env vars                  │
│    D. /usr/share/mios/flatpak-list     │
└────────────────────────────────────────┘
    │
    ▼
┌────────────────────────────────────────┐
│ 4. Deduplicate (sort -u)               │
└────────────────────────────────────────┘
    │
    ▼
┌────────────────────────────────────────┐
│ 5. Install all unique apps             │
│    flatpak install -y --system         │
│    flathub <app-id>                    │
└────────────────────────────────────────┘
    │
    ▼
┌────────────────────────────────────────┐
│ 6. Apply global overrides              │
│    - Dark theme (ADW_DEBUG_COLOR_      │
│      SCHEME=prefer-dark)               │
│    - Cursor theme (Bibata)             │
│    - GTK theme (adw-gtk3-dark)         │
└────────────────────────────────────────┘
    │
    ▼
┌────────────────────────────────────────┐
│ 7. Mark version complete                │
│    /etc/mios/.flatpak-version          │
└────────────────────────────────────────┘
```

### Version Tracking

**File:** `/etc/mios/.flatpak-version`

**Contents:** `<script version>-<sha256 hash>`

**Purpose:**
- Prevents re-running on every boot
- Re-runs if script version or hash changes
- Allows forced re-run by deleting version file

**Example:**
```bash
# Check version
cat /etc/mios/.flatpak-version
# Output: 4-a1b2c3d4e5f6...

# Force re-run
sudo rm /etc/mios/.flatpak-version
sudo systemctl start mios-flatpak-install.service
```

---

## Global Flatpak Overrides

**Applied by:** `mios-flatpak-install.sh` (lines 103-107)

```bash
# Dark theme
flatpak override --system --env=ADW_DEBUG_COLOR_SCHEME=prefer-dark
flatpak override --system --env=GTK_THEME=adw-gtk3-dark

# Cursor theme
flatpak override --system --env=XCURSOR_THEME=Bibata-Modern-Classic
flatpak override --system --env=XCURSOR_SIZE=24

# Filesystem access (for theme consistency)
flatpak override --system --filesystem=xdg-config/gtk-3.0:ro
flatpak override --system --filesystem=xdg-config/gtk-4.0:ro
```

**Effect:**
- All Flatpak apps inherit MiOS dark theme
- All Flatpak apps use Bibata cursor
- All Flatpak apps can read host GTK configs

---

## Logging

**Location:** `/var/log/mios-flatpak-install.log`

**Contents:**
```
[2026-04-28 12:00:00] MiOS Flatpak installer v4
[2026-04-28 12:00:01] Loading system environment from /usr/lib/mios/env.d/flatpaks.env...
[2026-04-28 12:00:02] Configuring Flatpak remotes...
[2026-04-28 12:00:03]   Found user list: /home/mios/.config/mios/flatpaks.list
[2026-04-28 12:00:04]   Adding Flatpaks from system default: /usr/share/mios/flatpak-list
[2026-04-28 12:00:05] Installing 13 unique Flatpaks...
[2026-04-28 12:00:06]   -> org.mozilla.firefox
[2026-04-28 12:00:45]   -> org.libreoffice.LibreOffice
[2026-04-28 12:02:15]   -> ...
[2026-04-28 12:15:00] Applying global Flatpak overrides...
[2026-04-28 12:15:01] Complete
```

**View log:**
```bash
cat /var/log/mios-flatpak-install.log

# Or tail in real-time
tail -f /var/log/mios-flatpak-install.log
```

---

## Advanced: Override System Defaults

### Scenario: Remove System Default Apps

**Problem:** User wants to remove Firefox and LibreOffice from defaults

**Solution 1: Build custom image without defaults**
```dockerfile
# In Containerfile
RUN echo "" > /usr/share/mios/flatpak-list
```

**Solution 2: Uninstall after installation**
```bash
# Let system install defaults, then remove unwanted apps
flatpak uninstall --system org.mozilla.firefox
flatpak uninstall --system org.libreoffice.LibreOffice
```

**Solution 3: Custom image with different defaults**
```bash
# Build with custom default list
cat > custom-flatpaks.txt << 'EOF'
com.brave.Browser
org.onlyoffice.desktopeditors
com.visualstudio.code
EOF

# Build image
podman build --build-arg MIOS_FLATPAKS="$(cat custom-flatpaks.txt | tr '\n' ',')" -t localhost/mios:custom .
```

---

## File Locations Summary

| File | Purpose | Layer | Mutability |
|------|---------|-------|------------|
| `/usr/share/mios/flatpak-list` | System default apps (9 apps) | Image | Immutable |
| `/usr/lib/mios/env.d/flatpaks.env` | Build-time MIOS_FLATPAKS | Image | Immutable |
| `/etc/mios/templates/flatpaks.list` | User template (all commented out) | Image | Immutable |
| `~/.config/mios/flatpaks.list` | User customization | User home | User-editable |
| `~/.env.mios` | User environment vars | User home | User-editable |
| `/var/log/mios-flatpak-install.log` | Installation log | Var state | System-managed |
| `/etc/mios/.flatpak-version` | Version tracker | Etc overlay | System-managed |

---

## Integration with build-mios.sh

**Fedora Server ignition script** creates user Flatpak list from prompt:

```bash
# build-mios.sh lines 119-121
read -p "Enter Flatpak app IDs (comma-separated, optional): " MIOS_FLATPAKS_INPUT
MIOS_FLATPAKS="${MIOS_FLATPAKS_INPUT}"

# Lines 299-303
if [[ -n "$MIOS_FLATPAKS" ]]; then
    echo "$MIOS_FLATPAKS" | tr ',' '\n' > "$MIOS_USER_CONFIG_DIR/flatpaks.list"
else
    touch "$MIOS_USER_CONFIG_DIR/flatpaks.list"
fi
```

**Result:**
- User-specified apps written to `~/.config/mios/flatpaks.list`
- On first boot, merged with system defaults
- Total apps = system defaults (9) + user-specified

---

## Quick Reference

### Add Apps to User List

```bash
# Edit list
vim ~/.config/mios/flatpaks.list

# Add a single app
echo "com.visualstudio.code" >> ~/.config/mios/flatpaks.list

# Trigger installation
sudo /usr/libexec/mios-flatpak-install.sh
```

---

### Build Image with Custom Defaults

```bash
# Set build-time Flatpaks
MIOS_FLATPAKS="org.gnome.Boxes,com.github.tchx84.Flatseal,org.signal.Signal" just build
```

---

### Check What Will Be Installed

```bash
# Simulate the merge (no actual installation)
(
    cat /usr/share/mios/flatpak-list
    cat ~/.config/mios/flatpaks.list 2>/dev/null
    grep "^MIOS_FLATPAKS=" ~/.env.mios 2>/dev/null | cut -d= -f2 | tr ',' '\n'
) | sort -u
```

---

### View Installed Flatpaks

```bash
# List all system Flatpaks
flatpak list --system --app

# List with details
flatpak list --system --app --columns=name,application,version
```

---

## Related Documentation

- [mios-flatpak-install.sh](../usr/libexec/mios-flatpak-install.sh) - Installation script
- [flatpak-list](../usr/share/mios/flatpak-list) - System defaults (9 apps)
- [VARIABLES-COMPLETE-REFERENCE.md](VARIABLES-COMPLETE-REFERENCE.md) - All variables
- [build-mios.sh](../build-mios.sh) - Fedora Server ignition script
- [FEDORA-SERVER-IGNITION.md](FEDORA-SERVER-IGNITION.md) - Ignition guide

---

**Generated:** 2026-04-28
**Version:** 1.0.0
**MiOS Version:** 0.1.3
