# Nix Architecture for Multi-Cloud Kubernetes Infrastructure

## Overview

This document describes the Nix package manager setup for the multi-cloud Kubernetes infrastructure project.

## Nix Configuration

### System-Wide Configuration ()

```ini
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
trusted-users = root usualsuspectx
```

### User Configuration ()

```ini
# Nix user configuration for multi-cloud Kubernetes infrastructure
# User: usualsuspectx

# Enable experimental features for better performance
experimental-features = nix-command

# Set maximum number of parallel jobs
max-jobs = auto

# Keep more generations for rollback capability
keep-derivations = true
keep-outputs = true
```

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

The system is configured with 10 Nix build users ( through ) for CI/CD operations:

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
```bash
# Source Nix environment
source ./setup-nix-environment.sh
```

### Package Management
```bash
# Check Nix status
./manage-nix-packages.sh status

# Update packages
./manage-nix-packages.sh update

# Clean Nix store
./manage-nix-packages.sh clean

# List installed packages
./manage-nix-packages.sh list
```

### Direct Nix Commands
```bash
# Install packages
nix-env -iA nixpkgs.package-name

# Remove packages
nix-env -e package-name

# Update packages
nix-env -u

# List packages
nix-env -q
```

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
