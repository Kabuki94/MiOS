#!/usr/bin/env bash
# build-all.sh - emit every deployment artifact from one image
set -euo pipefail

IMG="${IMG:-ghcr.io/kabuki94/mios:latest}"
OUT="${OUT:-$PWD/out}"
mkdir -p "$OUT"

BIB="quay.io/centos-bootc/bootc-image-builder:latest"

run_bib() {
    local cfg="$1" type="$2" rootfs="${3:-ext4}"
    podman run --rm --privileged --pull=newer \
        -v "$PWD/bib-configs/${cfg}:/config.toml:ro" \
        -v "$OUT:/output" \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        "$BIB" \
        --type "$type" --rootfs "$rootfs" \
        --config /config.toml "$IMG"
}

run_bib hyperv.toml   vhd       ext4
run_bib qemu.toml     qcow2     btrfs
run_bib anaconda.toml anaconda-iso
run_bib cloud-ami.toml ami      ext4

# WSL2 tarball (not a BIB type - export from running container)
echo "==> exporting WSL2 tarball"
cid=$(podman create "$IMG" /bin/true)
podman export "$cid" | zstd -T0 -19 -o "$OUT/mios-wsl2.tar.zst"
podman rm "$cid"

echo "==> artifacts in $OUT:"
ls -lh "$OUT"