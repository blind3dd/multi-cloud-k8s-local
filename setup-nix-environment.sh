#!/bin/bash

# Nix Environment Setup Script
# Source this script to set up Nix environment for multi-cloud Kubernetes infrastructure

# Source Nix environment
if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    echo "Nix environment sourced successfully"
else
    echo "Warning: Nix daemon profile not found"
fi

# Set Nix environment variables
export NIX_PATH="nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixpkgs"
export NIX_CONF_DIR="/etc/nix"

# Verify Nix installation
if command -v nix &> /dev/null; then
    echo "Nix version: $(nix --version)"
else
    echo "Error: Nix not found in PATH"
    exit 1
fi

# Verify installed packages
echo "Verifying installed packages:"
echo "  kubectl: $(kubectl version --client --short 2>/dev/null || echo 'not found')"
echo "  clusterctl: $(clusterctl version --short 2>/dev/null || echo 'not found')"
echo "  helm: $(helm version --short 2>/dev/null || echo 'not found')"
echo "  talosctl: $(talosctl version --short 2>/dev/null || echo 'not found')"
echo "  docker: $(docker --version 2>/dev/null || echo 'not found')"
echo "  kind: $(kind version 2>/dev/null || echo 'not found')"

echo "Nix environment setup complete!"
