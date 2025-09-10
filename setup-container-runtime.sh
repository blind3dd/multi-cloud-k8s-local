#!/bin/bash

# Container Runtime Setup for Multi-Cloud Kubernetes Volumes
# Configures containerd and crictl for each volume

set -euo pipefail

# Configuration
BASE_DIR="/opt/nix-volumes"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Create container runtime configuration for each volume
create_container_runtime_config() {
    log "Creating container runtime configuration for volumes..."
    
    # Get all volume directories
    for volume_dir in "$BASE_DIR"/*/; do
        if [ -d "$volume_dir" ]; then
            local node_name=$(basename "$volume_dir")
            local mount_point="$volume_dir/mount"
            
            if [ -d "$mount_point" ]; then
                log "Creating container runtime config for $node_name..."
                
                # Create containerd configuration
                mkdir -p "$mount_point/etc/containerd"
                tee "$mount_point/etc/containerd/config.toml" > /dev/null <<EOF
# Containerd configuration for $node_name
version = 2

[plugins."io.containerd.grpc.v1.cri"]
  sandbox_image = "registry.k8s.io/pause:3.9"
  
  [plugins."io.containerd.grpc.v1.cri".containerd]
    snapshotter = "overlayfs"
    
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
        runtime_type = "io.containerd.runc.v2"
        
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
          SystemdCgroup = true
          
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.talos]
        runtime_type = "io.containerd.runc.v2"
        
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.talos.options]
          SystemdCgroup = true
          BinaryName = "/usr/local/bin/runc"
          Root = "/run/containerd/runc/talos"

[plugins."io.containerd.grpc.v1.cri".cni]
  bin_dir = "/opt/cni/bin"
  conf_dir = "/etc/cni/net.d"
  conf_template = ""

[plugins."io.containerd.grpc.v1.cri".registry]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
      endpoint = ["https://registry-1.docker.io"]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry.k8s.io"]
      endpoint = ["https://registry.k8s.io"]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."ghcr.io"]
      endpoint = ["https://ghcr.io"]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."quay.io"]
      endpoint = ["https://quay.io"]

[plugins."io.containerd.grpc.v1.cri".image_decryption]
  key_model = "node"

[plugins."io.containerd.grpc.v1.cri".x509_key_pair_streaming]
  tls_cert_file = "/etc/containerd/ssl/cert.pem"
  tls_private_key_file = "/etc/containerd/ssl/key.pem"
EOF

                # Create crictl configuration
                mkdir -p "$mount_point/etc/crictl"
                tee "$mount_point/etc/crictl/crictl.yaml" > /dev/null <<EOF
# crictl configuration for $node_name
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
pull-image-on-create: false
disable-pull-on-run: false
EOF

                # Create systemd service for containerd
                mkdir -p "$mount_point/etc/systemd/system"
                tee "$mount_point/etc/systemd/system/containerd.service" > /dev/null <<EOF
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd
Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF

                # Create container runtime management script
                tee "$mount_point/opt/container-runtime-manager.sh" > /dev/null <<EOF
#!/bin/bash

# Container Runtime Management Script for $node_name
set -euo pipefail

NODE_NAME="$node_name"

start_containerd() {
    echo "Starting containerd for \$NODE_NAME..."
    systemctl daemon-reload
    systemctl enable containerd
    systemctl start containerd
    echo "Containerd started for \$NODE_NAME"
}

stop_containerd() {
    echo "Stopping containerd for \$NODE_NAME..."
    systemctl stop containerd
    echo "Containerd stopped for \$NODE_NAME"
}

status_containerd() {
    echo "Containerd status for \$NODE_NAME:"
    systemctl status containerd --no-pager
}

test_crictl() {
    echo "Testing crictl for \$NODE_NAME..."
    crictl version
    crictl info
    echo "crictl test completed for \$NODE_NAME"
}

list_containers() {
    echo "Listing containers for \$NODE_NAME:"
    crictl ps -a
}

list_images() {
    echo "Listing images for \$NODE_NAME:"
    crictl images
}

pull_test_image() {
    echo "Pulling test image for \$NODE_NAME..."
    crictl pull registry.k8s.io/pause:3.9
    echo "Test image pulled for \$NODE_NAME"
}

case "\${1:-}" in
    start)
        start_containerd
        ;;
    stop)
        stop_containerd
        ;;
    status)
        status_containerd
        ;;
    test)
        test_crictl
        ;;
    list-containers)
        list_containers
        ;;
    list-images)
        list_images
        ;;
    pull-test)
        pull_test_image
        ;;
    *)
        echo "Usage: \$0 {start|stop|status|test|list-containers|list-images|pull-test}"
        exit 1
        ;;
esac
EOF

                chmod +x "$mount_point/opt/container-runtime-manager.sh"
                
                # Create CNI configuration
                mkdir -p "$mount_point/etc/cni/net.d"
                tee "$mount_point/etc/cni/net.d/10-bridge.conf" > /dev/null <<EOF
{
    "cniVersion": "1.0.0",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cni0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
            [{"subnet": "10.22.0.0/16"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

                # Create CNI loopback configuration
                tee "$mount_point/etc/cni/net.d/99-loopback.conf" > /dev/null <<EOF
{
    "cniVersion": "1.0.0",
    "name": "lo",
    "type": "loopback"
}
EOF

                log "Container runtime configuration created for $node_name"
            fi
        fi
    done
    
    log "Container runtime configurations created for all volumes"
}

# Create container runtime installation script
create_container_runtime_installer() {
    log "Creating container runtime installation script..."
    
    tee "$BASE_DIR/install-container-runtime.sh" > /dev/null <<'EOF'
#!/bin/bash

# Container Runtime Installation Script for Linux Volumes
# This script should be run inside each volume when it's running Linux

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

install_containerd() {
    log "Installing containerd..."
    
    # Download containerd
    wget -O containerd-2.1.4-linux-amd64.tar.gz https://github.com/containerd/containerd/releases/download/v2.1.4/containerd-2.1.4-linux-amd64.tar.gz
    
    # Extract containerd
    tar -xzf containerd-2.1.4-linux-amd64.tar.gz
    
    # Install containerd
    sudo cp bin/containerd /usr/local/bin/
    sudo cp bin/containerd-shim /usr/local/bin/
    sudo cp bin/containerd-shim-runc-v2 /usr/local/bin/
    sudo cp bin/ctr /usr/local/bin/
    
    # Install systemd service
    sudo cp containerd.service /etc/systemd/system/
    
    # Clean up
    rm -rf bin containerd-2.1.4-linux-amd64.tar.gz
    
    log "Containerd installed"
}

install_runc() {
    log "Installing runc..."
    
    # Download runc
    wget -O runc.amd64 https://github.com/opencontainers/runc/releases/download/v1.3.0/runc.amd64
    
    # Install runc
    sudo cp runc.amd64 /usr/local/bin/runc
    sudo chmod +x /usr/local/bin/runc
    
    # Clean up
    rm runc.amd64
    
    log "Runc installed"
}

install_crictl() {
    log "Installing crictl..."
    
    # Download crictl
    wget -O crictl-v1.32.0-linux-amd64.tar.gz https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.32.0/crictl-v1.32.0-linux-amd64.tar.gz
    
    # Extract crictl
    tar -xzf crictl-v1.32.0-linux-amd64.tar.gz
    
    # Install crictl
    sudo cp crictl /usr/local/bin/
    sudo chmod +x /usr/local/bin/crictl
    
    # Clean up
    rm crictl crictl-v1.32.0-linux-amd64.tar.gz
    
    log "crictl installed"
}

install_cni() {
    log "Installing CNI plugins..."
    
    # Download CNI plugins
    wget -O cni-plugins-linux-amd64-v1.4.1.tgz https://github.com/containernetworking/plugins/releases/download/v1.4.1/cni-plugins-linux-amd64-v1.4.1.tgz
    
    # Create CNI directory
    sudo mkdir -p /opt/cni/bin
    
    # Extract CNI plugins
    sudo tar -xzf cni-plugins-linux-amd64-v1.4.1.tgz -C /opt/cni/bin
    
    # Clean up
    rm cni-plugins-linux-amd64-v1.4.1.tgz
    
    log "CNI plugins installed"
}

main() {
    log "Installing container runtime components..."
    
    install_containerd
    install_runc
    install_crictl
    install_cni
    
    log "Container runtime installation completed"
    log "Next steps:"
    log "1. Start containerd: systemctl start containerd"
    log "2. Test crictl: crictl version"
    log "3. Use container runtime manager: /opt/container-runtime-manager.sh start"
}

main "$@"
EOF

    chmod +x "$BASE_DIR/install-container-runtime.sh"
    log "Container runtime installation script created"
}

# Create container runtime management script
create_container_runtime_management() {
    log "Creating container runtime management script..."
    
    tee "$BASE_DIR/manage-container-runtime.sh" > /dev/null <<'EOF'
#!/bin/bash

# Container Runtime Management Script for All Volumes
set -euo pipefail

BASE_DIR="/opt/nix-volumes"

usage() {
    echo "Usage: $0 {status|start|stop|test|install}"
    echo ""
    echo "Commands:"
    echo "  status  - Show container runtime status for all volumes"
    echo "  start   - Start containerd in all volumes"
    echo "  stop    - Stop containerd in all volumes"
    echo "  test    - Test crictl in all volumes"
    echo "  install - Install container runtime in all volumes"
}

status_container_runtime() {
    echo "Container Runtime Status for All Volumes:"
    echo "========================================="
    
    for volume_dir in "$BASE_DIR"/*/; do
        if [ -d "$volume_dir" ]; then
            local node_name=$(basename "$volume_dir")
            if [ -f "$volume_dir/mount/opt/container-runtime-manager.sh" ]; then
                echo -e "\n--- $node_name ---"
                echo "Container runtime: CONFIGURED"
                echo "Containerd config: /etc/containerd/config.toml"
                echo "crictl config: /etc/crictl/crictl.yaml"
                echo "CNI config: /etc/cni/net.d/"
            else
                echo -e "\n--- $node_name ---"
                echo "Container runtime: NOT CONFIGURED"
            fi
        fi
    done
}

start_container_runtime() {
    echo "Starting container runtime in all volumes..."
    
    for volume_dir in "$BASE_DIR"/*/; do
        if [ -d "$volume_dir" ]; then
            local node_name=$(basename "$volume_dir")
            if [ -f "$volume_dir/mount/opt/container-runtime-manager.sh" ]; then
                echo "Starting container runtime for $node_name..."
                # Note: This would need to be run inside the volume
                echo "  Run: /opt/container-runtime-manager.sh start"
            fi
        fi
    done
    
    echo "Container runtime start commands generated"
}

stop_container_runtime() {
    echo "Stopping container runtime in all volumes..."
    
    for volume_dir in "$BASE_DIR"/*/; do
        if [ -d "$volume_dir" ]; then
            local node_name=$(basename "$volume_dir")
            if [ -f "$volume_dir/mount/opt/container-runtime-manager.sh" ]; then
                echo "Stopping container runtime for $node_name..."
                # Note: This would need to be run inside the volume
                echo "  Run: /opt/container-runtime-manager.sh stop"
            fi
        fi
    done
    
    echo "Container runtime stop commands generated"
}

test_container_runtime() {
    echo "Testing container runtime in all volumes..."
    
    for volume_dir in "$BASE_DIR"/*/; do
        if [ -d "$volume_dir" ]; then
            local node_name=$(basename "$volume_dir")
            if [ -f "$volume_dir/mount/opt/container-runtime-manager.sh" ]; then
                echo "Testing container runtime for $node_name..."
                # Note: This would need to be run inside the volume
                echo "  Run: /opt/container-runtime-manager.sh test"
            fi
        fi
    done
    
    echo "Container runtime test commands generated"
}

install_container_runtime() {
    echo "Installing container runtime in all volumes..."
    
    for volume_dir in "$BASE_DIR"/*/; do
        if [ -d "$volume_dir" ]; then
            local node_name=$(basename "$volume_dir")
            if [ -d "$volume_dir/mount" ]; then
                echo "Installing container runtime for $node_name..."
                # Note: This would need to be run inside the volume
                echo "  Run: /opt/install-container-runtime.sh"
            fi
        fi
    done
    
    echo "Container runtime installation commands generated"
}

main() {
    case "${1:-}" in
        status)
            status_container_runtime
            ;;
        start)
            start_container_runtime
            ;;
        stop)
            stop_container_runtime
            ;;
        test)
            test_container_runtime
            ;;
        install)
            install_container_runtime
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
EOF

    chmod +x "$BASE_DIR/manage-container-runtime.sh"
    log "Container runtime management script created"
}

# Create container runtime architecture documentation
create_container_runtime_architecture() {
    log "Creating container runtime architecture documentation..."
    
    tee "$BASE_DIR/container-runtime-architecture.md" > /dev/null <<'EOF'
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
EOF

    log "Container runtime architecture documentation created"
}

# Main execution
main() {
    log "Setting up container runtime for multi-cloud Kubernetes volumes..."
    
    create_container_runtime_config
    create_container_runtime_installer
    create_container_runtime_management
    create_container_runtime_architecture
    
    log "Container runtime setup complete!"
    log ""
    log "Next steps:"
    log "1. Check status: $BASE_DIR/manage-container-runtime.sh status"
    log "2. Install runtime: $BASE_DIR/manage-container-runtime.sh install"
    log "3. Start runtime: $BASE_DIR/manage-container-runtime.sh start"
    log "4. Test runtime: $BASE_DIR/manage-container-runtime.sh test"
    log "5. View architecture: cat $BASE_DIR/container-runtime-architecture.md"
    log ""
    log "Note: Container runtime installation requires Linux environment."
    log "Run installation scripts inside each volume when running Linux."
}

main "$@"
