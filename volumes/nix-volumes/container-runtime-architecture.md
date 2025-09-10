# Container Runtime Architecture for Multi-Cloud Kubernetes

## Overview

This setup configures containerd and crictl as the container runtime for all Kubernetes volumes, providing a consistent container runtime across all cloud providers.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Container Runtime Layer                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   AWS Volume    │  │  Azure Volume   │  │   GCP Volume    │ │
│  │                 │  │                 │  │                 │ │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │ │
│  │ │ containerd  │ │  │ │ containerd  │ │  │ │ containerd  │ │ │
│  │ │   v2.1.4    │ │  │ │   v2.1.4    │ │  │ │   v2.1.4    │ │ │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │ │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │ │
│  │ │   crictl    │ │  │ │   crictl    │ │  │ │   crictl    │ │ │
│  │ │   v1.32.0   │ │  │ │   v1.32.0   │ │  │ │   v1.32.0   │ │ │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │ │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │ │
│  │ │    runc     │ │  │ │    runc     │ │  │ │    runc     │ │ │
│  │ │   v1.3.0    │ │  │ │   v1.3.0    │ │  │ │   v1.3.0    │ │ │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│         │                       │                       │       │
│         └───────────────────────┼───────────────────────┘       │
│                                 │                               │
│  ┌─────────────────┐  ┌─────────────────┐                      │
│  │   IBM Volume    │  │  Talos Volume   │                      │
│  │                 │  │                 │                      │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │                      │
│  │ │ containerd  │ │  │ │ containerd  │ │                      │
│  │ │   v2.1.4    │ │  │ │   v2.1.4    │ │                      │
│  │ └─────────────┘ │  │ └─────────────┘ │                      │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │                      │
│  │ │   crictl    │ │  │ │   crictl    │ │                      │
│  │ │   v1.32.0   │ │  │ │   v1.32.0   │ │                      │
│  │ └─────────────┘ │  │ └─────────────┘ │                      │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │                      │
│  │ │    runc     │ │  │ │    runc     │ │                      │
│  │ │   v1.3.0    │ │  │ │   v1.3.0    │ │                      │
│  │ └─────────────┘ │  │ └─────────────┘ │                      │
│  └─────────────────┘  └─────────────────┘                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### Containerd (v2.1.4)
- **Purpose**: Container runtime daemon
- **Configuration**: `/etc/containerd/config.toml`
- **Service**: `containerd.service`
- **Socket**: `unix:///run/containerd/containerd.sock`

### crictl (v1.32.0)
- **Purpose**: Container runtime CLI
- **Configuration**: `/etc/crictl/crictl.yaml`
- **Usage**: Debugging and managing containers

### runc (v1.3.0)
- **Purpose**: OCI-compliant runtime
- **Location**: `/usr/local/bin/runc`
- **Usage**: Low-level container execution

### CNI Plugins (v1.4.1)
- **Purpose**: Container networking
- **Location**: `/opt/cni/bin`
- **Configuration**: `/etc/cni/net.d/`

## Configuration Files

### Containerd Configuration
- **File**: `/etc/containerd/config.toml`
- **Features**: 
  - CRI plugin enabled
  - OverlayFS snapshotter
  - Systemd cgroup support
  - Registry mirrors for Docker Hub, K8s, GitHub, Quay
  - Image decryption support

### crictl Configuration
- **File**: `/etc/crictl/crictl.yaml`
- **Features**:
  - Containerd socket connection
  - 10-second timeout
  - Debug disabled by default

### CNI Configuration
- **Bridge**: `/etc/cni/net.d/10-bridge.conf`
- **Loopback**: `/etc/cni/net.d/99-loopback.conf`
- **Subnet**: 10.22.0.0/16

## Management Commands

```bash
# Check status
/opt/nix-volumes/manage-container-runtime.sh status

# Start containerd in all volumes
/opt/nix-volumes/manage-container-runtime.sh start

# Stop containerd in all volumes
/opt/nix-volumes/manage-container-runtime.sh stop

# Test crictl in all volumes
/opt/nix-volumes/manage-container-runtime.sh test

# Install container runtime in all volumes
/opt/nix-volumes/manage-container-runtime.sh install
```

## Per-Volume Management

Each volume has its own container runtime manager:

```bash
# Inside each volume
/opt/container-runtime-manager.sh start
/opt/container-runtime-manager.sh status
/opt/container-runtime-manager.sh test
/opt/container-runtime-manager.sh list-containers
/opt/container-runtime-manager.sh list-images
```

## Integration with Kubernetes

The container runtime integrates with:
- **kubelet**: Uses containerd via CRI
- **CNI**: Provides container networking
- **CAPI**: Manages container runtime across clusters
- **Talos**: Uses containerd as the primary runtime

## Installation Process

1. **Download**: Get containerd, runc, crictl, and CNI plugins
2. **Install**: Copy binaries to `/usr/local/bin/`
3. **Configure**: Set up configuration files
4. **Service**: Enable and start containerd service
5. **Test**: Verify with crictl commands
