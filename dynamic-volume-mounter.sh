#!/bin/bash

# Dynamic Volume Mounter for CAPI Scaling
# Mounts new volumes when CAPI requests new machines

VOLUME_BASE_DIR="$(pwd)/volumes"
VOLUME_SIZE="10G"
CLOUD_PROVIDERS=("aws" "azure" "gcp" "ibm" "digitalocean")

echo "🏗️ DYNAMIC VOLUME MOUNTER FOR CAPI SCALING 🏗️"
echo "=============================================="
echo ""

# Function to create and mount a new volume
create_and_mount_volume() {
    local provider=$1
    local node_type=$2
    local node_number=$3
    
    local volume_name="${provider}-${node_type}-${node_number}"
    local volume_path="${VOLUME_BASE_DIR}/${volume_name}"
    local volume_file="${volume_path}/${volume_name}.dmg.sparseimage"
    local mount_path="${volume_path}/mount"
    
    echo "🔧 Creating volume: ${volume_name}"
    
    # Create directory structure
    mkdir -p "${volume_path}"
    mkdir -p "${mount_path}"
    
    # Create sparse disk image
    hdiutil create -size ${VOLUME_SIZE} -type SPARSE -fs HFS+ -volname "${volume_name}" "${volume_file}"
    
    # Mount the volume
    hdiutil attach "${volume_file}" -mountpoint "${mount_path}"
    
    # Create basic directory structure for the "machine"
    mkdir -p "${mount_path}/etc/kubernetes"
    mkdir -p "${mount_path}/var/lib/kubelet"
    mkdir -p "${mount_path}/var/lib/containerd"
    mkdir -p "${mount_path}/opt/cni/bin"
    
    # Create machine metadata
    cat > "${mount_path}/etc/kubernetes/machine-info" << EOF
{
  "provider": "${provider}",
  "nodeType": "${node_type}",
  "nodeNumber": ${node_number},
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "ready",
  "capacity": {
    "cpu": "2",
    "memory": "4Gi",
    "storage": "${VOLUME_SIZE}"
  }
}
EOF
    
    echo "✅ Volume ${volume_name} created and mounted at ${mount_path}"
    return 0
}

# Function to unmount and remove a volume
unmount_and_remove_volume() {
    local provider=$1
    local node_type=$2
    local node_number=$3
    
    local volume_name="${provider}-${node_type}-${node_number}"
    local volume_path="${VOLUME_BASE_DIR}/${volume_name}"
    local volume_file="${volume_path}/${volume_name}.dmg.sparseimage"
    local mount_path="${volume_path}/mount"
    
    echo "🗑️ Removing volume: ${volume_name}"
    
    # Unmount if mounted
    if mount | grep -q "${mount_path}"; then
        hdiutil detach "${mount_path}"
    fi
    
    # Remove volume file
    if [ -f "${volume_file}" ]; then
        rm -f "${volume_file}"
    fi
    
    # Remove directory
    rm -rf "${volume_path}"
    
    echo "✅ Volume ${volume_name} removed"
    return 0
}

# Function to list all mounted volumes
list_volumes() {
    echo "📊 CURRENT VOLUMES:"
    echo "-------------------"
    
    for provider in "${CLOUD_PROVIDERS[@]}"; do
        echo "🌐 ${provider^^} Provider:"
        
        # List control plane nodes
        for i in {1..3}; do
            volume_path="${VOLUME_BASE_DIR}/${provider}-control-plane-${i}"
            if [ -d "${volume_path}" ]; then
                if mount | grep -q "${volume_path}/mount"; then
                    echo "  ✅ ${provider}-control-plane-${i} (mounted)"
                else
                    echo "  ⚠️  ${provider}-control-plane-${i} (unmounted)"
                fi
            fi
        done
        
        # List worker nodes
        for i in {1..5}; do
            volume_path="${VOLUME_BASE_DIR}/${provider}-worker-${i}"
            if [ -d "${volume_path}" ]; then
                if mount | grep -q "${volume_path}/mount"; then
                    echo "  ✅ ${provider}-worker-${i} (mounted)"
                else
                    echo "  ⚠️  ${provider}-worker-${i} (unmounted)"
                fi
            fi
        done
        echo ""
    done
}

# Function to scale up a specific provider
scale_up_provider() {
    local provider=$1
    local node_type=$2
    local current_count=$3
    local new_count=$4
    
    echo "📈 SCALING UP ${provider^^} ${node_type^^} NODES:"
    echo "  From: ${current_count} nodes"
    echo "  To: ${new_count} nodes"
    echo ""
    
    for ((i=current_count+1; i<=new_count; i++)); do
        create_and_mount_volume "${provider}" "${node_type}" "${i}"
        echo "  🚀 New ${node_type} node ${i} ready for CAPI"
    done
    
    echo "✅ Scaling complete!"
}

# Function to scale down a specific provider
scale_down_provider() {
    local provider=$1
    local node_type=$2
    local current_count=$3
    local new_count=$4
    
    echo "📉 SCALING DOWN ${provider^^} ${node_type^^} NODES:"
    echo "  From: ${current_count} nodes"
    echo "  To: ${new_count} nodes"
    echo ""
    
    for ((i=current_count; i>new_count; i--)); do
        unmount_and_remove_volume "${provider}" "${node_type}" "${i}"
        echo "  🗑️ Removed ${node_type} node ${i}"
    done
    
    echo "✅ Scaling complete!"
}

# Function to simulate CAPI scaling events
simulate_capi_scaling() {
    echo "🎯 SIMULATING CAPI SCALING EVENTS 🎯"
    echo "===================================="
    echo ""
    
    echo "📊 Current cluster status:"
    kubectl get nodes 2>/dev/null || echo "No Kubernetes cluster running"
    echo ""
    
    echo "🏗️ Simulating scale-up events..."
    
    # Scale up AWS workers
    scale_up_provider "aws" "worker" 5 7
    
    # Scale up Azure workers  
    scale_up_provider "azure" "worker" 5 6
    
    # Scale up GCP control plane
    scale_up_provider "gcp" "control-plane" 3 5
    
    echo ""
    echo "📊 Updated volume status:"
    list_volumes
}

# Main menu
case "${1:-menu}" in
    "create")
        create_and_mount_volume "$2" "$3" "$4"
        ;;
    "remove")
        unmount_and_remove_volume "$2" "$3" "$4"
        ;;
    "list")
        list_volumes
        ;;
    "scale-up")
        scale_up_provider "$2" "$3" "$4" "$5"
        ;;
    "scale-down")
        scale_down_provider "$2" "$3" "$4" "$5"
        ;;
    "simulate")
        simulate_capi_scaling
        ;;
    "menu"|*)
        echo "🎮 DYNAMIC VOLUME MOUNTER MENU 🎮"
        echo "================================="
        echo ""
        echo "Usage: $0 [command] [args]"
        echo ""
        echo "Commands:"
        echo "  create <provider> <type> <number>  - Create and mount a volume"
        echo "  remove <provider> <type> <number>  - Remove a volume"
        echo "  list                               - List all volumes"
        echo "  scale-up <provider> <type> <from> <to>  - Scale up nodes"
        echo "  scale-down <provider> <type> <from> <to> - Scale down nodes"
        echo "  simulate                           - Simulate CAPI scaling"
        echo ""
        echo "Examples:"
        echo "  $0 create aws worker 6"
        echo "  $0 scale-up azure worker 5 8"
        echo "  $0 simulate"
        echo ""
        list_volumes
        ;;
esac
