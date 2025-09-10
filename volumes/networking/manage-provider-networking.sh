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
