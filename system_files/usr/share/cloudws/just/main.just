# CloudWS Professional Justfile
# Recipes for system management on the deployed workstation.

# Show system status and health
status:
    cloudws status

# Run system assessment
assess:
    cloudws assess

# Toggle between desktop and headless mode
toggle-headless:
    cloudws toggle-headless

# Perform system-wide update
update:
    cloudws update

# Rebuild the OS from source (requires repo)
rebuild:
    cloudws rebuild

# List IOMMU groups
iommu:
    cloudws iommu

# Validate VFIO readiness
vfio-check:
    cloudws vfio-check

# Toggle GPU VFIO binding
vfio-toggle:
    cloudws vfio-toggle

# Configure CPU isolation
cpu-isolate:
    cloudws cpu-isolate

# Run Podman garbage collection
gc:
    cloudws gc
