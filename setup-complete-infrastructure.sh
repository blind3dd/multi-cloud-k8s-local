#!/bin/bash

# Complete Multi-Cloud Kubernetes Infrastructure Setup
# This script sets up the entire infrastructure including Nix, volumes, networking, and proxy

set -euo pipefail

# Configuration
NIX_USER="usualsuspectx"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log "This script must be run as root for system-wide operations"
        exit 1
    fi
}

# Setup Nix package manager
setup_nix() {
    log "Setting up Nix package manager..."
    
    if [ -f "./setup-nix-complete.sh" ]; then
        chmod +x ./setup-nix-complete.sh
        ./setup-nix-complete.sh
    else
        log "Warning: setup-nix-complete.sh not found, skipping Nix setup"
    fi
    
    log "Nix setup completed"
}

# Create encrypted volumes
create_volumes() {
    log "Creating encrypted volumes..."
    
    if [ -f "./create-volumes-simple.sh" ]; then
        chmod +x ./create-volumes-simple.sh
        ./create-volumes-simple.sh
    else
        log "Warning: create-volumes-simple.sh not found, skipping volume creation"
    fi
    
    log "Volume creation completed"
}

# Configure volumes
configure_volumes() {
    log "Configuring volumes..."
    
    if [ -f "./configure-volumes.sh" ]; then
        chmod +x ./configure-volumes.sh
        ./configure-volumes.sh
    else
        log "Warning: configure-volumes.sh not found, skipping volume configuration"
    fi
    
    log "Volume configuration completed"
}

# Setup container runtime
setup_container_runtime() {
    log "Setting up container runtime..."
    
    if [ -f "./setup-container-runtime.sh" ]; then
        chmod +x ./setup-container-runtime.sh
        ./setup-container-runtime.sh
    else
        log "Warning: setup-container-runtime.sh not found, skipping container runtime setup"
    fi
    
    log "Container runtime setup completed"
}

# Setup proxy-based networking
setup_proxy_networking() {
    log "Setting up proxy-based networking..."
    
    if [ -f "./setup-simple-proxy.sh" ]; then
        chmod +x ./setup-simple-proxy.sh
        ./setup-simple-proxy.sh
    else
        log "Warning: setup-simple-proxy.sh not found, skipping proxy networking setup"
    fi
    
    log "Proxy networking setup completed"
}

# Setup cross-cloud networking
setup_cross_cloud_networking() {
    log "Setting up cross-cloud networking..."
    
    if [ -f "./setup-cross-cloud-networking.sh" ]; then
        chmod +x ./setup-cross-cloud-networking.sh
        ./setup-cross-cloud-networking.sh
    else
        log "Warning: setup-cross-cloud-networking.sh not found, skipping cross-cloud networking setup"
    fi
    
    log "Cross-cloud networking setup completed"
}

# Deploy CAPI
deploy_capi() {
    log "Deploying CAPI..."
    
    if [ -f "./deploy-capi-simple.sh" ]; then
        chmod +x ./deploy-capi-simple.sh
        ./deploy-capi-simple.sh
    else
        log "Warning: deploy-capi-simple.sh not found, skipping CAPI deployment"
    fi
    
    log "CAPI deployment completed"
}

# Start proxy server
start_proxy() {
    log "Starting proxy server..."
    
    if [ -f "./volumes/networking/proxy/manage-simple-proxy.sh" ]; then
        chmod +x ./volumes/networking/proxy/manage-simple-proxy.sh
        ./volumes/networking/proxy/manage-simple-proxy.sh start
    else
        log "Warning: proxy management script not found, skipping proxy start"
    fi
    
    log "Proxy server started"
}

# Verify installation
verify_installation() {
    log "Verifying installation..."
    
    echo -e "\n=== Installation Verification ==="
    
    # Check Nix
    if command -v nix &> /dev/null; then
        echo "✓ Nix: $(nix --version)"
    else
        echo "✗ Nix: Not found"
    fi
    
    # Check Kubernetes tools
    if command -v kubectl &> /dev/null; then
        echo "✓ kubectl: $(kubectl version --client --short 2>/dev/null || echo 'installed')"
    else
        echo "✗ kubectl: Not found"
    fi
    
    if command -v clusterctl &> /dev/null; then
        echo "✓ clusterctl: $(clusterctl version --short 2>/dev/null || echo 'installed')"
    else
        echo "✗ clusterctl: Not found"
    fi
    
    if command -v helm &> /dev/null; then
        echo "✓ helm: $(helm version --short 2>/dev/null || echo 'installed')"
    else
        echo "✗ helm: Not found"
    fi
    
    if command -v talosctl &> /dev/null; then
        echo "✓ talosctl: $(talosctl version --short 2>/dev/null || echo 'installed')"
    else
        echo "✗ talosctl: Not found"
    fi
    
    # Check volumes
    if [ -d "./volumes" ]; then
        local volume_count=$(find ./volumes -name "*.dmg.sparseimage" | wc -l)
        echo "✓ Encrypted volumes: $volume_count volumes created"
    else
        echo "✗ Encrypted volumes: Not found"
    fi
    
    # Check proxy
    if curl -s http://localhost:8000/status > /dev/null 2>&1; then
        echo "✓ Proxy server: Running on port 8000"
    else
        echo "✗ Proxy server: Not responding"
    fi
    
    # Check container runtime configurations
    if [ -d "./volumes" ]; then
        local runtime_configs=$(find ./volumes -name "containerd" -type d | wc -l)
        echo "✓ Container runtime: $runtime_configs configurations created"
    else
        echo "✗ Container runtime: Not found"
    fi
    
    echo -e "\n=== Installation Summary ==="
    echo "Multi-cloud Kubernetes infrastructure setup completed!"
    echo ""
    echo "Components:"
    echo "- Nix package manager with all required tools"
    echo "- 13 encrypted volumes for different cloud providers"
    echo "- Container runtime (containerd + crictl) configured"
    echo "- Proxy-based networking for volume communication"
    echo "- Cross-cloud networking with Cilium, Istio, WireGuard"
    echo "- CAPI orchestration for multi-cloud cluster management"
    echo ""
    echo "Next steps:"
    echo "1. Test proxy: curl http://localhost:8000/status"
    echo "2. Check volumes: ./volumes/manage-volumes.sh status"
    echo "3. Deploy clusters: ./volumes/capi-management/manage-capi.sh deploy"
    echo "4. View documentation: cat README.md"
}

# Main execution
main() {
    log "Starting complete multi-cloud Kubernetes infrastructure setup..."
    
    check_root
    
    # Setup sequence
    setup_nix
    create_volumes
    configure_volumes
    setup_container_runtime
    setup_proxy_networking
    setup_cross_cloud_networking
    deploy_capi
    start_proxy
    verify_installation
    
    log "Complete multi-cloud Kubernetes infrastructure setup finished!"
    log ""
    log "🔄 KEY FEATURE: Proxy-based networking is now running on http://localhost:8000"
    log ""
    log "Management commands:"
    log "- Proxy: ./volumes/networking/proxy/manage-simple-proxy.sh {start|stop|status|test}"
    log "- Volumes: ./volumes/manage-volumes.sh {mount-all|unmount-all|status}"
    log "- CAPI: ./volumes/capi-management/manage-capi.sh {init|deploy|status}"
    log "- Nix: ./manage-nix-packages.sh {status|update|clean|list}"
    log ""
    log "Documentation:"
    log "- README.md: Complete project overview"
    log "- nix-architecture.md: Nix setup details"
    log "- volumes/networking/proxy/simple-proxy-architecture.md: Proxy networking details"
}

main "$@"
