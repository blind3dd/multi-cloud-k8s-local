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
