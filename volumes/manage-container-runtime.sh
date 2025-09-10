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
