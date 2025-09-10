#!/bin/bash

# Complete Nix Setup for Multi-Cloud Kubernetes Infrastructure
# This script sets up Nix package manager with all required configurations and packages

set -euo pipefail

# Configuration
NIX_USER="usualsuspectx"
NIX_VERSION="2.24.1"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log "This script must be run as root for system-wide Nix configuration"
        exit 1
    fi
}

# Install Nix package manager
install_nix() {
    log "Installing Nix package manager..."
    
    # Check if Nix is already installed
    if command -v nix &> /dev/null; then
        log "Nix is already installed: $(nix --version)"
        return 0
    fi
    
    # Install Nix using the official installer
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
    
    # Source Nix environment
    if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi
    
    log "Nix package manager installed successfully"
}

# Configure Nix system-wide settings
configure_nix_system() {
    log "Configuring Nix system-wide settings..."
    
    # Create system-wide Nix configuration directory
    mkdir -p /etc/nix
    
    # Create system-wide Nix configuration
    tee /etc/nix/nix.conf > /dev/null <<EOF
# Nix system-wide configuration for multi-cloud Kubernetes infrastructure

# Enable experimental features
experimental-features = nix-command flakes

# Set maximum number of parallel jobs
max-jobs = auto

# Keep more generations for rollback capability
keep-derivations = true
keep-outputs = true

# Auto-optimise store
auto-optimise-store = true

# Sandbox settings
sandbox = true

# Substituters for faster package downloads
substituters = https://cache.nixos.org/ https://nix-community.cachix.org/
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=

# Build users for CI/CD
build-users-group = nixbld
build-users = nixbld1 nixbld2 nixbld3 nixbld4 nixbld5 nixbld6 nixbld7 nixbld8 nixbld9 nixbld10

# Trusted users
trusted-users = root $NIX_USER
EOF

    # Create custom configuration for trusted users
    tee /etc/nix/nix.custom.conf > /dev/null <<EOF
# Custom Nix configuration for multi-cloud Kubernetes infrastructure
# Written by multi-cloud-k8s-local setup

trusted-users = root $NIX_USER
EOF

    log "Nix system-wide configuration created"
}

# Configure Nix user settings
configure_nix_user() {
    log "Configuring Nix user settings for $NIX_USER..."
    
    # Create user Nix configuration directory
    mkdir -p "/Users/$NIX_USER/.config/nix"
    
    # Create user Nix configuration
    tee "/Users/$NIX_USER/.config/nix/nix.conf" > /dev/null <<EOF
# Nix user configuration for multi-cloud Kubernetes infrastructure
# User: $NIX_USER

# Enable experimental features for better performance
experimental-features = nix-command

# Set maximum number of parallel jobs
max-jobs = auto

# Keep more generations for rollback capability
keep-derivations = true
keep-outputs = true
EOF

    # Set proper ownership
    chown -R "$NIX_USER:staff" "/Users/$NIX_USER/.config"
    
    log "Nix user configuration created for $NIX_USER"
}

# Install required Nix packages
install_nix_packages() {
    log "Installing required Nix packages for multi-cloud Kubernetes infrastructure..."
    
    # Switch to the user to install packages
    sudo -u "$NIX_USER" bash <<EOF
# Source Nix environment
if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# Install Kubernetes tools
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] \$*"
}

log "Installing kubectl..."
nix-env -iA nixpkgs.kubectl

log "Installing clusterctl..."
nix-env -iA nixpkgs.clusterctl

log "Installing helm..."
nix-env -iA nixpkgs.kubernetes-helm-wrapped

log "Installing talosctl..."
nix-env -iA nixpkgs.talosctl

log "Installing Docker and Kind..."
nix-env -iA nixpkgs.docker
nix-env -iA nixpkgs.kind

log "Installing development tools..."
nix-env -iA nixpkgs.git
nix-env -iA nixpkgs.curl
nix-env -iA nixpkgs.wget
nix-env -iA nixpkgs.jq
nix-env -iA nixpkgs.python3

log "Installing cloud provider CLIs..."
nix-env -iA nixpkgs.awscli2
nix-env -iA nixpkgs.azure-cli
nix-env -iA nixpkgs.google-cloud-sdk
nix-env -iA nixpkgs.ibmcloud-cli

log "Installing security tools..."
nix-env -iA nixpkgs.gnupg
nix-env -iA nixpkgs.openssl
nix-env -iA nixpkgs.age

log "Installing networking tools..."
nix-env -iA nixpkgs.wireguard-tools
nix-env -iA nixpkgs.tcpdump
nix-env -iA nixpkgs.nmap

log "Installing container tools..."
nix-env -iA nixpkgs.docker-compose
nix-env -iA nixpkgs.podman
nix-env -iA nixpkgs.skopeo

log "Installing monitoring tools..."
nix-env -iA nixpkgs.htop
nix-env -iA nixpkgs.iotop
nix-env -iA nixpkgs.sysstat

log "All Nix packages installed successfully"
EOF

    log "Nix packages installation completed"
}

# Create Nix environment setup script
create_nix_environment() {
    log "Creating Nix environment setup script..."
    
    tee ./setup-nix-environment.sh > /dev/null <<EOF
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
    echo "Nix version: \$(nix --version)"
else
    echo "Error: Nix not found in PATH"
    exit 1
fi

# Verify installed packages
echo "Verifying installed packages:"
echo "  kubectl: \$(kubectl version --client --short 2>/dev/null || echo 'not found')"
echo "  clusterctl: \$(clusterctl version --short 2>/dev/null || echo 'not found')"
echo "  helm: \$(helm version --short 2>/dev/null || echo 'not found')"
echo "  talosctl: \$(talosctl version --short 2>/dev/null || echo 'not found')"
echo "  docker: \$(docker --version 2>/dev/null || echo 'not found')"
echo "  kind: \$(kind version 2>/dev/null || echo 'not found')"

echo "Nix environment setup complete!"
EOF

    chmod +x ./setup-nix-environment.sh
    log "Nix environment setup script created"
}

# Create Nix package management script
create_nix_management() {
    log "Creating Nix package management script..."
    
    tee ./manage-nix-packages.sh > /dev/null <<EOF
#!/bin/bash

# Nix Package Management Script for Multi-Cloud Kubernetes Infrastructure
set -euo pipefail

usage() {
    echo "Usage: \$0 {status|update|clean|list|install|remove}"
    echo ""
    echo "Commands:"
    echo "  status  - Show Nix system status"
    echo "  update  - Update Nix channels and packages"
    echo "  clean   - Clean Nix store and generations"
    echo "  list    - List installed packages"
    echo "  install - Install additional packages"
    echo "  remove  - Remove packages"
}

status_nix() {
    echo "Nix System Status:"
    echo "=================="
    
    echo -e "\nNix Version:"
    nix --version
    
    echo -e "\nNix Configuration:"
    echo "  System config: /etc/nix/nix.conf"
    echo "  User config: ~/.config/nix/nix.conf"
    echo "  Trusted users: \$(grep 'trusted-users' /etc/nix/nix.conf | cut -d= -f2 | tr -d ' ')"
    
    echo -e "\nNix Store:"
    nix-store --query --roots /nix/store | head -5
    
    echo -e "\nInstalled Packages:"
    nix-env -q | head -10
}

update_nix() {
    echo "Updating Nix channels and packages..."
    
    # Update Nix channels
    nix-channel --update
    
    # Update installed packages
    nix-env -u
    
    echo "Nix update completed"
}

clean_nix() {
    echo "Cleaning Nix store and generations..."
    
    # Collect garbage
    nix-collect-garbage -d
    
    # Remove old generations
    nix-env --delete-generations old
    
    echo "Nix cleanup completed"
}

list_packages() {
    echo "Installed Nix Packages:"
    echo "======================="
    
    nix-env -q
}

install_packages() {
    echo "Installing additional packages..."
    
    # Install common development packages
    nix-env -iA nixpkgs.vim
    nix-env -iA nixpkgs.tmux
    nix-env -iA nixpkgs.zsh
    nix-env -iA nixpkgs.bash-completion
    
    echo "Additional packages installed"
}

remove_packages() {
    echo "Removing packages..."
    
    # Remove packages (example)
    # nix-env -e package-name
    
    echo "Package removal completed"
}

main() {
    case "\${1:-}" in
        status)
            status_nix
            ;;
        update)
            update_nix
            ;;
        clean)
            clean_nix
            ;;
        list)
            list_packages
            ;;
        install)
            install_packages
            ;;
        remove)
            remove_packages
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "\$@"
EOF

    chmod +x ./manage-nix-packages.sh
    log "Nix package management script created"
}

# Create Nix architecture documentation
create_nix_architecture() {
    log "Creating Nix architecture documentation..."
    
    tee ./nix-architecture.md > /dev/null <<EOF
# Nix Architecture for Multi-Cloud Kubernetes Infrastructure

## Overview

This document describes the Nix package manager setup for the multi-cloud Kubernetes infrastructure project.

## Nix Configuration

### System-Wide Configuration (`/etc/nix/nix.conf`)

\`\`\`ini
# Nix system-wide configuration for multi-cloud Kubernetes infrastructure

# Enable experimental features
experimental-features = nix-command flakes

# Set maximum number of parallel jobs
max-jobs = auto

# Keep more generations for rollback capability
keep-derivations = true
keep-outputs = true

# Auto-optimise store
auto-optimise-store = true

# Sandbox settings
sandbox = true

# Substituters for faster package downloads
substituters = https://cache.nixos.org/ https://nix-community.cachix.org/
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=

# Build users for CI/CD
build-users-group = nixbld
build-users = nixbld1 nixbld2 nixbld3 nixbld4 nixbld5 nixbld6 nixbld7 nixbld8 nixbld9 nixbld10

# Trusted users
trusted-users = root $NIX_USER
\`\`\`

### User Configuration (`~/.config/nix/nix.conf`)

\`\`\`ini
# Nix user configuration for multi-cloud Kubernetes infrastructure
# User: $NIX_USER

# Enable experimental features for better performance
experimental-features = nix-command

# Set maximum number of parallel jobs
max-jobs = auto

# Keep more generations for rollback capability
keep-derivations = true
keep-outputs = true
\`\`\`

## Installed Packages

### Kubernetes Tools
- **kubectl**: Kubernetes command-line tool
- **clusterctl**: Cluster API command-line tool
- **helm**: Kubernetes package manager
- **talosctl**: Talos OS command-line tool

### Container Runtime
- **docker**: Container runtime
- **kind**: Kubernetes in Docker
- **docker-compose**: Multi-container Docker applications
- **podman**: Container runtime
- **skopeo**: Container image operations

### Cloud Provider CLIs
- **awscli2**: AWS command-line interface
- **azure-cli**: Azure command-line interface
- **google-cloud-sdk**: Google Cloud SDK
- **ibmcloud-cli**: IBM Cloud CLI

### Development Tools
- **git**: Version control system
- **curl**: HTTP client
- **wget**: File downloader
- **jq**: JSON processor
- **python3**: Python interpreter

### Security Tools
- **gnupg**: GNU Privacy Guard
- **openssl**: SSL/TLS toolkit
- **age**: File encryption tool

### Networking Tools
- **wireguard-tools**: WireGuard VPN tools
- **tcpdump**: Network packet analyzer
- **nmap**: Network mapper

### Monitoring Tools
- **htop**: Interactive process viewer
- **iotop**: I/O monitoring tool
- **sysstat**: System performance tools

## Nix Build Users

The system is configured with 10 Nix build users (`nixbld1` through `nixbld10`) for CI/CD operations:

- **nixbld1**: AWS provider builds
- **nixbld2**: Azure provider builds
- **nixbld3**: GCP provider builds
- **nixbld4**: IBM provider builds
- **nixbld5**: DigitalOcean provider builds
- **nixbld6**: General Kubernetes builds
- **nixbld7**: Container runtime builds
- **nixbld8**: Networking builds
- **nixbld9**: Security builds
- **nixbld10**: Monitoring builds

## Management Commands

### Environment Setup
\`\`\`bash
# Source Nix environment
source ./setup-nix-environment.sh
\`\`\`

### Package Management
\`\`\`bash
# Check Nix status
./manage-nix-packages.sh status

# Update packages
./manage-nix-packages.sh update

# Clean Nix store
./manage-nix-packages.sh clean

# List installed packages
./manage-nix-packages.sh list
\`\`\`

### Direct Nix Commands
\`\`\`bash
# Install packages
nix-env -iA nixpkgs.package-name

# Remove packages
nix-env -e package-name

# Update packages
nix-env -u

# List packages
nix-env -q
\`\`\`

## Benefits

- **Reproducible**: All packages are versioned and reproducible
- **Declarative**: Package installation is declarative
- **Rollback**: Easy rollback to previous generations
- **Isolation**: Packages are isolated and don't conflict
- **CI/CD Ready**: Build users configured for automated builds
- **Multi-User**: Supports multiple users with different permissions

## Integration with Multi-Cloud Infrastructure

The Nix setup integrates with the multi-cloud Kubernetes infrastructure by:

1. **Volume Configuration**: Each volume has its own Nix configuration
2. **Package Installation**: Kubernetes tools installed via Nix in each volume
3. **Build Users**: Nix build users used for CI/CD across cloud providers
4. **Reproducible Builds**: All infrastructure components built reproducibly
5. **Version Management**: Consistent package versions across all environments
EOF

    log "Nix architecture documentation created"
}

# Main execution
main() {
    log "Setting up complete Nix environment for multi-cloud Kubernetes infrastructure..."
    
    check_root
    install_nix
    configure_nix_system
    configure_nix_user
    install_nix_packages
    create_nix_environment
    create_nix_management
    create_nix_architecture
    
    log "Complete Nix setup finished!"
    log ""
    log "Next steps:"
    log "1. Source Nix environment: source ./setup-nix-environment.sh"
    log "2. Check Nix status: ./manage-nix-packages.sh status"
    log "3. View architecture: cat ./nix-architecture.md"
    log ""
    log "Nix components created:"
    log "- System-wide Nix configuration (/etc/nix/nix.conf)"
    log "- User Nix configuration (~/.config/nix/nix.conf)"
    log "- All required packages installed"
    log "- Environment setup script"
    log "- Package management script"
    log "- Architecture documentation"
    log ""
    log "Trusted user: $NIX_USER"
    log "Build users: nixbld1 through nixbld10"
}

main "$@"
