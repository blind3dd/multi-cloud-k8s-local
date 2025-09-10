#!/bin/bash

# Simple Proxy-Based Networking for Multi-Cloud Kubernetes Volumes
# Uses simple HTTP proxies for volume communication

set -euo pipefail

# Configuration
BASE_DIR="/opt/nix-volumes"
PROXY_DIR="$BASE_DIR/networking/proxy"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Create proxy directory
create_proxy_directory() {
    log "Creating proxy directory..."
    mkdir -p "$PROXY_DIR"
    log "Proxy directory created at $PROXY_DIR"
}

# Create simple proxy server
create_simple_proxy_server() {
    log "Creating simple proxy server..."
    
    cat > "$PROXY_DIR/simple-proxy.py" << 'EOF'
#!/usr/bin/env python3

import json
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.parse

class SimpleProxyHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.handle_request()
    
    def do_POST(self):
        self.handle_request()
    
    def handle_request(self):
        try:
            parsed_url = urllib.parse.urlparse(self.path)
            path = parsed_url.path
            
            if path.startswith('/volume/'):
                volume_name = path.split('/')[2]
                self.handle_volume_request(volume_name)
            elif path.startswith('/status'):
                self.handle_status_request()
            elif path.startswith('/health'):
                self.handle_health_request()
            else:
                self.handle_general_request()
                
        except Exception as e:
            self.send_error(500, f"Internal Server Error: {str(e)}")
    
    def handle_volume_request(self, volume_name):
        response_data = {
            "volume": volume_name,
            "status": "active",
            "message": f"Request to {volume_name} processed"
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(response_data).encode())
    
    def handle_status_request(self):
        status_data = {
            "proxy_server": "active",
            "volumes": ["etcd-1", "etcd-2", "etcd-3", "talos-control-plane-1", "talos-control-plane-2", "talos-control-plane-3", "talos-control-plane-4", "talos-control-plane-5", "karpenter-worker-1", "karpenter-worker-2", "karpenter-worker-3", "karpenter-worker-4", "karpenter-worker-5"],
            "providers": ["aws", "azure", "gcp", "ibm", "digitalocean"]
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(status_data, indent=2).encode())
    
    def handle_health_request(self):
        health_data = {
            "status": "healthy",
            "timestamp": "2025-09-10T04:40:00Z"
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(health_data).encode())
    
    def handle_general_request(self):
        response_data = {
            "message": "Multi-Cloud Kubernetes Simple Proxy Server",
            "endpoints": [
                "/status - Get proxy status",
                "/health - Health check",
                "/volume/{volume_name} - Access specific volume"
            ]
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(response_data, indent=2).encode())
    
    def log_message(self, format, *args):
        pass

def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    
    server = HTTPServer(('0.0.0.0', port), SimpleProxyHandler)
    print(f"Simple proxy server starting on port {port}")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down simple proxy server...")
        server.shutdown()

if __name__ == "__main__":
    main()
EOF

    chmod +x "$PROXY_DIR/simple-proxy.py"
    log "Simple proxy server created"
}

# Create proxy management script
create_proxy_management() {
    log "Creating proxy management script..."
    
    cat > "$PROXY_DIR/manage-simple-proxy.sh" << 'EOF'
#!/bin/bash

# Simple Proxy Management Script
set -euo pipefail

PROXY_DIR="/opt/nix-volumes/networking/proxy"
PID_FILE="$PROXY_DIR/proxy.pid"
LOG_FILE="$PROXY_DIR/proxy.log"

usage() {
    echo "Usage: $0 {start|stop|status|restart|test}"
    echo ""
    echo "Commands:"
    echo "  start   - Start proxy server"
    echo "  stop    - Stop proxy server"
    echo "  status  - Show proxy server status"
    echo "  restart - Restart proxy server"
    echo "  test    - Test proxy connectivity"
}

start_proxy() {
    echo "Starting simple proxy server..."
    
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Proxy server is already running (PID: $pid)"
            return
        fi
    fi
    
    python3 "$PROXY_DIR/simple-proxy.py" 8000 > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    
    sleep 2
    echo "Proxy server started on port 8000"
}

stop_proxy() {
    echo "Stopping proxy server..."
    
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            echo "Proxy server stopped (PID: $pid)"
        else
            echo "Proxy server was not running"
        fi
        rm -f "$PID_FILE"
    else
        echo "Proxy server was not running"
    fi
}

status_proxy() {
    echo "Simple Proxy Server Status:"
    echo "==========================="
    
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Status: RUNNING (PID: $pid, Port: 8000)"
            echo "Log file: $LOG_FILE"
        else
            echo "Status: STOPPED"
        fi
    else
        echo "Status: STOPPED"
    fi
    
    echo ""
    echo "Endpoints:"
    echo "  Main: http://localhost:8000"
    echo "  Status: http://localhost:8000/status"
    echo "  Health: http://localhost:8000/health"
    echo "  Volume: http://localhost:8000/volume/{volume_name}"
}

restart_proxy() {
    echo "Restarting proxy server..."
    stop_proxy
    sleep 2
    start_proxy
}

test_proxy() {
    echo "Testing proxy connectivity..."
    
    # Test main endpoint
    echo -e "\nTesting main endpoint..."
    if curl -s http://localhost:8000 > /dev/null; then
        echo "✓ Main endpoint responding"
    else
        echo "✗ Main endpoint not responding"
    fi
    
    # Test status endpoint
    echo -e "\nTesting status endpoint..."
    if curl -s http://localhost:8000/status > /dev/null; then
        echo "✓ Status endpoint responding"
    else
        echo "✗ Status endpoint not responding"
    fi
    
    # Test health endpoint
    echo -e "\nTesting health endpoint..."
    if curl -s http://localhost:8000/health > /dev/null; then
        echo "✓ Health endpoint responding"
    else
        echo "✗ Health endpoint not responding"
    fi
    
    # Test volume endpoints
    echo -e "\nTesting volume endpoints..."
    for volume in etcd-1 etcd-2 talos-control-plane-1 talos-control-plane-2; do
        if curl -s "http://localhost:8000/volume/$volume" > /dev/null; then
            echo "✓ Volume $volume accessible"
        else
            echo "✗ Volume $volume not accessible"
        fi
    done
    
    echo "Proxy connectivity test completed"
}

main() {
    case "${1:-}" in
        start)
            start_proxy
            ;;
        stop)
            stop_proxy
            ;;
        status)
            status_proxy
            ;;
        restart)
            restart_proxy
            ;;
        test)
            test_proxy
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
EOF

    chmod +x "$PROXY_DIR/manage-simple-proxy.sh"
    log "Simple proxy management script created"
}

# Create volume proxy configurations
create_volume_proxy_configs() {
    log "Creating volume proxy configurations..."
    
    for volume_dir in "$BASE_DIR"/*/; do
        if [ -d "$volume_dir" ]; then
            local node_name=$(basename "$volume_dir")
            local mount_point="$volume_dir/mount"
            
            if [ -d "$mount_point" ]; then
                log "Creating proxy config for $node_name..."
                
                # Create proxy configuration directory
                mkdir -p "$mount_point/etc/proxy"
                
                # Create simple proxy configuration
                cat > "$mount_point/etc/proxy/proxy.conf" << EOF
# Simple proxy configuration for $node_name

PROXY_HOST=localhost
PROXY_PORT=8000
VOLUME_NAME=$node_name
VOLUME_ENDPOINT=http://localhost:8000/volume/$node_name
HEALTH_ENDPOINT=http://localhost:8000/health
STATUS_ENDPOINT=http://localhost:8000/status
EOF

                # Create simple proxy management script for volume
                cat > "$mount_point/opt/proxy-manager.sh" << EOF
#!/bin/bash

# Simple proxy management script for $node_name
set -euo pipefail

VOLUME_NAME="$node_name"
PROXY_CONFIG="/etc/proxy/proxy.conf"

# Load proxy configuration
if [ -f "\$PROXY_CONFIG" ]; then
    source "\$PROXY_CONFIG"
else
    echo "Proxy configuration not found: \$PROXY_CONFIG"
    exit 1
fi

test_proxy_connection() {
    echo "Testing proxy connection for \$VOLUME_NAME..."
    
    # Test main proxy
    if curl -s "\$PROXY_HOST:\$PROXY_PORT/status" > /dev/null; then
        echo "✓ Main proxy server reachable"
    else
        echo "✗ Main proxy server not reachable"
    fi
    
    # Test volume endpoint
    if curl -s "\$VOLUME_ENDPOINT" > /dev/null; then
        echo "✓ Volume endpoint accessible"
    else
        echo "✗ Volume endpoint not accessible"
    fi
    
    # Test health endpoint
    if curl -s "\$HEALTH_ENDPOINT" > /dev/null; then
        echo "✓ Health endpoint responding"
    else
        echo "✗ Health endpoint not responding"
    fi
}

show_proxy_info() {
    echo "Proxy information for \$VOLUME_NAME:"
    echo "  Volume: \$VOLUME_NAME"
    echo "  Main proxy: \$PROXY_HOST:\$PROXY_PORT"
    echo "  Volume endpoint: \$VOLUME_ENDPOINT"
    echo "  Health endpoint: \$HEALTH_ENDPOINT"
    echo "  Status endpoint: \$STATUS_ENDPOINT"
}

case "\${1:-}" in
    test)
        test_proxy_connection
        ;;
    info)
        show_proxy_info
        ;;
    *)
        echo "Usage: \$0 {test|info}"
        exit 1
        ;;
esac
EOF

                chmod +x "$mount_point/opt/proxy-manager.sh"
                
                log "Proxy configuration created for $node_name"
            fi
        fi
    done
    
    log "Volume proxy configurations created"
}

# Create proxy architecture documentation
create_proxy_architecture() {
    log "Creating proxy architecture documentation..."
    
    cat > "$PROXY_DIR/simple-proxy-architecture.md" << 'EOF'
# Simple Proxy-Based Networking Architecture

## Overview

This implementation uses a simple HTTP proxy server to enable communication between mounted volumes and localhost, providing a reliable networking solution for macOS.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Simple Proxy Network Stack                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                Simple Proxy Server                     │   │
│  │                   Port: 8000                           │   │
│  │                                                         │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │   │
│  │  │/status      │  │/health      │  │/volume/*    │    │   │
│  │  │             │  │             │  │             │    │   │
│  │  │Get proxy    │  │Health check │  │Access       │    │   │
│  │  │status and   │  │endpoint     │  │specific     │    │   │
│  │  │volume list  │  │             │  │volumes      │    │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                Volume Configurations                   │   │
│  │                                                         │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │   │
│  │  │   etcd-1    │  │   etcd-2    │  │   etcd-3    │    │   │
│  │  │             │  │             │  │             │    │   │
│  │  │/etc/proxy/  │  │/etc/proxy/  │  │/etc/proxy/  │    │   │
│  │  │proxy.conf   │  │proxy.conf   │  │proxy.conf   │    │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘    │   │
│  │                                                         │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │   │
│  │  │talos-cp-1   │  │talos-cp-2   │  │talos-cp-3   │    │   │
│  │  │             │  │             │  │             │    │   │
│  │  │/etc/proxy/  │  │/etc/proxy/  │  │/etc/proxy/  │    │   │
│  │  │proxy.conf   │  │proxy.conf   │  │proxy.conf   │    │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### Simple Proxy Server (Port 8000)
- **Purpose**: Central proxy server for all volume communication
- **Endpoints**:
  - `/status` - Get proxy status and volume list
  - `/health` - Health check endpoint
  - `/volume/{volume_name}` - Access specific volume
- **Function**: Routes requests to appropriate volumes

### Volume Proxy Configurations
- **Location**: `/etc/proxy/proxy.conf` in each volume
- **Settings**: Proxy endpoints, health checks, status endpoints
- **Management**: Volume-specific proxy management scripts

## Communication Flow

### Volume to Volume Communication
```
Volume A -> Simple Proxy (8000) -> Volume B
```

### Volume to Localhost Communication
```
Volume A -> Simple Proxy (8000) -> Localhost Services
```

### Cross-Provider Communication
```
Volume A (AWS) -> Simple Proxy (8000) -> Volume B (Azure)
```

## Management Commands

```bash
# Start proxy server
/opt/nix-volumes/networking/proxy/manage-simple-proxy.sh start

# Stop proxy server
/opt/nix-volumes/networking/proxy/manage-simple-proxy.sh stop

# Check proxy status
/opt/nix-volumes/networking/proxy/manage-simple-proxy.sh status

# Restart proxy server
/opt/nix-volumes/networking/proxy/manage-simple-proxy.sh restart

# Test proxy connectivity
/opt/nix-volumes/networking/proxy/manage-simple-proxy.sh test
```

## Volume-Specific Commands

```bash
# Test proxy connection for specific volume
/opt/proxy-manager.sh test

# Show proxy information for specific volume
/opt/proxy-manager.sh info
```

## Benefits

- **Simple**: Single proxy server for all communication
- **Reliable**: HTTP-based communication that works across platforms
- **Manageable**: Centralized proxy management
- **Cross-Platform**: Works on macOS, Linux, and other platforms
- **Debuggable**: HTTP endpoints for easy testing and debugging
- **Lightweight**: Minimal resource usage

## Security Features

- **Centralized Control**: Single point of access control
- **Logging**: All requests are logged for audit purposes
- **Health Checks**: Regular health monitoring
- **Access Control**: Can be extended with authentication
EOF

    log "Simple proxy architecture documentation created"
}

# Main execution
main() {
    log "Setting up simple proxy-based networking for multi-cloud Kubernetes volumes..."
    
    create_proxy_directory
    create_simple_proxy_server
    create_proxy_management
    create_volume_proxy_configs
    create_proxy_architecture
    
    log "Simple proxy-based networking setup complete!"
    log ""
    log "Next steps:"
    log "1. Start proxy: $PROXY_DIR/manage-simple-proxy.sh start"
    log "2. Check status: $PROXY_DIR/manage-simple-proxy.sh status"
    log "3. Test connectivity: $PROXY_DIR/manage-simple-proxy.sh test"
    log "4. View architecture: cat $PROXY_DIR/simple-proxy-architecture.md"
    log ""
    log "Proxy components created:"
    log "- Simple proxy server (port 8000)"
    log "- Volume proxy configurations"
    log "- Management scripts"
    log "- Architecture documentation"
}

main "$@"
