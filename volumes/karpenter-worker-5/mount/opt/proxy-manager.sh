#!/bin/bash

# Simple proxy management script for karpenter-worker-5
set -euo pipefail

VOLUME_NAME="karpenter-worker-5"
PROXY_CONFIG="/etc/proxy/proxy.conf"

# Load proxy configuration
if [ -f "$PROXY_CONFIG" ]; then
    source "$PROXY_CONFIG"
else
    echo "Proxy configuration not found: $PROXY_CONFIG"
    exit 1
fi

test_proxy_connection() {
    echo "Testing proxy connection for $VOLUME_NAME..."
    
    # Test main proxy
    if curl -s "$PROXY_HOST:$PROXY_PORT/status" > /dev/null; then
        echo "✓ Main proxy server reachable"
    else
        echo "✗ Main proxy server not reachable"
    fi
    
    # Test volume endpoint
    if curl -s "$VOLUME_ENDPOINT" > /dev/null; then
        echo "✓ Volume endpoint accessible"
    else
        echo "✗ Volume endpoint not accessible"
    fi
    
    # Test health endpoint
    if curl -s "$HEALTH_ENDPOINT" > /dev/null; then
        echo "✓ Health endpoint responding"
    else
        echo "✗ Health endpoint not responding"
    fi
}

show_proxy_info() {
    echo "Proxy information for $VOLUME_NAME:"
    echo "  Volume: $VOLUME_NAME"
    echo "  Main proxy: $PROXY_HOST:$PROXY_PORT"
    echo "  Volume endpoint: $VOLUME_ENDPOINT"
    echo "  Health endpoint: $HEALTH_ENDPOINT"
    echo "  Status endpoint: $STATUS_ENDPOINT"
}

case "${1:-}" in
    test)
        test_proxy_connection
        ;;
    info)
        show_proxy_info
        ;;
    *)
        echo "Usage: $0 {test|info}"
        exit 1
        ;;
esac
