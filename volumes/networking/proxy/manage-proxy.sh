#!/bin/bash

# Proxy Management Script for Multi-Cloud Kubernetes Volumes
set -euo pipefail

PROXY_DIR="/opt/nix-volumes/networking/proxy"
PID_DIR="$PROXY_DIR/pids"

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script must be run as root for network operations"
        exit 1
    fi
}

usage() {
    echo "Usage: $0 {start|stop|status|restart|logs|test}"
    echo ""
    echo "Commands:"
    echo "  start   - Start all proxy servers"
    echo "  stop    - Stop all proxy servers"
    echo "  status  - Show proxy server status"
    echo "  restart - Restart all proxy servers"
    echo "  logs    - Show proxy server logs"
    echo "  test    - Test proxy connectivity"
}

start_proxy_servers() {
    echo "Starting proxy servers..."
    
    mkdir -p "$PID_DIR"
    
    # Start main proxy server
    echo "Starting main proxy server on port 8000..."
    python3 "$PROXY_DIR/proxy-server.py" 8000 > "$PROXY_DIR/main-proxy.log" 2>&1 &
    echo $! > "$PID_DIR/main-proxy.pid"
    
    # Start provider-specific proxy servers
    for provider in aws azure gcp ibm digitalocean; do
        if [ -f "$PROXY_DIR/${provider}-proxy-server.py" ]; then
            echo "Starting ${provider} proxy server..."
            python3 "$PROXY_DIR/${provider}-proxy-server.py" > "$PROXY_DIR/${provider}-proxy.log" 2>&1 &
            echo $! > "$PID_DIR/${provider}-proxy.pid"
        fi
    done
    
    sleep 2
    echo "Proxy servers started"
}

stop_proxy_servers() {
    echo "Stopping proxy servers..."
    
    # Stop all proxy servers
    for pid_file in "$PID_DIR"/*.pid; do
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            local service=$(basename "$pid_file" .pid)
            
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid"
                echo "Stopped $service (PID: $pid)"
            else
                echo "$service was not running"
            fi
            
            rm -f "$pid_file"
        fi
    done
    
    echo "Proxy servers stopped"
}

status_proxy_servers() {
    echo "Proxy Server Status:"
    echo "==================="
    
    # Check main proxy server
    if [ -f "$PID_DIR/main-proxy.pid" ]; then
        local pid=$(cat "$PID_DIR/main-proxy.pid")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Main proxy server: RUNNING (PID: $pid, Port: 8000)"
        else
            echo "Main proxy server: STOPPED"
        fi
    else
        echo "Main proxy server: STOPPED"
    fi
    
    # Check provider proxy servers
    for provider in aws azure gcp ibm digitalocean; do
        if [ -f "$PID_DIR/${provider}-proxy.pid" ]; then
            local pid=$(cat "$PID_DIR/${provider}-proxy.pid")
            if kill -0 "$pid" 2>/dev/null; then
                local port=$(grep "base_port" "$PROXY_DIR/${provider}-proxy.conf" | cut -d= -f2)
                echo "${provider} proxy server: RUNNING (PID: $pid, Port: $port)"
            else
                echo "${provider} proxy server: STOPPED"
            fi
        else
            echo "${provider} proxy server: STOPPED"
        fi
    done
    
    echo ""
    echo "Port Mappings:"
    echo "Main proxy: http://localhost:8000"
    echo "AWS proxy: http://localhost:8080"
    echo "Azure proxy: http://localhost:8081"
    echo "GCP proxy: http://localhost:8082"
    echo "IBM proxy: http://localhost:8083"
    echo "DigitalOcean proxy: http://localhost:8084"
}

restart_proxy_servers() {
    echo "Restarting proxy servers..."
    stop_proxy_servers
    sleep 2
    start_proxy_servers
}

show_logs() {
    echo "Proxy Server Logs:"
    echo "=================="
    
    for log_file in "$PROXY_DIR"/*.log; do
        if [ -f "$log_file" ]; then
            local service=$(basename "$log_file" .log)
            echo -e "\n--- $service ---"
            tail -20 "$log_file"
        fi
    done
}

test_proxy_connectivity() {
    echo "Testing proxy connectivity..."
    
    # Test main proxy server
    echo -e "\nTesting main proxy server..."
    if curl -s http://localhost:8000/status > /dev/null; then
        echo "✓ Main proxy server responding"
    else
        echo "✗ Main proxy server not responding"
    fi
    
    # Test provider proxy servers
    for provider in aws azure gcp ibm digitalocean; do
        local port=$(grep "base_port" "$PROXY_DIR/${provider}-proxy.conf" 2>/dev/null | cut -d= -f2)
        if [ -n "$port" ]; then
            echo -e "\nTesting ${provider} proxy server (port $port)..."
            if curl -s http://localhost:$port/status > /dev/null; then
                echo "✓ ${provider} proxy server responding"
            else
                echo "✗ ${provider} proxy server not responding"
            fi
        fi
    done
    
    # Test volume-specific endpoints
    echo -e "\nTesting volume endpoints..."
    for volume in etcd-1 etcd-2 etcd-3 talos-control-plane-1 talos-control-plane-2; do
        if curl -s http://localhost:8000/volume/$volume > /dev/null; then
            echo "✓ Volume $volume accessible"
        else
            echo "✗ Volume $volume not accessible"
        fi
    done
    
    echo "Proxy connectivity test completed"
}

main() {
    check_root
    
    case "${1:-}" in
        start)
            start_proxy_servers
            ;;
        stop)
            stop_proxy_servers
            ;;
        status)
            status_proxy_servers
            ;;
        restart)
            restart_proxy_servers
            ;;
        logs)
            show_logs
            ;;
        test)
            test_proxy_connectivity
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
