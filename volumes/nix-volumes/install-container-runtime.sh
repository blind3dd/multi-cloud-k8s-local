#!/bin/bash

# Container Runtime Installation Script for Linux Volumes
# This script should be run inside each volume when it's running Linux

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

install_containerd() {
    log "Installing containerd..."
    
    # Download containerd
    wget -O containerd-2.1.4-linux-amd64.tar.gz https://github.com/containerd/containerd/releases/download/v2.1.4/containerd-2.1.4-linux-amd64.tar.gz
    
    # Extract containerd
    tar -xzf containerd-2.1.4-linux-amd64.tar.gz
    
    # Install containerd
    sudo cp bin/containerd /usr/local/bin/
    sudo cp bin/containerd-shim /usr/local/bin/
    sudo cp bin/containerd-shim-runc-v2 /usr/local/bin/
    sudo cp bin/ctr /usr/local/bin/
    
    # Install systemd service
    sudo cp containerd.service /etc/systemd/system/
    
    # Clean up
    rm -rf bin containerd-2.1.4-linux-amd64.tar.gz
    
    log "Containerd installed"
}

install_runc() {
    log "Installing runc..."
    
    # Download runc
    wget -O runc.amd64 https://github.com/opencontainers/runc/releases/download/v1.3.0/runc.amd64
    
    # Install runc
    sudo cp runc.amd64 /usr/local/bin/runc
    sudo chmod +x /usr/local/bin/runc
    
    # Clean up
    rm runc.amd64
    
    log "Runc installed"
}

install_crictl() {
    log "Installing crictl..."
    
    # Download crictl
    wget -O crictl-v1.32.0-linux-amd64.tar.gz https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.32.0/crictl-v1.32.0-linux-amd64.tar.gz
    
    # Extract crictl
    tar -xzf crictl-v1.32.0-linux-amd64.tar.gz
    
    # Install crictl
    sudo cp crictl /usr/local/bin/
    sudo chmod +x /usr/local/bin/crictl
    
    # Clean up
    rm crictl crictl-v1.32.0-linux-amd64.tar.gz
    
    log "crictl installed"
}

install_cni() {
    log "Installing CNI plugins..."
    
    # Download CNI plugins
    wget -O cni-plugins-linux-amd64-v1.4.1.tgz https://github.com/containernetworking/plugins/releases/download/v1.4.1/cni-plugins-linux-amd64-v1.4.1.tgz
    
    # Create CNI directory
    sudo mkdir -p /opt/cni/bin
    
    # Extract CNI plugins
    sudo tar -xzf cni-plugins-linux-amd64-v1.4.1.tgz -C /opt/cni/bin
    
    # Clean up
    rm cni-plugins-linux-amd64-v1.4.1.tgz
    
    log "CNI plugins installed"
}

main() {
    log "Installing container runtime components..."
    
    install_containerd
    install_runc
    install_crictl
    install_cni
    
    log "Container runtime installation completed"
    log "Next steps:"
    log "1. Start containerd: systemctl start containerd"
    log "2. Test crictl: crictl version"
    log "3. Use container runtime manager: /opt/container-runtime-manager.sh start"
}

main "$@"
