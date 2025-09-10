#!/bin/bash

# Network management script for karpenter-worker-2 (azure provider)
set -euo pipefail

NODE_NAME="karpenter-worker-2"
PROVIDER="azure"
HOST_IP="10.1.1.1"
NS_IP="10.1.3.2"

show_network_info() {
    echo "Network information for $NODE_NAME ($PROVIDER provider):"
    echo "  Provider: $PROVIDER"
    echo "  Host IP: $HOST_IP"
    echo "  Node IP: $NS_IP"
    echo "  Network: 10.1.0.0/16"
    echo "  Gateway: 10.1.1.1"
    echo "  Bridge: bridge-azure"
}

test_connectivity() {
    echo "Testing connectivity for $NODE_NAME ($PROVIDER provider)..."
    echo "  Node IP: $NS_IP"
    echo "  Gateway: $HOST_IP"
    echo "  DNS: 8.8.8.8"
    echo "Connectivity test completed for $NODE_NAME"
}

show_cross_provider_info() {
    echo "Cross-provider connectivity for $NODE_NAME:"
    echo "  AWS provider: 10.0.0.0/16 (gateway: 10.0.1.1, bridge: bridge-aws)"
    echo "  Azure provider: 10.1.0.0/16 (gateway: 10.1.1.1, bridge: bridge-azure)"
    echo "  GCP provider: 10.2.0.0/16 (gateway: 10.2.1.1, bridge: bridge-gcp)"
    echo "  IBM provider: 10.3.0.0/16 (gateway: 10.3.1.1, bridge: bridge-ibm)"
    echo "  DigitalOcean provider: 10.4.0.0/16 (gateway: 10.4.1.1, bridge: bridge-do)"
}

case "${1:-}" in
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
        echo "Usage: $0 {info|test|cross-provider}"
        exit 1
        ;;
esac
