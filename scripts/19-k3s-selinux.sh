#!/usr/bin/env bash
set -eoux pipefail

echo "==> Compiling and Installing K3s SELinux Policy for Fedora 44..."

# Install SELinux development tools required for compilation
dnf install -y selinux-policy-devel git make

# Clone the upstream k3s-selinux repository
git clone https://github.com/k3s-io/k3s-selinux.git /tmp/k3s-selinux
cd /tmp/k3s-selinux

# Compile the policy using the Fedora 44 SELinux Makefile
make -f /usr/share/selinux/devel/Makefile k3s.pp

# Install the compiled policy into the image
semodule -i k3s.pp

# Clean up
cd /
rm -rf /tmp/k3s-selinux
echo "==> K3s SELinux Policy successfully embedded."
