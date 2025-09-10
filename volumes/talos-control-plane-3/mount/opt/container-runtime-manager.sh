#!/bin/bash

# Container Runtime Management Script for talos-control-plane-3
set -euo pipefail

NODE_NAME="talos-control-plane-3"

start_containerd() {
    echo "Starting containerd for $NODE_NAME..."
    systemctl daemon-reload
    systemctl enable containerd
    systemctl start containerd
    echo "Containerd started for $NODE_NAME"
}

stop_containerd() {
    echo "Stopping containerd for $NODE_NAME..."
    systemctl stop containerd
    echo "Containerd stopped for $NODE_NAME"
}

status_containerd() {
    echo "Containerd status for $NODE_NAME:"
    systemctl status containerd --no-pager
}

test_crictl() {
    echo "Testing crictl for $NODE_NAME..."
    crictl version
    crictl info
    echo "crictl test completed for $NODE_NAME"
}

list_containers() {
    echo "Listing containers for $NODE_NAME:"
    crictl ps -a
}

list_images() {
    echo "Listing images for $NODE_NAME:"
    crictl images
}

pull_test_image() {
    echo "Pulling test image for $NODE_NAME..."
    crictl pull registry.k8s.io/pause:3.9
    echo "Test image pulled for $NODE_NAME"
}

case "${1:-}" in
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
        echo "Usage: $0 {start|stop|status|test|list-containers|list-images|pull-test}"
        exit 1
        ;;
esac
