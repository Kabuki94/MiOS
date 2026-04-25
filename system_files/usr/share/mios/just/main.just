# MiOS Professional Justfile
# Recipes for system management on the deployed workstation.

# Show system status and health
status:
    mios status

# Run system assessment
assess:
    mios assess

# Toggle between desktop and headless mode
toggle-headless:
    mios toggle-headless

# Perform system-wide update
update:
    mios update

# Rebuild the OS from source (requires repo)
rebuild:
    mios rebuild

# List IOMMU groups
iommu:
    mios iommu

# Validate VFIO readiness
vfio-check:
    mios vfio-check

# Toggle GPU VFIO binding
vfio-toggle:
    mios vfio-toggle

# Configure CPU isolation
cpu-isolate:
    mios cpu-isolate

# Run Podman garbage collection
gc:
    mios gc
