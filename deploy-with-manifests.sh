#!/bin/bash

# Multi-Cloud Kubernetes Deployment with Manifests
# This script deploys the complete multi-cloud Kubernetes infrastructure using generated manifests

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VOLUMES_DIR="${SCRIPT_DIR}/volumes"
CAPI_TEMPLATES_DIR="/opt/nix-volumes/capi-templates"
CERTS_DIR="/opt/nix-volumes/certificates"
KUBECONFIG_DIR="/opt/nix-volumes/kubeconfigs"
LOG_FILE="${SCRIPT_DIR}/deploy-manifests.log"

# Clusters to deploy
CLUSTERS="aws azure gcp ibm digitalocean talos"

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}✗${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1" | tee -a "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if certificates exist
    if [ ! -d "$CERTS_DIR" ]; then
        log_error "Certificates directory not found: $CERTS_DIR"
        log "Please run setup-kubeconfig.sh first"
        exit 1
    fi
    
    # Check if CAPI templates exist
    if [ ! -d "$CAPI_TEMPLATES_DIR" ]; then
        log_error "CAPI templates directory not found: $CAPI_TEMPLATES_DIR"
        log "Please run setup-kubeconfig.sh first"
        exit 1
    fi
    
    # Check if kubeconfigs exist
    if [ ! -d "$KUBECONFIG_DIR" ]; then
        log_error "Kubeconfig directory not found: $KUBECONFIG_DIR"
        log "Please run setup-kubeconfig.sh first"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Create deployment namespace
create_namespace() {
    log "Creating deployment namespace..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: multi-cloud-k8s
  labels:
    name: multi-cloud-k8s
    purpose: multi-cloud-kubernetes-deployment
EOF
    
    log_success "Namespace created"
}

# Deploy cluster manifests
deploy_cluster_manifests() {
    local cluster="$1"
    log "Deploying manifests for $cluster cluster..."
    
    local cluster_dir="$CAPI_TEMPLATES_DIR/$cluster"
    
    if [ ! -d "$cluster_dir" ]; then
        log_error "Cluster directory not found: $cluster_dir"
        return 1
    fi
    
    # Apply cluster manifest
    if [ -f "$cluster_dir/cluster.yaml" ]; then
        log "Applying cluster manifest for $cluster..."
        kubectl apply -f "$cluster_dir/cluster.yaml" -n multi-cloud-k8s --v=7
        log_success "Cluster manifest applied for $cluster"
    fi
    
    # Apply control plane machine manifest
    if [ -f "$cluster_dir/control-plane-machine.yaml" ]; then
        log "Applying control plane machine manifest for $cluster..."
        kubectl apply -f "$cluster_dir/control-plane-machine.yaml" -n multi-cloud-k8s --v=7
        log_success "Control plane machine manifest applied for $cluster"
    fi
    
    # Apply worker machine manifest
    if [ -f "$cluster_dir/worker-machine.yaml" ]; then
        log "Applying worker machine manifest for $cluster..."
        kubectl apply -f "$cluster_dir/worker-machine.yaml" -n multi-cloud-k8s --v=7
        log_success "Worker machine manifest applied for $cluster"
    fi
}

# Deploy all clusters
deploy_all_clusters() {
    log "Deploying all multi-cloud clusters..."
    
    for cluster in $CLUSTERS; do
        deploy_cluster_manifests "$cluster"
    done
    
    log_success "All cluster manifests deployed"
}

# Deploy networking components
deploy_networking() {
    log "Deploying cross-cloud networking components..."
    
    # Deploy Cilium CNI
    log "Deploying Cilium CNI..."
    kubectl create namespace cilium-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy Istio Service Mesh
    log "Deploying Istio Service Mesh..."
    kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy WireGuard VPN
    log "Deploying WireGuard VPN mesh..."
    kubectl create namespace wireguard-system --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Networking components deployed"
}

# Deploy security components
deploy_security() {
    log "Deploying security components..."
    
    # Deploy External Secrets Operator
    log "Deploying External Secrets Operator..."
    kubectl create namespace external-secrets-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy Vault
    log "Deploying Vault..."
    kubectl create namespace vault-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy custom security operator
    log "Deploying custom security operator..."
    kubectl create namespace security-operator-system --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Security components deployed"
}

# Deploy monitoring and observability
deploy_monitoring() {
    log "Deploying monitoring and observability..."
    
    # Deploy Prometheus
    log "Deploying Prometheus..."
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy Grafana
    log "Deploying Grafana..."
    kubectl create namespace grafana --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy Jaeger
    log "Deploying Jaeger..."
    kubectl create namespace jaeger --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Monitoring components deployed"
}

# Check deployment status
check_deployment_status() {
    log "Checking deployment status..."
    
    echo -e "\n${PURPLE}=== Multi-Cloud Kubernetes Deployment Status ===${NC}"
    
    # Check namespaces
    echo -e "\n${YELLOW}Namespaces:${NC}"
    kubectl get namespaces | grep -E "(multi-cloud|cilium|istio|wireguard|external-secrets|vault|security-operator|monitoring|grafana|jaeger)"
    
    # Check clusters
    echo -e "\n${YELLOW}Clusters:${NC}"
    kubectl get clusters -n multi-cloud-k8s 2>/dev/null || echo "No clusters found yet"
    
    # Check machines
    echo -e "\n${YELLOW}Machines:${NC}"
    kubectl get machines -n multi-cloud-k8s 2>/dev/null || echo "No machines found yet"
    
    # Check pods
    echo -e "\n${YELLOW}Pods:${NC}"
    kubectl get pods --all-namespaces | grep -E "(cilium|istio|wireguard|external-secrets|vault|security-operator|monitoring|grafana|jaeger)" || echo "No pods found yet"
    
    log_success "Deployment status checked"
}

# Main deployment function
main() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    Multi-Cloud Kubernetes Deployment                        ║"
    echo "║                           Using Manifests                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    log "Starting multi-cloud Kubernetes deployment with manifests..."
    log "Log file: $LOG_FILE"
    
    check_prerequisites
    create_namespace
    deploy_all_clusters
    deploy_networking
    deploy_security
    deploy_monitoring
    check_deployment_status
    
    echo -e "\n${GREEN}🎉 Multi-Cloud Kubernetes Deployment Complete! 🎉${NC}"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Monitor cluster creation:"
    echo "   kubectl get clusters -n multi-cloud-k8s -w"
    echo ""
    echo "2. Check machine status:"
    echo "   kubectl get machines -n multi-cloud-k8s -w"
    echo ""
    echo "3. Monitor pods:"
    echo "   kubectl get pods --all-namespaces -w"
    echo ""
    echo "4. Access cluster kubeconfigs:"
    echo "   source $KUBECONFIG_DIR/setup-kubeconfig-env.sh"
    echo "   switch_cluster aws"
    echo ""
    echo -e "${BLUE}All manifests have been applied successfully!${NC}"
}

# Run main function
main "$@"
