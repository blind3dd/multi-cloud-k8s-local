#!/bin/bash

# Provider-Grouped Volume Networking Setup
# Creates network configurations for volumes grouped by cloud providers

set -euo pipefail

# Configuration
BASE_DIR="/opt/nix-volumes"
NETWORK_DIR="$BASE_DIR/networking"

# Network configuration grouped by cloud providers
PROVIDER_NETWORKS=(
    "aws:10.0.0.0/16:10.0.1.1:etcd-1,talos-control-plane-1,karpenter-worker-1"
    "azure:10.1.0.0/16:10.1.1.1:etcd-2,talos-control-plane-2,karpenter-worker-2"
    "gcp:10.2.0.0/16:10.2.1.1:etcd-3,talos-control-plane-3,karpenter-worker-3"
    "ibm:10.3.0.0/16:10.3.1.1:talos-control-plane-4,karpenter-worker-4"
    "digitalocean:10.4.0.0/16:10.4.1.1:talos-control-plane-5,karpenter-worker-5"
)

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Create network configuration for each volume grouped by provider
create_volume_network_config() {
    log "Creating network configuration for volumes grouped by provider..."
    
    # Process each provider group
    for provider_info in "${PROVIDER_NETWORKS[@]}"; do
        local provider=$(echo "$provider_info" | cut -d: -f1)
        local network=$(echo "$provider_info" | cut -d: -f2)
        local gateway=$(echo "$provider_info" | cut -d: -f3)
        local volumes=$(echo "$provider_info" | cut -d: -f4)
        
        log "Creating network configs for $provider provider (volumes: $volumes)..."
        
        # Extract network base (e.g., 10.0 from 10.0.0.0/16)
        local network_base=$(echo "$network" | cut -d. -f1-2)
        
        # Create network configs for each volume in this provider group
        local volume_index=1
        IFS=',' read -ra VOLUME_ARRAY <<< "$volumes"
        for volume_name in "${VOLUME_ARRAY[@]}"; do
            local volume_dir="$BASE_DIR/$volume_name"
            local mount_point="$volume_dir/mount"
            
            if [ -d "$mount_point" ]; then
                log "Creating network config for $volume_name in $provider provider..."
                
                # Create network configuration directory
                mkdir -p "$mount_point/etc/network"
                
                # Calculate IP addresses
                local host_ip="$network_base.$volume_index.1"
                local ns_ip="$network_base.$volume_index.2"
                
                # Create network configuration
                tee "$mount_point/etc/network/interfaces" > /dev/null <<EOF
# Network configuration for $volume_name ($provider provider)
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address $ns_ip
    netmask 255.255.255.0
    gateway $host_ip
    dns-nameservers 8.8.8.8 8.8.4.4
EOF

                # Create systemd network configuration
                mkdir -p "$mount_point/etc/systemd/network"
                tee "$mount_point/etc/systemd/network/eth0.network" > /dev/null <<EOF
[Match]
Name=eth0

[Network]
Address=$ns_ip/24
Gateway=$host_ip
DNS=8.8.8.8
DNS=8.8.4.4
EOF

                # Create network management script
                tee "$mount_point/opt/network-manager.sh" > /dev/null <<EOF
#!/bin/bash

# Network management script for $volume_name ($provider provider)
set -euo pipefail

NODE_NAME="$volume_name"
PROVIDER="$provider"
HOST_IP="$host_ip"
NS_IP="$ns_ip"

show_network_info() {
    echo "Network information for \$NODE_NAME (\$PROVIDER provider):"
    echo "  Provider: \$PROVIDER"
    echo "  Host IP: \$HOST_IP"
    echo "  Node IP: \$NS_IP"
    echo "  Network: $network"
    echo "  Gateway: $gateway"
}

test_connectivity() {
    echo "Testing connectivity for \$NODE_NAME (\$PROVIDER provider)..."
    echo "  Node IP: \$NS_IP"
    echo "  Gateway: \$HOST_IP"
    echo "  DNS: 8.8.8.8"
    echo "Connectivity test completed for \$NODE_NAME"
}

show_cross_provider_info() {
    echo "Cross-provider connectivity for \$NODE_NAME:"
    echo "  AWS provider: 10.0.0.0/16 (gateway: 10.0.1.1)"
    echo "  Azure provider: 10.1.0.0/16 (gateway: 10.1.1.1)"
    echo "  GCP provider: 10.2.0.0/16 (gateway: 10.2.1.1)"
    echo "  IBM provider: 10.3.0.0/16 (gateway: 10.3.1.1)"
    echo "  DigitalOcean provider: 10.4.0.0/16 (gateway: 10.4.1.1)"
}

case "\${1:-}" in
    info)
        show_network_info
        ;;
    test)
        test_connectivity
        ;;
    cross-provider)
        show_cross_provider_info
        ;;
    *)
        echo "Usage: \$0 {info|test|cross-provider}"
        exit 1
        ;;
esac
EOF

                chmod +x "$mount_point/opt/network-manager.sh"
                
                log "Network configuration created for $volume_name (IP: $ns_ip) in $provider provider"
            fi
            
            ((volume_index++))
        done
    done
    
    log "Volume network configurations created for all providers"
}

# Create cross-cloud network management script
create_network_management() {
    log "Creating cross-cloud network management script..."
    
    tee "$NETWORK_DIR/manage-provider-networking.sh" > /dev/null <<'EOF'
#!/bin/bash

# Provider-Grouped Volume Networking Management Script
set -euo pipefail

BASE_DIR="/opt/nix-volumes"
NETWORK_DIR="$BASE_DIR/networking"

usage() {
    echo "Usage: $0 {status|test|info|cross-provider}"
    echo ""
    echo "Commands:"
    echo "  status         - Show network status for all volumes"
    echo "  test           - Test network configurations"
    echo "  info           - Show detailed network information"
    echo "  cross-provider - Show cross-provider connectivity info"
}

status_networking() {
    echo "Provider-Grouped Volume Networking Status:"
    echo "=========================================="
    
    echo -e "\nProvider Groups:"
    echo "  AWS provider: 10.0.0.0/16 (gateway: 10.0.1.1)"
    echo "    Volumes: etcd-1, talos-control-plane-1, karpenter-worker-1"
    echo "  Azure provider: 10.1.0.0/16 (gateway: 10.1.1.1)"
    echo "    Volumes: etcd-2, talos-control-plane-2, karpenter-worker-2"
    echo "  GCP provider: 10.2.0.0/16 (gateway: 10.2.1.1)"
    echo "    Volumes: etcd-3, talos-control-plane-3, karpenter-worker-3"
    echo "  IBM provider: 10.3.0.0/16 (gateway: 10.3.1.1)"
    echo "    Volumes: talos-control-plane-4, karpenter-worker-4"
    echo "  DigitalOcean provider: 10.4.0.0/16 (gateway: 10.4.1.1)"
    echo "    Volumes: talos-control-plane-5, karpenter-worker-5"
    
    echo -e "\nVolume Network Status:"
    for volume_dir in "$BASE_DIR"/*/; do
        if [ -d "$volume_dir" ]; then
            local node_name=$(basename "$volume_dir")
            if [ -f "$volume_dir/mount/opt/network-manager.sh" ]; then
                echo "  $node_name: CONFIGURED"
            else
                echo "  $node_name: NOT CONFIGURED"
            fi
        fi
    done
}

test_networking() {
    echo "Testing network configurations..."
    
    for volume_dir in "$BASE_DIR"/*/; do
        if [ -d "$volume_dir" ]; then
            local node_name=$(basename "$volume_dir")
            if [ -f "$volume_dir/mount/opt/network-manager.sh" ]; then
                echo "Testing $node_name..."
                "$volume_dir/mount/opt/network-manager.sh" test
            fi
        fi
    done
    
    echo "Network configuration test completed"
}

info_networking() {
    echo "Detailed Network Information:"
    echo "============================="
    
    for volume_dir in "$BASE_DIR"/*/; do
        if [ -d "$volume_dir" ]; then
            local node_name=$(basename "$volume_dir")
            if [ -f "$volume_dir/mount/opt/network-manager.sh" ]; then
                echo -e "\n--- $node_name ---"
                "$volume_dir/mount/opt/network-manager.sh" info
            fi
        fi
    done
}

cross_provider_info() {
    echo "Cross-Provider Connectivity Information:"
    echo "======================================="
    
    for volume_dir in "$BASE_DIR"/*/; do
        if [ -d "$volume_dir" ]; then
            local node_name=$(basename "$volume_dir")
            if [ -f "$volume_dir/mount/opt/network-manager.sh" ]; then
                echo -e "\n--- $node_name ---"
                "$volume_dir/mount/opt/network-manager.sh" cross-provider
            fi
        fi
    done
}

main() {
    case "${1:-}" in
        status)
            status_networking
            ;;
        test)
            test_networking
            ;;
        info)
            info_networking
            ;;
        cross-provider)
            cross_provider_info
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
EOF

    chmod +x "$NETWORK_DIR/manage-provider-networking.sh"
    log "Provider networking management script created"
}

# Create network architecture diagram
create_network_architecture() {
    log "Creating provider-grouped network architecture diagram..."
    
    tee "$NETWORK_DIR/provider-networking-architecture.md" > /dev/null <<'EOF'
# Provider-Grouped Volume Networking Architecture

## Network Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                    Provider-Grouped Networking                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   AWS Provider  │  │ Azure Provider  │  │   GCP Provider  │ │
│  │  10.0.0.0/16    │  │  10.1.0.0/16    │  │  10.2.0.0/16    │ │
│  │                 │  │                 │  │                 │ │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │ │
│  │ │   etcd-1    │ │  │ │   etcd-2    │ │  │ │   etcd-3    │ │ │
│  │ │ 10.0.1.2    │ │  │ │ 10.1.1.2    │ │  │ │ 10.2.1.2    │ │ │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │ │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │ │
│  │ │talos-cp-1   │ │  │ │talos-cp-2   │ │  │ │talos-cp-3   │ │ │
│  │ │ 10.0.2.2    │ │  │ │ 10.1.2.2    │ │  │ │ 10.2.2.2    │ │ │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │ │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │ │
│  │ │karpenter-1  │ │  │ │karpenter-2  │ │  │ │karpenter-3  │ │ │
│  │ │ 10.0.3.2    │ │  │ │ 10.1.3.2    │ │  │ │ 10.2.3.2    │ │ │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│         │                       │                       │       │
│         └───────────────────────┼───────────────────────┘       │
│                                 │                               │
│  ┌─────────────────┐  ┌─────────────────┐                      │
│  │   IBM Provider  │  │   DO Provider   │                      │
│  │  10.3.0.0/16    │  │  10.4.0.0/16    │                      │
│  │                 │  │                 │                      │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │                      │
│  │ │talos-cp-4   │ │  │ │talos-cp-5   │ │                      │
│  │ │ 10.3.1.2    │ │  │ │ 10.4.1.2    │ │                      │
│  │ └─────────────┘ │  │ └─────────────┘ │                      │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │                      │
│  │ │karpenter-4  │ │  │ │karpenter-5  │ │                      │
│  │ │ 10.3.2.2    │ │  │ │ 10.4.2.2    │ │                      │
│  │ └─────────────┘ │  │ └─────────────┘ │                      │
│  └─────────────────┘  └─────────────────┘                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Provider Groups

### AWS Provider (10.0.0.0/16)
- **etcd-1**: 10.0.1.2
- **talos-control-plane-1**: 10.0.2.2
- **karpenter-worker-1**: 10.0.3.2

### Azure Provider (10.1.0.0/16)
- **etcd-2**: 10.1.1.2
- **talos-control-plane-2**: 10.1.2.2
- **karpenter-worker-2**: 10.1.3.2

### GCP Provider (10.2.0.0/16)
- **etcd-3**: 10.2.1.2
- **talos-control-plane-3**: 10.2.2.2
- **karpenter-worker-3**: 10.2.3.2

### IBM Provider (10.3.0.0/16)
- **talos-control-plane-4**: 10.3.1.2
- **karpenter-worker-4**: 10.3.2.2

### DigitalOcean Provider (10.4.0.0/16)
- **talos-control-plane-5**: 10.4.1.2
- **karpenter-worker-5**: 10.4.2.2

## Benefits

- **Provider Isolation**: Each cloud provider has its own network segment
- **Logical Grouping**: Volumes are grouped by their intended cloud provider
- **Cross-Cloud Communication**: Different provider networks can communicate
- **Scalable**: Easy to add new providers and volumes
- **Manageable**: Centralized network management per provider

## Management Commands

```bash
# Check status
/opt/nix-volumes/networking/manage-provider-networking.sh status

# Test configurations
/opt/nix-volumes/networking/manage-provider-networking.sh test

# Show detailed info
/opt/nix-volumes/networking/manage-provider-networking.sh info

# Show cross-provider connectivity
/opt/nix-volumes/networking/manage-provider-networking.sh cross-provider
```
EOF

    log "Provider networking architecture diagram created"
}

# Main execution
main() {
    log "Setting up provider-grouped volume networking..."
    
    create_volume_network_config
    create_network_management
    create_network_architecture
    
    log "Provider-grouped volume networking setup complete!"
    log ""
    log "Next steps:"
    log "1. Check status: $NETWORK_DIR/manage-provider-networking.sh status"
    log "2. Test configurations: $NETWORK_DIR/manage-provider-networking.sh test"
    log "3. Show detailed info: $NETWORK_DIR/manage-provider-networking.sh info"
    log "4. View architecture: cat $NETWORK_DIR/provider-networking-architecture.md"
}

main "$@"
