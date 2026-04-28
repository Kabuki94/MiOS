# MiOS Quick Start Guide

**Fast-track installation and usage guide for MiOS**

---

## One-Liner Installation

```bash
curl -fsSL https://raw.githubusercontent.com/Kabuki94/MiOS-bootstrap/main/build-mios.sh | sudo bash
```

Follow the prompts, then:

```bash
su - mios
mios init
mios status
```

---

## Common Workflows

### 1. Fresh Fedora Server → MiOS System

```bash
# Install MiOS
curl -fsSL https://raw.githubusercontent.com/Kabuki94/MiOS-bootstrap/main/build-mios.sh | sudo bash

# Switch to user
su - mios

# Initialize user space
mios init

# Build image (if not done during ignition)
cd /usr/share/mios && just build

# Deploy to system
sudo bootc install to-existing-root --source-imgref localhost/mios:latest

# Reboot into MiOS
sudo reboot
```

**Time:** ~25-35 minutes (including build)

---

### 2. Development Build (Local Repository)

```bash
# Clone repo
git clone https://github.com/Kabuki94/MiOS-bootstrap.git
cd MiOS-bootstrap

# Configure user environment
mkdir -p ~/.config/mios
cp etc/mios/templates/default.env.toml ~/.config/mios/env.toml
cp etc/mios/templates/default.images.toml ~/.config/mios/images.toml
cp etc/mios/templates/default.build.toml ~/.config/mios/build.toml

# Edit configuration
nano ~/.config/mios/env.toml

# Build
just build

# (Optional) Test in VM
just test-vm
```

**Time:** ~15-20 minutes

---

### 3. Update Existing MiOS System

```bash
# Check for updates
mios update

# OR rebuild from source
mios rebuild

# OR pull latest and build
cd /usr/src/mios
git pull
just build
sudo bootc upgrade --source-imgref localhost/mios:latest
sudo reboot
```

**Time:** ~5-10 minutes (update) or ~15-20 minutes (rebuild)

---

## Essential Commands

### System Management

| Command | Description |
|---------|-------------|
| `mios status` | Show system & service status |
| `mios update` | Check for & apply OS updates |
| `mios rebuild` | Clone repo, build from source, push to GHCR |
| `mios build` | Local OCI build only (no push) |
| `mios deploy-image` | Switch to a different MiOS image |
| `mios backup` | Snapshot /etc + /var/home |

### User Space

| Command | Description |
|---------|-------------|
| `mios init` | Initialize user space (~/.config/mios) |
| `mios assess` | Run automated system assessment |
| `mios test` | Run system health checks |

### Virtualization

| Command | Description |
|---------|-------------|
| `mios vfio-toggle` | Bind/unbind GPU from vfio-pci |
| `mios vfio-check` | Validate VFIO passthrough readiness |
| `mios iommu-groups` | List IOMMU groups |
| `mios cpu-isolate` | Configure core isolation (X3D optimized) |

### Containers

| Command | Description |
|---------|-------------|
| `mios gc` | Run Podman garbage collection |
| `mios gc-status` | Show Podman disk usage |

### AI & LLM

| Command | Description |
|---------|-------------|
| `mios ai` | Show status of Ollama and AIChat |
| `mios ai-logs` | Tail Ollama container logs |
| `mios ai-pull <model>` | Pull a model into Ollama |

---

## Configuration Files

### User Configuration (~/.config/mios/)

```
~/.config/mios/
├── env.toml          # User environment (username, hostname)
├── images.toml       # Image configuration (base, builder, output)
├── build.toml        # Build configuration (cache, flatpaks)
├── flatpaks.list     # Flatpak applications (one per line)
└── ai.env            # AI secrets (mode 600, not committed)
```

### System Configuration (/etc/mios/)

```
/etc/mios/
├── runtime.env       # System-wide runtime environment
└── templates/        # Default configuration templates
```

---

## Quick Customization

### Change Base Image

Edit `~/.config/mios/images.toml`:

```toml
[base]
image = "ghcr.io/ublue-os/ucore-hci:stable"  # No NVIDIA
```

Then rebuild:

```bash
cd /usr/share/mios && just build
```

### Add Flatpak Applications

Edit `~/.config/mios/flatpaks.list`:

```
org.mozilla.Firefox
org.gnome.Boxes
com.visualstudio.code
org.libreoffice.LibreOffice
```

Then rebuild:

```bash
cd /usr/share/mios && just build
```

### Change AI Model

Edit `~/.config/mios/env.toml`:

```toml
[ai]
model = "llama3.1:70b"
endpoint = "http://localhost:8080/v1"
temperature = 0.7
```

Then pull the model:

```bash
mios ai-pull llama3.1:70b
```

### Change Hostname

Edit `~/.config/mios/env.toml`:

```toml
[mios]
hostname = "my-server"
```

Then rebuild and deploy:

```bash
cd /usr/share/mios && just build
sudo bootc upgrade --source-imgref localhost/mios:latest
sudo reboot
```

---

## Build Process Overview

```
User Config (~/.config/mios/*.toml)
    ↓
tools/load-user-env.sh (TOML parser)
    ↓
Environment Variables (MIOS_*)
    ↓
Justfile (build recipes)
    ↓
Containerfile (OCI build)
    ↓
podman build
    ↓
localhost/mios:latest
    ↓
bootc install/upgrade
    ↓
System Boot
```

---

## Directory Structure

```
/usr/
├── bin/
│   ├── mios*                 # Main CLI
│   ├── mios-*                # Command implementations
│   └── iommu-groups*         # IOMMU utility
├── libexec/
│   ├── mios-init.sh*         # Initialization script
│   └── mios/                 # Internal scripts
│       ├── assess*
│       ├── cpu-isolate*
│       ├── dash*
│       └── ...
└── share/mios/
    ├── tools/                # Build tools
    ├── automation/           # Automation scripts
    ├── Containerfile         # OCI build definition
    ├── Justfile              # Build automation
    └── VERSION               # Version file

/etc/mios/
├── runtime.env               # System runtime environment
└── templates/                # Default TOML templates

/var/
├── log/mios/                 # Logs
├── cache/mios/               # Build cache
└── lib/mios/                 # State

~/.config/mios/               # User configuration
~/.local/share/mios/          # User data
~/.cache/mios/                # User cache
~/.local/state/mios/          # User state
```

---

## Troubleshooting Quick Fixes

### Build Fails

```bash
# Check disk space
df -h /var/lib/containers

# Clean up containers
mios gc

# Check podman
podman info
systemctl status podman.socket

# Try clean build
cd /usr/share/mios
just clean
just build
```

### Command Not Found

```bash
# Verify installation
ls -la /usr/bin/mios*

# Check PATH
echo $PATH

# Make scripts executable
sudo chmod +x /usr/bin/mios* /usr/libexec/mios*
```

### Configuration Not Loading

```bash
# Verify files exist
ls -la ~/.config/mios/

# Check syntax
python3 -m json.tool ~/.config/mios/env.toml 2>&1 | head

# Debug mode
export MIOS_DEBUG=true
cd /usr/share/mios
just build
```

### Bootc Deployment Fails

```bash
# Check bootc status
bootc status

# Verify image
podman images | grep mios

# Check system compatibility
rpm-ostree status

# Try direct bootc command
sudo bootc install to-existing-root \
  --source-imgref localhost/mios:latest \
  --skip-fetch-check
```

---

## Performance Tips

### Faster Builds

1. **Enable build cache:**
   ```toml
   # ~/.config/mios/build.toml
   [build]
   no_cache = false  # Use cache
   ```

2. **Use local base image:**
   ```bash
   podman pull ghcr.io/ublue-os/ucore-hci:stable-nvidia
   ```

3. **Reduce Flatpak list:**
   Only install essential apps, add more later with `flatpak install`

### Reduce Disk Usage

```bash
# Clean Podman
mios gc

# Clean build cache
rm -rf ~/.cache/mios/build-cache/*

# Prune old images
podman image prune -a
```

### Optimize for X3D CPUs

```bash
# Isolate cores for VM passthrough
mios cpu-isolate
```

---

## Next Steps

- **Full Documentation:** [FEDORA-SERVER-IGNITION.md](FEDORA-SERVER-IGNITION.md)
- **Variable System:** [VARIABLES.md](../VARIABLES.md)
- **AI Environment:** [.ai/README.md](../.ai/README.md)
- **Command Reference:** [MIOS-COMMANDS-VERIFICATION.md](../MIOS-COMMANDS-VERIFICATION.md)

---

**Repository:** https://github.com/Kabuki94/MiOS-bootstrap
**Version:** 0.1.3
**Last Updated:** 2026-04-28
