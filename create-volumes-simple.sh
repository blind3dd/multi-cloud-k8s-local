#!/bin/bash

# Simplified Encrypted Volume Creation Script
# Creates encrypted volumes for multi-cloud Kubernetes cluster

set -euo pipefail

# Configuration
BASE_DIR="/opt/nix-volumes"
VOLUME_SIZE="10G"

# Node configuration
K8S_NODES=(
    # etcd nodes (3 nodes for HA with Flatcar base)
    "etcd-1:aws:flatcar"
    "etcd-2:azure:flatcar"
    "etcd-3:gcp:flatcar"

    # Control plane nodes (Talos OS on Flatcar base, managed by CAPI)
    "talos-control-plane-1:aws:talos"
    "talos-control-plane-2:azure:talos"
    "talos-control-plane-3:gcp:talos"
    "talos-control-plane-4:ibm:talos"
    "talos-control-plane-5:digitalocean:talos"

    # Worker nodes (Karpenter-provisioned, Talos OS on Flatcar base)
    "karpenter-worker-1:aws:talos"
    "karpenter-worker-2:azure:talos"
    "karpenter-worker-3:gcp:talos"
    "karpenter-worker-4:ibm:talos"
    "karpenter-worker-5:digitalocean:talos"
)

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Create base directory structure
create_base_structure() {
    log "Creating base directory structure..."
    sudo mkdir -p "$BASE_DIR"
    sudo chown "$(whoami):staff" "$BASE_DIR"
}

# Create encrypted volume for a single node
create_encrypted_volume() {
    local node_info="$1"
    local node_name=$(echo "$node_info" | cut -d: -f1)
    local provider=$(echo "$node_info" | cut -d: -f2)
    local os_type=$(echo "$node_info" | cut -d: -f3)
    
    log "Creating encrypted volume for $node_name ($provider, $os_type)..."
    
    local volume_dir="$BASE_DIR/$node_name"
    local mount_point="$volume_dir/mount"
    local disk_image="$volume_dir/$node_name.dmg"
    
    # Create volume directory
    mkdir -p "$volume_dir"
    
    # Create passphrase
    local passphrase="nix-k8s-$node_name"
    echo "$passphrase" > "$volume_dir/$node_name.passphrase"
    chmod 600 "$volume_dir/$node_name.passphrase"
    
    # Create encrypted sparse disk image
    log "Creating encrypted sparse disk image..."
    echo "$passphrase" | sudo hdiutil create -size "$VOLUME_SIZE" -type SPARSE -fs APFS -encryption AES-256 -stdinpass -volname "$node_name" "$disk_image"
    
    # Mount the encrypted volume
    log "Mounting encrypted volume..."
    echo "$passphrase" | sudo hdiutil attach "$disk_image.sparseimage" -mountpoint "$mount_point" -stdinpass
    
    # Set ownership
    sudo chown -R "$(whoami):staff" "$mount_point"
    
    log "Volume $node_name created and mounted successfully"
}

# Create all encrypted volumes
create_all_volumes() {
    log "Creating all encrypted volumes..."
    
    for node_info in "${K8S_NODES[@]}"; do
        create_encrypted_volume "$node_info"
    done
    
    log "All volumes created successfully!"
}

# Create volume management script
create_volume_management() {
    log "Creating volume management script..."
    
    tee "$BASE_DIR/manage-volumes.sh" > /dev/null <<'EOF'
#!/bin/bash

BASE_DIR="/opt/nix-volumes"

usage() {
    echo "Usage: $0 {mount-all|unmount-all|status|shell <node-name>}"
    echo ""
    echo "Commands:"
    echo "  mount-all    - Mount all encrypted volumes"
    echo "  unmount-all  - Unmount all encrypted volumes"
    echo "  status       - Show status of all volumes"
    echo "  shell <node> - Open shell in specific node volume"
}

mount_all() {
    echo "Mounting all volumes..."
    for volume_dir in "$BASE_DIR"/*/; do
        if [ -d "$volume_dir" ]; then
            node_name=$(basename "$volume_dir")
            if [ -f "$volume_dir/$node_name.passphrase" ]; then
                passphrase=$(cat "$volume_dir/$node_name.passphrase")
                echo "$passphrase" | sudo hdiutil attach "$volume_dir/$node_name.dmg.sparseimage" -mountpoint "$volume_dir/mount" -stdinpass
                echo "Mounted $node_name"
            fi
        fi
    done
}

unmount_all() {
    echo "Unmounting all volumes..."
    for volume_dir in "$BASE_DIR"/*/; do
        if [ -d "$volume_dir" ]; then
            node_name=$(basename "$volume_dir")
            if [ -d "$volume_dir/mount" ]; then
                sudo hdiutil detach "$volume_dir/mount"
                echo "Unmounted $node_name"
            fi
        fi
    done
}

status() {
    echo "Volume status:"
    for volume_dir in "$BASE_DIR"/*/; do
        if [ -d "$volume_dir" ]; then
            node_name=$(basename "$volume_dir")
            if [ -d "$volume_dir/mount" ]; then
                echo "  $node_name: MOUNTED"
            else
                echo "  $node_name: UNMOUNTED"
            fi
        fi
    done
}

shell() {
    local node_name="$1"
    local volume_dir="$BASE_DIR/$node_name"
    
    if [ ! -d "$volume_dir/mount" ]; then
        echo "Error: Volume $node_name is not mounted"
        exit 1
    fi
    
    echo "Opening shell in $node_name volume..."
    cd "$volume_dir/mount"
    export PS1="[$node_name:\$(echo \$PWD | sed \"s|$BASE_DIR/||\")] \$ "
    bash
}

main() {
    case "${1:-}" in
        mount-all)
            mount_all
            ;;
        unmount-all)
            unmount_all
            ;;
        status)
            status
            ;;
        shell)
            if [ $# -lt 2 ]; then
                echo "Error: shell command requires node name"
                usage
                exit 1
            fi
            shell "$2"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
EOF

    chmod +x "$BASE_DIR/manage-volumes.sh"
    log "Volume management script created"
}

# Main execution
main() {
    log "Starting simplified encrypted volume creation..."
    
    create_base_structure
    create_all_volumes
    create_volume_management
    
    log "Setup complete!"
    log ""
    log "Next steps:"
    log "1. Check volume status: $BASE_DIR/manage-volumes.sh status"
    log "2. Mount all volumes: $BASE_DIR/manage-volumes.sh mount-all"
    log "3. Open shell in a volume: $BASE_DIR/manage-volumes.sh shell etcd-1"
}

main "$@"
