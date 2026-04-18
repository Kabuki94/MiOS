#!/bin/bash
# vfio-verify.sh
# Verification script for RTX 4090 VFIO passthrough configuration

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Status tracking
PASS=0
FAIL=0
WARN=0

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASS++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAIL++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARN++))
}

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}RTX 4090 VFIO Configuration Verification${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Test 1: Check IOMMU is enabled in kernel
echo -e "${BLUE}[1/10]${NC} Checking IOMMU kernel parameter..."
IOMMU_CMDLINE=$(cat /proc/cmdline | grep -oE '(amd_iommu|intel_iommu)=on')
if [[ -n "$IOMMU_CMDLINE" ]]; then
    check_pass "IOMMU enabled in kernel: $IOMMU_CMDLINE"
else
    check_fail "IOMMU not enabled in kernel parameters"
fi

# Test 2: Check IOMMU is active
echo -e "${BLUE}[2/10]${NC} Checking IOMMU initialization..."
IOMMU_DMESG=$(dmesg | grep -iE 'IOMMU|AMD-Vi|Intel-VT-d' | grep -i "enabled\|initialized" | head -n1)
if [[ -n "$IOMMU_DMESG" ]]; then
    check_pass "IOMMU initialized: ${IOMMU_DMESG:0:80}..."
else
    check_fail "IOMMU not initialized"
fi

# Test 3: Check VFIO modules loaded
echo -e "${BLUE}[3/10]${NC} Checking VFIO modules..."
VFIO_MODULES=("vfio" "vfio_pci" "vfio_iommu_type1")
ALL_LOADED=true
for module in "${VFIO_MODULES[@]}"; do
    if lsmod | grep -q "^$module"; then
        echo "  ${GREEN}✓${NC} $module loaded"
    else
        echo "  ${RED}✗${NC} $module not loaded"
        ALL_LOADED=false
    fi
done

if $ALL_LOADED; then
    check_pass "All VFIO modules loaded"
else
    check_fail "Some VFIO modules missing"
fi

# Test 4: Find RTX 4090
echo -e "${BLUE}[4/10]${NC} Detecting RTX 4090..."
RTX4090_PCI=$(lspci -nn | grep -i "RTX 4090" | awk '{print $1}' | head -n1)
if [[ -n "$RTX4090_PCI" ]]; then
    check_pass "RTX 4090 found at PCI address: $RTX4090_PCI"
    
    # Extract IDs
    RTX4090_INFO=$(lspci -nn -s "$RTX4090_PCI")
    GPU_ID=$(echo "$RTX4090_INFO" | grep -oP '\[\K[0-9a-f]{4}:[0-9a-f]{4}(?=\])')
    echo "  Device ID: $GPU_ID"
else
    check_fail "RTX 4090 not detected"
    echo "Exiting - cannot continue without GPU"
    exit 1
fi

# Test 5: Check driver binding
echo -e "${BLUE}[5/10]${NC} Checking driver binding..."
DRIVER_INFO=$(lspci -nnk -s "$RTX4090_PCI")
CURRENT_DRIVER=$(echo "$DRIVER_INFO" | grep "Kernel driver in use:" | awk '{print $5}')

if [[ "$CURRENT_DRIVER" == "vfio-pci" ]]; then
    check_pass "RTX 4090 bound to vfio-pci driver"
elif [[ -z "$CURRENT_DRIVER" ]]; then
    check_warn "No driver bound to RTX 4090"
    echo "  This may be intentional if using dynamic binding"
else
    check_fail "RTX 4090 bound to wrong driver: $CURRENT_DRIVER (expected vfio-pci)"
    echo ""
    echo "  Possible issues:"
    echo "  - VFIO IDs not in kernel parameters"
    echo "  - Module load order incorrect"
    echo "  - Kernel parameters not applied"
fi

# Test 6: Check audio controller
echo -e "${BLUE}[6/10]${NC} Checking audio controller..."
PCI_BUS=$(echo "$RTX4090_PCI" | cut -d: -f1)
AUDIO_PCI=$(lspci -nn | grep "$PCI_BUS:" | grep -i "audio" | grep -i "nvidia" | awk '{print $1}')

if [[ -n "$AUDIO_PCI" ]]; then
    AUDIO_DRIVER=$(lspci -nnk -s "$AUDIO_PCI" | grep "Kernel driver in use:" | awk '{print $5}')
    AUDIO_ID=$(lspci -nn -s "$AUDIO_PCI" | grep -oP '\[\K[0-9a-f]{4}:[0-9a-f]{4}(?=\])')
    
    if [[ "$AUDIO_DRIVER" == "vfio-pci" ]]; then
        check_pass "Audio controller ($AUDIO_ID) bound to vfio-pci"
    else
        check_fail "Audio controller bound to wrong driver: ${AUDIO_DRIVER:-none}"
        echo "  Both GPU and audio must use vfio-pci for passthrough"
    fi
else
    check_warn "Audio controller not found or not on same bus"
fi

# Test 7: Check VFIO device nodes
echo -e "${BLUE}[7/10]${NC} Checking VFIO device nodes..."
if [[ -d /dev/vfio ]]; then
    VFIO_DEVICES=$(ls /dev/vfio/ 2>/dev/null | grep -v "vfio" | wc -l)
    if [[ $VFIO_DEVICES -gt 0 ]]; then
        check_pass "VFIO device nodes present: $VFIO_DEVICES device(s)"
        ls -la /dev/vfio/ | grep -v "total" | sed 's/^/  /'
    else
        check_fail "No VFIO device nodes found"
    fi
else
    check_fail "/dev/vfio directory does not exist"
fi

# Test 8: Check IOMMU group
echo -e "${BLUE}[8/10]${NC} Checking IOMMU group isolation..."
if [[ -L "/sys/bus/pci/devices/0000:$RTX4090_PCI/iommu_group" ]]; then
    IOMMU_GROUP=$(basename $(readlink "/sys/bus/pci/devices/0000:$RTX4090_PCI/iommu_group"))
    GROUP_DEVICES=$(ls -1 "/sys/kernel/iommu_groups/$IOMMU_GROUP/devices/" | wc -l)
    
    echo "  IOMMU Group: $IOMMU_GROUP"
    echo "  Devices in group: $GROUP_DEVICES"
    
    if [[ $GROUP_DEVICES -le 3 ]]; then
        check_pass "Good IOMMU isolation (≤3 devices in group)"
    else
        check_warn "Multiple devices in IOMMU group ($GROUP_DEVICES)"
        echo "  Consider ACS override patch if this causes issues"
    fi
    
    echo ""
    echo "  Group members:"
    for dev in /sys/kernel/iommu_groups/$IOMMU_GROUP/devices/*; do
        DEV_ID=$(basename "$dev")
        DEV_INFO=$(lspci -nns "$DEV_ID" | cut -d' ' -f2-)
        echo "    $DEV_INFO"
    done
else
    check_fail "IOMMU group information not available"
fi

# Test 9: Check kernel parameters
echo -e "${BLUE}[9/10]${NC} Checking kernel command line..."
CMDLINE=$(cat /proc/cmdline)

# Check for vfio-pci.ids
if echo "$CMDLINE" | grep -q "vfio-pci.ids="; then
    VFIO_IDS=$(echo "$CMDLINE" | grep -oP 'vfio-pci\.ids=\K[0-9a-f:,]+')
    check_pass "VFIO IDs in kernel params: $VFIO_IDS"
else
    check_fail "vfio-pci.ids not found in kernel parameters"
fi

# Check for iommu=pt
if echo "$CMDLINE" | grep -q "iommu=pt"; then
    check_pass "IOMMU passthrough mode enabled"
else
    check_warn "iommu=pt not set (may impact performance)"
fi

# Test 10: Check for potential conflicts
echo -e "${BLUE}[10/10]${NC} Checking for potential conflicts..."

# Check if nvidia module is loaded
if lsmod | grep -q "^nvidia"; then
    check_warn "NVIDIA driver loaded - may conflict with VFIO"
    echo "  Consider blacklisting if GPU is dedicated to passthrough"
else
    check_pass "No conflicting NVIDIA driver loaded"
fi

# Check if nouveau is loaded
if lsmod | grep -q "^nouveau"; then
    check_warn "Nouveau driver loaded - may conflict with VFIO"
else
    check_pass "No conflicting Nouveau driver loaded"
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Verification Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Passed:  $PASS${NC}"
echo -e "${YELLOW}Warnings: $WARN${NC}"
echo -e "${RED}Failed:  $FAIL${NC}"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}✓ RTX 4090 VFIO configuration is correct!${NC}"
    echo ""
    echo "You can now:"
    echo "  1. Create a VM in virt-manager"
    echo "  2. Add PCI devices: $GPU_ID and $AUDIO_ID"
    echo "  3. Use UEFI firmware (OVMF)"
    echo "  4. Install guest OS with GPU drivers"
    echo ""
elif [[ $FAIL -le 2 && $PASS -ge 6 ]]; then
    echo -e "${YELLOW}⚠ Configuration mostly correct with minor issues${NC}"
    echo ""
    echo "Review the failed checks above and consider:"
    echo "  - Verifying kernel parameters in boot loader"
    echo "  - Checking mkinitcpio module order"
    echo "  - Rebuilding initramfs: sudo mkinitcpio -P"
    echo ""
else
    echo -e "${RED}✗ VFIO configuration has significant issues${NC}"
    echo ""
    echo "Please review the failed checks and:"
    echo "  1. Verify kernel parameters in systemd-boot entries"
    echo "  2. Check /etc/modprobe.d/vfio.conf"
    echo "  3. Verify MODULES in /etc/mkinitcpio.conf"
    echo "  4. Rebuild initramfs: sudo mkinitcpio -P"
    echo "  5. Reboot and run this script again"
    echo ""
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Detailed diagnostics option
read -p "Show detailed diagnostics? (y/N): " SHOW_DIAG

if [[ "$SHOW_DIAG" =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Detailed Diagnostics${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}Kernel Command Line:${NC}"
    cat /proc/cmdline
    echo ""
    
    echo -e "${YELLOW}VFIO Kernel Messages:${NC}"
    dmesg | grep -i vfio | tail -20
    echo ""
    
    echo -e "${YELLOW}RTX 4090 Detailed Info:${NC}"
    lspci -nnk -s "$RTX4090_PCI"
    echo ""
    
    if [[ -n "$AUDIO_PCI" ]]; then
        echo -e "${YELLOW}Audio Controller Detailed Info:${NC}"
        lspci -nnk -s "$AUDIO_PCI"
        echo ""
    fi
    
    echo -e "${YELLOW}Loaded Modules:${NC}"
    lsmod | grep -E "(vfio|nvidia|nouveau)" || echo "None found"
    echo ""
    
    echo -e "${YELLOW}Modprobe Configuration:${NC}"
    if [[ -f /etc/modprobe.d/vfio.conf ]]; then
        cat /etc/modprobe.d/vfio.conf
    else
        echo "No /etc/modprobe.d/vfio.conf found"
    fi
    echo ""
fi

exit $FAIL
