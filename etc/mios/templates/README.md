# MiOS Configuration Templates

This directory contains **system default configuration templates** that ship with MiOS.

## [DIR] Template Files

- `default.env.toml` - Environment configuration template
- `default.images.toml` - OCI image references template
- `default.build.toml` - Build configuration template
- `flatpaks.list` - Flatpak applications template

##  User Configuration Location

**DO NOT EDIT THESE FILES DIRECTLY!**

These templates are read-only system defaults. User configurations belong in:

```
$HOME/.config/mios/
+-- env.toml           # Your environment config
+-- images.toml        # Your OCI image preferences
+-- build.toml         # Your build configuration
+-- flatpaks.list      # Your Flatpak applications
+-- credentials/       # Your credentials (never committed)
```

## [START] First-Time Setup

Initialize your user-space configuration:

```bash
# Run the initialization script
just init-user-space

# Or manually
./tools/init-user-space.sh
```

This will:
1. Create `$HOME/.config/mios/` directory structure
2. Copy these templates to your user config
3. Set up credentials directory with `.gitignore`
4. Create XDG Base Directory structure

## [DOC] Customizing Configuration

After initialization, edit your user configuration files:

```bash
# Edit environment configuration
$EDITOR ~/.config/mios/env.toml

# Edit OCI image preferences
$EDITOR ~/.config/mios/images.toml

# Edit build configuration
$EDITOR ~/.config/mios/build.toml

# Add Flatpak applications
$EDITOR ~/.config/mios/flatpaks.list
```

##  Adding Credentials

Store sensitive data in the credentials directory:

```bash
# GitHub Personal Access Token
echo "ghp_your_token_here" > ~/.config/mios/credentials/github-token
chmod 600 ~/.config/mios/credentials/github-token

# Container registry authentication (Podman/Docker format)
podman login ghcr.io
cp ~/.config/containers/auth.json ~/.config/mios/credentials/registry-auth.json

# SSH keys for private repositories
cp ~/.ssh/id_ed25519 ~/.config/mios/credentials/ssh-keys/
chmod 600 ~/.config/mios/credentials/ssh-keys/*
```

**IMPORTANT:** The credentials directory is automatically `.gitignore`'d and will **never** be committed to version control.

## [SYNC] Configuration Priority

Variables are loaded in priority order (later overrides earlier):

1. **System Defaults** (these templates) - Read-only, shipped with MiOS
2. **User Configuration** (`~/.config/mios/*.toml`) - Your overrides
3. **Environment Variables** (e.g., `MIOS_BASE_IMAGE`) - Shell environment
4. **Command-Line Arguments** - Direct overrides (highest priority)

## [NET] XDG Base Directory Compliance

MiOS follows the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html):

| Purpose | Default Path | Environment Variable |
|---------|--------------|---------------------|
| Configuration | `~/.config/mios/` | `$XDG_CONFIG_HOME/mios/` |
| Data | `~/.local/share/mios/` | `$XDG_DATA_HOME/mios/` |
| Cache | `~/.cache/mios/` | `$XDG_CACHE_HOME/mios/` |
| State (logs) | `~/.local/state/mios/` | `$XDG_STATE_HOME/mios/` |
| Runtime | `/run/user/$UID/mios/` | `$XDG_RUNTIME_DIR/mios/` |

##  Documentation

For more information, see:
- [User-Space Separation Spec](../../specs/engineering/2026-04-27-Artifact-ENG-008-UserSpace-Separation.md)
- [Self-Build Guide](../../SELF-BUILD.md)
- [AI Agent Guide](../../AI-AGENT-GUIDE.md)

---

**Location in Image:** `/usr/share/mios/config/`
**Repository Location:** `etc/mios/templates/`
