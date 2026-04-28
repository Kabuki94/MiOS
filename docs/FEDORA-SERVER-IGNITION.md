# MiOS Fedora Server Ignition Guide

**Version:** 1.0.0
**Script:** [build-mios.sh](../build-mios.sh)
**Purpose:** Automated MiOS installation on Fedora Server with FHS-compliant merge (NO deletions)

---

## Overview

The `build-mios.sh` script provides a one-command installation path for deploying MiOS onto a clean Fedora Server system. It fetches the MiOS repository from GitHub, prompts for user configuration, and merges the MiOS structure onto the system root using FHS-compliant patterns.

### Key Features

✓ **Zero-Deletion Merge**: Uses `rsync --ignore-existing` to preserve all existing Fedora files
✓ **Interactive Configuration**: Prompts for username, password, hostname, base image, Flatpaks, AI settings
✓ **FHS 3.0 Compliant**: Follows Filesystem Hierarchy Standard patterns
✓ **User Environment Queuing**: Creates `~/.config/mios/*.toml` files with user preferences
✓ **Secure Password Hashing**: SHA-512 password encryption
✓ **Optional OCI Build**: Can build MiOS container image during installation
✓ **Comprehensive Logging**: Full installation log at `/var/log/mios-ignition.log`

---

## Prerequisites

- **OS**: Fedora Server 40+ (or Fedora CoreOS, RHEL 9+)
- **Requirements**:
  - Root access (`sudo`)
  - Internet connection
  - Minimum 10 GB disk space
  - Podman (auto-installed if missing)

---

## Installation Methods

### Method 1: One-Liner (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/Kabuki94/MiOS-bootstrap/main/build-mios.sh | sudo bash
```

### Method 2: Download and Run

```bash
curl -fsSL https://raw.githubusercontent.com/Kabuki94/MiOS-bootstrap/main/build-mios.sh -o build-mios.sh
chmod +x build-mios.sh
sudo ./build-mios.sh
```

### Method 3: From Local Repository

```bash
git clone https://github.com/Kabuki94/MiOS-bootstrap.git
cd MiOS-bootstrap
sudo bash build-mios.sh
```

---

## Interactive Prompts

The script will prompt for the following configuration:

### 1. Username
```
Enter username (default: mios):
```
**Default:** `mios`
**Purpose:** Primary user account with sudo access

### 2. Password
```
Enter password for mios:
Confirm password:
```
**Purpose:** User account password (SHA-512 hashed)
**Security:** Password is never logged or saved in plaintext

### 3. Hostname
```
Enter hostname (default: mios):
```
**Default:** `mios`
**Purpose:** System hostname (sets via `hostnamectl`)

### 4. Base Image
```
Select base image:
  1) ghcr.io/ublue-os/ucore-hci:stable-nvidia (NVIDIA GPU, recommended)
  2) ghcr.io/ublue-os/ucore-hci:stable (No NVIDIA)
  3) ghcr.io/ublue-os/ucore:stable (Minimal)
  4) Custom (enter manually)
Choice [1-4] (default: 1):
```
**Default:** NVIDIA variant
**Purpose:** bootc base image for container build

### 5. Flatpak Applications
```
Enter Flatpak app IDs (comma-separated, optional):
```
**Example:** `org.mozilla.Firefox,org.gnome.Boxes,com.visualstudio.code`
**Purpose:** Pre-install Flatpak applications in the system image

### 6. AI Configuration
```
Configure AI settings? (y/N):
AI Model (default: llama3.1:8b):
AI Endpoint (default: http://localhost:8080/v1):
AI API Key (optional, press Enter to skip):
```
**Purpose:** Configure Ollama/AIChat integration
**Note:** API key is saved to `~/.config/mios/ai.env` (mode 600, never committed)

### 7. Final Confirmation
```
Configuration Summary:
  Username:     mios
  Hostname:     mios
  Base Image:   ghcr.io/ublue-os/ucore-hci:stable-nvidia
  Flatpaks:     org.mozilla.Firefox
  AI Model:     llama3.1:8b
  AI Endpoint:  http://localhost:8080/v1

Proceed with this configuration? (y/N):
```

---

## What Gets Installed

### Directory Structure Merge

| MiOS Path | System Path | Method | Description |
|-----------|-------------|--------|-------------|
| `usr/` | `/usr/` | `rsync --ignore-existing` | Binaries, libraries, data |
| `etc/` | `/etc/` | `rsync --ignore-existing` | Configuration templates |
| `var/` | `/var/` | `tmpfiles.d` | State directories (declared, not merged) |
| `home/mios/` | `/etc/skel/` | `rsync --ignore-existing` | User skeleton files |
| `tools/` | `/usr/share/mios/tools/` | `rsync` | Build tools and scripts |
| `automation/` | `/usr/share/mios/automation/` | `rsync` | Automation scripts |
| `Containerfile` | `/usr/share/mios/Containerfile` | `cp -n` | OCI image build file |
| `Justfile` | `/usr/share/mios/Justfile` | `cp -n` | Build automation |

### User Environment Files Created

**Location:** `~/.config/mios/`

1. **env.toml** - User environment configuration
   ```toml
   [mios]
   user = "mios"
   hostname = "mios"

   [ai]
   model = "llama3.1:8b"
   endpoint = "http://localhost:8080/v1"
   temperature = 0.7
   ```

2. **images.toml** - Image configuration
   ```toml
   [base]
   image = "ghcr.io/ublue-os/ucore-hci:stable-nvidia"

   [builder]
   image = "quay.io/centos-bootc/bootc-image-builder:latest"

   [output]
   name = "localhost/mios"
   tag = "latest"
   ```

3. **build.toml** - Build configuration
   ```toml
   [build]
   no_cache = true
   progress = "tty"

   [flatpaks]
   source_file = "~/.config/mios/flatpaks.list"
   ```

4. **flatpaks.list** - Flatpak applications (one per line)
5. **ai.env** - AI secrets (mode 600, not committed)

### System Files Created

**Location:** `/etc/mios/`

- **runtime.env** - System-wide runtime environment variables

---

## Merge Strategy (FHS-Compliant)

### NO Deletions Policy

The script uses `rsync --ignore-existing` to ensure:

✓ **Existing Fedora files are NEVER overwritten**
✓ **Existing Fedora files are NEVER deleted**
✓ **Only NEW files are added**
✓ **MiOS merges INTO Fedora, not OVER it**

### Merge Order

1. **Phase 1: /usr** (system resources)
   - Binaries: `/usr/bin/mios*`, `/usr/bin/iommu-groups`
   - Libraries: `/usr/libexec/mios*`
   - Data: `/usr/share/mios/`
   - tmpfiles: `/usr/lib/tmpfiles.d/mios.conf`

2. **Phase 2: /etc** (configuration)
   - Templates: `/etc/mios/`
   - systemd: `/etc/systemd/system/`
   - sudoers: `/etc/sudoers.d/mios`

3. **Phase 3: /var** (state, via tmpfiles.d)
   - Logs: `/var/log/mios/`
   - Cache: `/var/cache/mios/`
   - State: `/var/lib/mios/`

4. **Phase 4: /home** (user skeleton)
   - Skeleton: `/etc/skel/.config/mios/`
   - Dotfiles: `/etc/skel/.bashrc`, etc.

---

## Post-Installation Workflow

### Step 1: Switch to User Account

```bash
su - mios
```

### Step 2: Initialize User Space

```bash
mios init
```

This creates:
- `~/.config/mios/` (XDG-compliant config)
- `~/.local/share/mios/` (data)
- `~/.cache/mios/` (cache)
- `~/.local/state/mios/` (state)

### Step 3: Build MiOS Image (if not done during ignition)

```bash
cd /usr/share/mios
just build
```

**OR** (without `just`):

```bash
cd /usr/share/mios
podman build --no-cache -t localhost/mios:latest .
```

### Step 4: Check System Status

```bash
mios status
```

### Step 5: Deploy MiOS Image (Optional)

```bash
sudo bootc install to-existing-root --source-imgref localhost/mios:latest
sudo reboot
```

After reboot, the system will boot into the MiOS container image.

---

## Build Process Details

### Environment Variable Propagation

The script propagates user configuration to the build process:

```bash
export MIOS_BASE_IMAGE="ghcr.io/ublue-os/ucore-hci:stable-nvidia"
export MIOS_USER="mios"
export MIOS_PASSWORD_HASH="$6$..."
export MIOS_HOSTNAME="mios"
export MIOS_FLATPAKS="org.mozilla.Firefox org.gnome.Boxes"
```

These are consumed by:
- **Containerfile** (ARG declarations)
- **Justfile** (build recipes)
- **tools/load-user-env.sh** (TOML parser)

### Build Commands

**With `just`:**
```bash
just build
```

**Without `just` (fallback):**
```bash
podman build --no-cache \
  --build-arg BASE_IMAGE="$MIOS_BASE_IMAGE" \
  --build-arg MIOS_USER="$MIOS_USER" \
  --build-arg MIOS_PASSWORD_HASH="$MIOS_PASSWORD_HASH" \
  --build-arg MIOS_HOSTNAME="$MIOS_HOSTNAME" \
  --build-arg MIOS_FLATPAKS="$MIOS_FLATPAKS" \
  -t localhost/mios:latest .
```

---

## Logging and Debugging

### Installation Log

**Location:** `/var/log/mios-ignition.log`

**Contents:**
- Timestamped installation steps
- Configuration summary
- Error messages (if any)
- Full rsync output
- Build logs (if built during ignition)

**View log:**
```bash
cat /var/log/mios-ignition.log
```

### Debug Mode

Set environment variable before running:

```bash
export MIOS_DEBUG=true
sudo -E bash build-mios.sh
```

This will print all `MIOS_*` environment variables during execution.

---

## Advanced Configuration

### Custom Repository URL

```bash
export MIOS_REPO_URL="https://github.com/YourFork/MiOS-bootstrap.git"
export MIOS_REPO_BRANCH="develop"
sudo -E bash build-mios.sh
```

### Non-Interactive Mode

For automated deployments, pre-set all variables:

```bash
export MIOS_USERNAME="admin"
export MIOS_PASSWORD="SecurePassword123"
export MIOS_HOSTNAME="mios-prod"
export MIOS_BASE_IMAGE="ghcr.io/ublue-os/ucore-hci:stable-nvidia"
export MIOS_FLATPAKS="org.mozilla.Firefox,com.visualstudio.code"
export MIOS_AI_MODEL="llama3.1:8b"
export MIOS_AI_ENDPOINT="http://localhost:8080/v1"

sudo -E bash build-mios.sh --non-interactive
```

*(Note: Non-interactive mode would require script modification)*

---

## Security Considerations

### Password Handling

✓ **SHA-512 hashing**: Passwords are hashed before storage
✓ **No plaintext logs**: Passwords never appear in logs
✓ **Secure prompt**: `read -sp` hides password input

### File Permissions

- **ai.env**: Mode 600 (owner read/write only)
- **sudoers.d/mios**: Mode 440 (root read only)
- **User config**: Owned by user, not root

### Network Security

- **HTTPS git clone**: Repository fetched over HTTPS
- **Registry authentication**: Podman respects `~/.docker/config.json`

---

## Troubleshooting

### Error: "This script must be run as root"

**Solution:** Use `sudo`
```bash
sudo bash build-mios.sh
```

### Error: "No internet connection"

**Solution:** Check network connectivity
```bash
ping -c 3 github.com
```

### Error: "Failed to clone MiOS repository"

**Possible Causes:**
- GitHub is down
- Repository URL is incorrect
- Network firewall blocking git

**Solution:** Check repository URL
```bash
export MIOS_REPO_URL="https://github.com/Kabuki94/MiOS-bootstrap.git"
```

### Error: "Build failed"

**Possible Causes:**
- Out of disk space
- Podman not running
- Base image not available

**Solution 1:** Check disk space
```bash
df -h /var/lib/containers
```

**Solution 2:** Check podman
```bash
systemctl status podman.socket
podman info
```

**Solution 3:** Pull base image manually
```bash
podman pull ghcr.io/ublue-os/ucore-hci:stable-nvidia
```

### Warning: "Some files in /usr were skipped (already exist)"

**This is normal!** The `--ignore-existing` flag ensures existing Fedora files are preserved. MiOS files are only added if they don't conflict.

---

## Uninstallation

MiOS is designed to merge with Fedora, not replace it. To remove MiOS:

### Manual Cleanup

```bash
# Remove MiOS binaries
sudo rm -rf /usr/bin/mios* /usr/bin/iommu-groups

# Remove MiOS libraries
sudo rm -rf /usr/libexec/mios*

# Remove MiOS data
sudo rm -rf /usr/share/mios

# Remove MiOS configuration
sudo rm -rf /etc/mios
sudo rm -rf ~/.config/mios

# Remove MiOS state
sudo rm -rf /var/lib/mios /var/log/mios /var/cache/mios

# Remove user (optional)
sudo userdel -r mios
```

### Automated Cleanup Script

```bash
sudo bash /usr/share/mios/tools/uninstall-mios.sh
```

*(Note: Uninstall script would need to be created)*

---

## FAQ

**Q: Will this overwrite my existing Fedora installation?**
A: No. The script uses `rsync --ignore-existing`, which ONLY adds new files. Existing files are never modified or deleted.

**Q: Can I run this on Fedora Workstation?**
A: Yes, but it's designed for Fedora Server. Desktop users should use the regular MiOS build process.

**Q: Can I customize the configuration after installation?**
A: Yes! Edit `~/.config/mios/*.toml` files, then rebuild with `just build`.

**Q: How do I update MiOS after installation?**
A: Run `mios update` or `sudo bootc upgrade`.

**Q: Can I use this in Kickstart or Ignition files?**
A: Yes! See [CLOUD-INIT-INTEGRATION.md](CLOUD-INIT-INTEGRATION.md) for examples.

**Q: What if I want to use a different base image?**
A: Select option 4 during the base image prompt, or edit `~/.config/mios/images.toml` after installation.

---

## Related Documentation

- [VARIABLES.md](../VARIABLES.md) - User-editable variable system
- [BUILD-READINESS-REPORT.md](../BUILD-READINESS-REPORT.md) - Build system validation
- [MIOS-COMMANDS-VERIFICATION.md](../MIOS-COMMANDS-VERIFICATION.md) - Command reference
- [.ai/README.md](../.ai/README.md) - AI environment documentation

---

## Support

**Repository:** https://github.com/Kabuki94/MiOS-bootstrap
**Issues:** https://github.com/Kabuki94/MiOS-bootstrap/issues
**License:** Licensed as personal property to Kabu.ki

---

**Generated:** 2026-04-28
**MiOS Version:** 0.1.3
**Ignition Script Version:** 1.0.0
