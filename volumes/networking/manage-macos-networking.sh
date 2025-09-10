#!/bin/bash

# macOS Networking Management Script for Multi-Cloud Kubernetes Volumes
set -euo pipefail

BASE_DIR="/opt/nix-volumes"
NETWORK_DIR="$BASE_DIR/networking"

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script must be run as root for network operations"
        exit 1
    fi
}

usage() {
    echo "Usage: $0 {status|start|stop|test|cleanup|logs}"
    echo ""
    echo "Commands:"
    echo "  status  - Show network status for all volumes"
    echo "  start   - Start all networking components"
    echo "  stop    - Stop all networking components"
    echo "  test    - Test connectivity between volumes"
    echo "  cleanup - Clean up all network components"
    echo "  logs    - Show network logs and statistics"
}

status_networking() {
    echo "macOS Networking Status:"
    echo "======================="
    
    echo -e "\nNetwork Interfaces:"
    ifconfig | grep -E "^[a-z]" | while read line; do
        local interface=$(echo "$line" | cut -d: -f1)
        if [[ "$interface" =~ ^(bridge-|veth-|lo0) ]]; then
            echo "  $interface"
        fi
    done
    
    echo -e "\nBridge Interfaces:"
    for bridge in bridge-aws bridge-azure bridge-gcp bridge-ibm bridge-do bridge-localhost; do
        if ifconfig "$bridge" &>/dev/null; then
            echo "  $bridge"
        fi
    done
    
    echo -e "\nLocalhost Aliases:"
    ifconfig lo0 | grep "inet 127.0.1" | while read line; do
        echo "  $line"
    done
    
    echo -e "\nPF Firewall Status:"
    pfctl -s info | head -5
    
    echo -e "\nNAT Rules:"
    pfctl -s nat | grep -E "10\.[0-9]+\.[0-9]+\.[0-9]+" | while read rule; do
        echo "  $rule"
    done
}

start_networking() {
    echo "Starting macOS networking components..."
    
    # Start bridges
    for bridge in bridge-aws bridge-azure bridge-gcp bridge-ibm bridge-do bridge-localhost; do
        if ifconfig "$bridge" &>/dev/null; then
            ifconfig "$bridge" up
            echo "Started bridge: $bridge"
        fi
    done
    
    # Enable PF firewall
    pfctl -e 2>/dev/null || true
    
    echo "Networking components started"
}

stop_networking() {
    echo "Stopping networking components..."
    
    # Stop bridges
    for bridge in bridge-aws bridge-azure bridge-gcp bridge-ibm bridge-do bridge-localhost; do
        if ifconfig "$bridge" &>/dev/null; then
            ifconfig "$bridge" down
            echo "Stopped bridge: $bridge"
        fi
    done
    
    # Disable PF firewall
    pfctl -d 2>/dev/null || true
    
    echo "Networking components stopped"
}

test_connectivity() {
    echo "Testing connectivity between volumes..."
    
    # Test localhost connectivity
    echo -e "\nTesting localhost connectivity:"
    for volume_dir in "$BASE_DIR"/*/; do
        if [ -d "$volume_dir" ]; then
            local node_name=$(basename "$volume_dir")
            echo "Testing $node_name -> localhost..."
            ping -c 1 127.0.0.1 &>/dev/null && echo "  ✓ localhost reachable" || echo "  ✗ localhost unreachable"
        fi
    done
    
    # Test cross-provider connectivity
    echo -e "\nTesting cross-provider connectivity:"
    local test_ips=("10.0.1.1" "10.1.1.1" "10.2.1.1" "10.3.1.1" "10.4.1.1")
    
    for volume_dir in "$BASE_DIR"/*/; do
        if [ -d "$volume_dir" ]; then
            local node_name=$(basename "$volume_dir")
            echo "Testing $node_name cross-provider connectivity..."
            for test_ip in "${test_ips[@]}"; do
                ping -c 1 "$test_ip" &>/dev/null && echo "  ✓ $test_ip reachable" || echo "  ✗ $test_ip unreachable"
            done
        fi
    done
    
    echo "Connectivity test completed"
}

cleanup_networking() {
    echo "Cleaning up all network components..."
    
    # Remove all bridge interfaces
    for bridge in bridge-aws bridge-azure bridge-gcp bridge-ibm bridge-do bridge-localhost; do
        if ifconfig "$bridge" &>/dev/null; then
            ifconfig "$bridge" destroy
            echo "Removed bridge: $bridge"
        fi
    done
    
    # Remove localhost aliases
    ifconfig lo0 | grep "inet 127.0.1" | while read line; do
        local ip=$(echo "$line" | awk '{print $2}')
        ifconfig lo0 -alias "$ip" 2>/dev/null || true
        echo "Removed localhost alias: $ip"
    done
    
    # Disable PF firewall
    pfctl -d 2>/dev/null || true
    
    # Remove pfctl configuration
    rm -f /etc/pf.conf.volumes
    
    echo "Network cleanup completed"
}

show_logs() {
    echo "Network Logs and Statistics:"
    echo "============================"
    
    echo -e "\nNetwork Interface Statistics:"
    ifconfig | grep -A 10 -E "^[a-z]"
    
    echo -e "\nBridge Statistics:"
    for bridge in bridge-aws bridge-azure bridge-gcp bridge-ibm bridge-do bridge-localhost; do
        if ifconfig "$bridge" &>/dev/null; then
            echo -e "\n$bridge:"
            ifconfig "$bridge"
        fi
    done
    
    echo -e "\nPF Firewall Statistics:"
    pfctl -s info
    pfctl -s nat
}

main() {
    check_root
    
    case "${1:-}" in
        status)
            status_networking
            ;;
        start)
            start_networking
            ;;
        stop)
            stop_networking
            ;;
        test)
            test_connectivity
            ;;
        cleanup)
            cleanup_networking
            ;;
        logs)
            show_logs
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
