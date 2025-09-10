#!/bin/bash

# =============================================================================
# Multi-Cloud Kubernetes Local Infrastructure - Master Setup Script
# =============================================================================
# This script orchestrates the complete setup of a multi-cloud Kubernetes
# cluster running locally on macOS using encrypted volumes and Nix package
# management.
#
# Architecture:
# - 3 etcd nodes (Flatcar base)
# - 5 Talos control plane nodes (immutable OS)
# - 5 Karpenter worker nodes (auto-scaling)
# - Cross-cloud networking via proxy and Cilium CNI
# - CAPI (Cluster API) for orchestration
# - External Secrets (Vault), Istio Service Mesh, WireGuard VPN
#
# Author: AI Assistant
# Date: $(date)
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VOLUMES_DIR="${SCRIPT_DIR}/volumes"
LOG_FILE="${SCRIPT_DIR}/setup-main.log"

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗${NC} $1" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "\n${PURPLE}========================================${NC}"
    echo -e "${PURPLE}STEP $1: $2${NC}"
    echo -e "${PURPLE}========================================${NC}"
    log "Starting Step $1: $2"
}

# Check prerequisites
check_prerequisites() {
    log_step "0" "Checking Prerequisites"
    
    # Check if running on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "This script is designed for macOS only"
        exit 1
    fi
    
    # Check for required tools
    local required_tools=("hdiutil" "diskutil" "ifconfig" "pfctl" "python3" "git")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Required tool '$tool' not found. Please install it first."
            exit 1
        fi
    done
    
    # Check for Nix
    if ! command -v nix &> /dev/null; then
        log_warning "Nix not found. Will install it in Step 1."
    else
        log_success "Nix is already installed"
    fi
    
    # Check for Docker (optional for Kind)
    if ! command -v docker &> /dev/null; then
        log_warning "Docker not found. CAPI setup will use simplified approach."
    else
        log_success "Docker is available"
    fi
    
    log_success "Prerequisites check completed"
}

# Step 1: Setup Nix Package Manager
setup_nix() {
    log_step "1" "Setting up Nix Package Manager"
    
    if [[ -f "${SCRIPT_DIR}/setup-nix-complete.sh" ]]; then
        log "Running Nix setup script..."
        chmod +x "${SCRIPT_DIR}/setup-nix-complete.sh"
        "${SCRIPT_DIR}/setup-nix-complete.sh"
        log_success "Nix setup completed"
    else
        log_error "Nix setup script not found: setup-nix-complete.sh"
        exit 1
    fi
}

# Step 2: Create Encrypted Volumes
create_volumes() {
    log_step "2" "Creating Encrypted Volumes for Kubernetes Nodes"
    
    if [[ -f "${SCRIPT_DIR}/create-volumes-simple.sh" ]]; then
        log "Creating encrypted volumes for all Kubernetes nodes..."
        chmod +x "${SCRIPT_DIR}/create-volumes-simple.sh"
        "${SCRIPT_DIR}/create-volumes-simple.sh"
        log_success "Encrypted volumes created successfully"
    else
        log_error "Volume creation script not found: create-volumes-simple.sh"
        exit 1
    fi
}

# Step 3: Configure Volumes with Nix and Kubernetes Tools
configure_volumes() {
    log_step "3" "Configuring Volumes with Nix and Kubernetes Tools"
    
    if [[ -f "${SCRIPT_DIR}/configure-volumes.sh" ]]; then
        log "Configuring all volumes with Nix users and Kubernetes tools..."
        chmod +x "${SCRIPT_DIR}/configure-volumes.sh"
        "${SCRIPT_DIR}/configure-volumes.sh"
        log_success "Volume configuration completed"
    else
        log_error "Volume configuration script not found: configure-volumes.sh"
        exit 1
    fi
}

# Step 4: Setup Container Runtime (containerd, crictl)
setup_container_runtime() {
    log_step "4" "Setting up Container Runtime (containerd, crictl)"
    
    if [[ -f "${SCRIPT_DIR}/setup-container-runtime.sh" ]]; then
        log "Configuring containerd and crictl for all volumes..."
        chmod +x "${SCRIPT_DIR}/setup-container-runtime.sh"
        "${SCRIPT_DIR}/setup-container-runtime.sh"
        log_success "Container runtime setup completed"
    else
        log_error "Container runtime setup script not found: setup-container-runtime.sh"
        exit 1
    fi
}

# Step 5: Setup macOS Networking
setup_macos_networking() {
    log_step "5" "Setting up macOS Networking for Volume Communication"
    
    if [[ -f "${SCRIPT_DIR}/setup-macos-networking.sh" ]]; then
        log "Configuring macOS networking for cross-volume communication..."
        chmod +x "${SCRIPT_DIR}/setup-macos-networking.sh"
        "${SCRIPT_DIR}/setup-macos-networking.sh"
        log_success "macOS networking setup completed"
    else
        log_error "macOS networking setup script not found: setup-macos-networking.sh"
        exit 1
    fi
}

# Step 6: Setup Proxy-based Networking
setup_proxy_networking() {
    log_step "6" "Setting up Proxy-based Networking for Cross-Cloud Simulation"
    
    if [[ -f "${SCRIPT_DIR}/setup-simple-proxy.sh" ]]; then
        log "Setting up proxy networking for cross-cloud communication..."
        chmod +x "${SCRIPT_DIR}/setup-simple-proxy.sh"
        "${SCRIPT_DIR}/setup-simple-proxy.sh"
        log_success "Proxy networking setup completed"
    else
        log_error "Proxy networking setup script not found: setup-simple-proxy.sh"
        exit 1
    fi
}

# Step 7: Setup Cross-Cloud Networking Stack
setup_cross_cloud_networking() {
    log_step "7" "Setting up Cross-Cloud Networking Stack (Cilium, Istio, WireGuard)"
    
    if [[ -f "${SCRIPT_DIR}/setup-cross-cloud-networking.sh" ]]; then
        log "Configuring Cilium CNI, Istio Service Mesh, and WireGuard VPN..."
        chmod +x "${SCRIPT_DIR}/setup-cross-cloud-networking.sh"
        "${SCRIPT_DIR}/setup-cross-cloud-networking.sh"
        log_success "Cross-cloud networking stack setup completed"
    else
        log_error "Cross-cloud networking setup script not found: setup-cross-cloud-networking.sh"
        exit 1
    fi
}

# Step 8: Deploy CAPI (Cluster API)
deploy_capi() {
    log_step "8" "Deploying CAPI (Cluster API) for Multi-Cloud Orchestration"
    
    if [[ -f "${SCRIPT_DIR}/deploy-capi-simple.sh" ]]; then
        log "Deploying CAPI for multi-cloud Kubernetes orchestration..."
        chmod +x "${SCRIPT_DIR}/deploy-capi-simple.sh"
        "${SCRIPT_DIR}/deploy-capi-simple.sh"
        log_success "CAPI deployment completed"
    else
        log_error "CAPI deployment script not found: deploy-capi-simple.sh"
        exit 1
    fi
}

# Step 9: Verify Setup
verify_setup() {
    log_step "9" "Verifying Complete Setup"
    
    log "Checking volume status..."
    if [[ -d "$VOLUMES_DIR" ]]; then
        local volume_count=$(find "$VOLUMES_DIR" -name "*.dmg.sparseimage" | wc -l)
        log_success "Found $volume_count encrypted volumes"
    else
        log_error "Volumes directory not found"
        return 1
    fi
    
    log "Checking networking setup..."
    if [[ -f "${VOLUMES_DIR}/networking/proxy/simple-proxy.py" ]]; then
        log_success "Proxy networking is configured"
    else
        log_warning "Proxy networking not found"
    fi
    
    log "Checking CAPI configuration..."
    if [[ -f "${VOLUMES_DIR}/capi-management/init-capi.sh" ]]; then
        log_success "CAPI configuration is ready"
    else
        log_warning "CAPI configuration not found"
    fi
    
    log "Checking container runtime setup..."
    if [[ -f "${VOLUMES_DIR}/install-container-runtime.sh" ]]; then
        log_success "Container runtime configuration is ready"
    else
        log_warning "Container runtime configuration not found"
    fi
    
    log_success "Setup verification completed"
}

# Step 10: Display Next Steps
display_next_steps() {
    log_step "10" "Setup Complete - Next Steps"
    
    echo -e "\n${GREEN}🎉 Multi-Cloud Kubernetes Local Infrastructure Setup Complete! 🎉${NC}\n"
    
    echo -e "${CYAN}Your infrastructure includes:${NC}"
    echo -e "  • ${YELLOW}3 etcd nodes${NC} (Flatcar base OS)"
    echo -e "  • ${YELLOW}5 Talos control plane nodes${NC} (immutable OS)"
    echo -e "  • ${YELLOW}5 Karpenter worker nodes${NC} (auto-scaling)"
    echo -e "  • ${YELLOW}Cross-cloud networking${NC} (proxy + Cilium CNI)"
    echo -e "  • ${YELLOW}CAPI orchestration${NC} (Cluster API)"
    echo -e "  • ${YELLOW}Security stack${NC} (External Secrets, Istio, WireGuard)"
    
    echo -e "\n${CYAN}Next steps to deploy your clusters:${NC}"
    echo -e "  1. ${YELLOW}Start the proxy server:${NC}"
    echo -e "     ${BLUE}sudo ${VOLUMES_DIR}/networking/proxy/manage-simple-proxy.sh start${NC}"
    
    echo -e "\n  2. ${YELLOW}Initialize CAPI:${NC}"
    echo -e "     ${BLUE}${VOLUMES_DIR}/capi-management/init-capi.sh${NC}"
    
    echo -e "\n  3. ${YELLOW}Deploy your first cluster:${NC}"
    echo -e "     ${BLUE}${VOLUMES_DIR}/capi-management/manage-capi.sh deploy aws${NC}"
    
    echo -e "\n  4. ${YELLOW}Monitor cluster status:${NC}"
    echo -e "     ${BLUE}${VOLUMES_DIR}/manage-cluster.sh status${NC}"
    
    echo -e "\n${CYAN}Management scripts available:${NC}"
    echo -e "  • ${BLUE}${VOLUMES_DIR}/manage-volumes.sh${NC} - Volume management"
    echo -e "  • ${BLUE}${VOLUMES_DIR}/manage-container-runtime.sh${NC} - Container runtime"
    echo -e "  • ${BLUE}${VOLUMES_DIR}/networking/manage-networking.sh${NC} - Networking"
    echo -e "  • ${BLUE}${VOLUMES_DIR}/capi-management/manage-capi.sh${NC} - CAPI management"
    
    echo -e "\n${CYAN}Documentation:${NC}"
    echo -e "  • ${BLUE}${SCRIPT_DIR}/README.md${NC} - Project overview"
    echo -e "  • ${BLUE}${VOLUMES_DIR}/networking/architecture.md${NC} - Networking architecture"
    echo -e "  • ${BLUE}${VOLUMES_DIR}/capi-management/capi-architecture.md${NC} - CAPI architecture"
    
    echo -e "\n${GREEN}Happy Kubernetes clustering! 🚀${NC}\n"
}

# Main execution
main() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    Multi-Cloud Kubernetes Local Infrastructure                ║"
    echo "║                               Main Setup Script                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    log "Starting main setup process..."
    log "Log file: $LOG_FILE"
    
    # Execute all steps
    check_prerequisites
    setup_nix
    create_volumes
    configure_volumes
    setup_container_runtime
    setup_macos_networking
    setup_proxy_networking
    setup_cross_cloud_networking
    deploy_capi
    verify_setup
    display_next_steps
    
    log_success "Main setup completed successfully!"
}

# Run main function
main "$@"
