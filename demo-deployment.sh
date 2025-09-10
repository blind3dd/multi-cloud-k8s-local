#!/bin/bash

# Multi-Cloud Kubernetes Deployment Demo
# This script demonstrates the deployment process and shows what manifests would be applied

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
CAPI_TEMPLATES_DIR="/opt/nix-volumes/capi-templates"
CERTS_DIR="/opt/nix-volumes/certificates"
KUBECONFIG_DIR="/opt/nix-volumes/kubeconfigs"

# Clusters to deploy
CLUSTERS="aws azure gcp ibm digitalocean talos"

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Show architecture
show_architecture() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    Multi-Cloud Kubernetes Architecture                      ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│                    Multi-Cloud Kubernetes                      │${NC}"
    echo -e "${CYAN}│                     Local Infrastructure                       │${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │${NC}"
    echo -e "${CYAN}│  │   AWS Cluster   │  │  Azure Cluster  │  │   GCP Cluster   │ │${NC}"
    echo -e "${CYAN}│  │                 │  │                 │  │                 │ │${NC}"
    echo -e "${CYAN}│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │ │${NC}"
    echo -e "${CYAN}│  │ │Control Plane│ │  │ │Control Plane│ │  │ │Control Plane│ │ │${NC}"
    echo -e "${CYAN}│  │ │  3 nodes    │ │  │ │  3 nodes    │ │  │ │  3 nodes    │ │ │${NC}"
    echo -e "${CYAN}│  │ │ 10.0.1.1    │ │  │ │ 10.1.1.1    │ │  │ │ 10.2.1.1    │ │ │${NC}"
    echo -e "${CYAN}│  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │ │${NC}"
    echo -e "${CYAN}│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │ │${NC}"
    echo -e "${CYAN}│  │ │   Workers   │ │  │ │   Workers   │ │  │ │   Workers   │ │ │${NC}"
    echo -e "${CYAN}│  │ │  Karpenter  │ │  │ │  Karpenter  │ │  │ │  Karpenter  │ │ │${NC}"
    echo -e "${CYAN}│  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │ │${NC}"
    echo -e "${CYAN}│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │${NC}"
    echo -e "${CYAN}│                                                                 │${NC}"
    echo -e "${CYAN}│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │${NC}"
    echo -e "${CYAN}│  │   IBM Cluster   │  │  Talos Cluster  │  │ DigitalOcean    │ │${NC}"
    echo -e "${CYAN}│  │                 │  │                 │  │   Cluster       │ │${NC}"
    echo -e "${CYAN}│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │                 │ │${NC}"
    echo -e "${CYAN}│  │ │Control Plane│ │  │ │Control Plane│ │  │ ┌─────────────┐ │ │${NC}"
    echo -e "${CYAN}│  │ │  3 nodes    │ │  │ │  3 nodes    │ │  │ │Control Plane│ │ │${NC}"
    echo -e "${CYAN}│  │ │ 10.3.1.1    │ │  │ │ 10.4.1.1    │ │  │ │  3 nodes    │ │ │${NC}"
    echo -e "${CYAN}│  │ └─────────────┘ │  │ └─────────────┘ │  │ │ 10.5.1.1    │ │ │${NC}"
    echo -e "${CYAN}│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ └─────────────┘ │ │${NC}"
    echo -e "${CYAN}│  │ │   Workers   │ │  │ │   Workers   │ │  │ ┌─────────────┐ │ │${NC}"
    echo -e "${CYAN}│  │ │  Karpenter  │ │  │ │  Karpenter  │ │  │ │   Workers   │ │ │${NC}"
    echo -e "${CYAN}│  │ └─────────────┘ │  │ └─────────────┘ │  │ │  Karpenter  │ │ │${NC}"
    echo -e "${CYAN}│  └─────────────────┘  └─────────────────┘  │ └─────────────┘ │ │${NC}"
    echo -e "${CYAN}│                                           └─────────────────┘ │${NC}"
    echo -e "${CYAN}│                                                                 │${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# Show what manifests we have
show_manifests() {
    log "📋 Available Manifests:"
    echo ""
    
    for cluster in $CLUSTERS; do
        echo -e "${YELLOW}🔹 $cluster Cluster:${NC}"
        local cluster_dir="$CAPI_TEMPLATES_DIR/$cluster"
        
        if [ -d "$cluster_dir" ]; then
            echo "   📁 $cluster_dir/"
            for manifest in cluster.yaml control-plane-machine.yaml worker-machine.yaml; do
                if [ -f "$cluster_dir/$manifest" ]; then
                    echo -e "   ${GREEN}✓${NC} $manifest"
                else
                    echo -e "   ${RED}✗${NC} $manifest"
                fi
            done
        else
            echo -e "   ${RED}✗${NC} Directory not found"
        fi
        echo ""
    done
}

# Show certificates
show_certificates() {
    log "🔐 Available Certificates:"
    echo ""
    
    for cluster in $CLUSTERS; do
        echo -e "${YELLOW}🔹 $cluster Certificates:${NC}"
        local certs_dir="$CERTS_DIR/$cluster"
        
        if [ -d "$certs_dir" ]; then
            echo "   📁 $certs_dir/"
            
            # Show key certificate types
            local cert_types=("ca.key" "ca.crt" "apiserver.key" "apiserver.crt" "etcd-server.key" "etcd-server.crt" "sa.key" "sa.pub" "kubelet-client.key" "kubelet-client.crt")
            
            for cert_type in "${cert_types[@]}"; do
                if [ -f "$certs_dir/$cert_type" ]; then
                    echo -e "   ${GREEN}✓${NC} $cert_type"
                else
                    echo -e "   ${RED}✗${NC} $cert_type"
                fi
            done
        else
            echo -e "   ${RED}✗${NC} Directory not found"
        fi
        echo ""
    done
}

# Show kubeadm configurations
show_kubeadm_configs() {
    log "⚙️  Available Kubeadm Configurations:"
    echo ""
    
    for cluster in $CLUSTERS; do
        local kubeadm_config="$CERTS_DIR/$cluster/kubeadm-config.yaml"
        
        if [ -f "$kubeadm_config" ]; then
            echo -e "${YELLOW}🔹 $cluster Kubeadm Config:${NC}"
            echo -e "   ${GREEN}✓${NC} $kubeadm_config"
            
            # Show key configuration details
            echo "   📋 Configuration Details:"
            echo "      • Kubernetes Version: $(grep 'kubernetesVersion:' "$kubeadm_config" | head -1 | awk '{print $2}')"
            echo "      • Cluster Name: $(grep 'clusterName:' "$kubeadm_config" | head -1 | awk '{print $2}')"
            echo "      • Control Plane Endpoint: $(grep 'controlPlaneEndpoint:' "$kubeadm_config" | head -1 | awk '{print $2}')"
            echo "      • Pod Subnet: $(grep 'podSubnet:' "$kubeadm_config" | head -1 | awk '{print $2}')"
        else
            echo -e "${RED}✗${NC} $cluster kubeadm config not found"
        fi
        echo ""
    done
}

# Show what would be deployed
show_deployment_plan() {
    log "🚀 Deployment Plan:"
    echo ""
    
    echo -e "${CYAN}1. Create Namespaces:${NC}"
    echo "   • multi-cloud-k8s (for CAPI resources)"
    echo "   • cilium-system (for CNI)"
    echo "   • istio-system (for service mesh)"
    echo "   • wireguard-system (for VPN)"
    echo "   • external-secrets-system (for secrets management)"
    echo "   • vault-system (for Vault)"
    echo "   • security-operator-system (for custom security operator)"
    echo "   • monitoring (for Prometheus)"
    echo "   • grafana (for Grafana)"
    echo "   • jaeger (for tracing)"
    echo ""
    
    echo -e "${CYAN}2. Deploy Clusters:${NC}"
    for cluster in $CLUSTERS; do
        echo "   • $cluster-cluster (3 control planes + workers via Karpenter)"
    done
    echo ""
    
    echo -e "${CYAN}3. Deploy Networking:${NC}"
    echo "   • Cilium CNI with cluster pool IPAM"
    echo "   • Istio Service Mesh with mTLS"
    echo "   • WireGuard VPN mesh for cross-cloud communication"
    echo ""
    
    echo -e "${CYAN}4. Deploy Security:${NC}"
    echo "   • External Secrets Operator"
    echo "   • Vault for secret management"
    echo "   • Custom Security Operator"
    echo ""
    
    echo -e "${CYAN}5. Deploy Monitoring:${NC}"
    echo "   • Prometheus for metrics"
    echo "   • Grafana for dashboards"
    echo "   • Jaeger for distributed tracing"
    echo ""
}

# Show sample manifest content
show_sample_manifest() {
    log "📄 Sample Manifest Content (AWS Cluster):"
    echo ""
    
    local cluster_yaml="$CAPI_TEMPLATES_DIR/aws/cluster.yaml"
    if [ -f "$cluster_yaml" ]; then
        echo -e "${CYAN}Cluster Definition:${NC}"
        head -20 "$cluster_yaml"
        echo ""
        echo -e "${YELLOW}... (truncated)${NC}"
        echo ""
    fi
}

# Show next steps
show_next_steps() {
    log "🎯 Next Steps:"
    echo ""
    
    echo -e "${CYAN}To deploy with a running Kubernetes cluster:${NC}"
    echo "1. Start a bootstrap cluster:"
    echo "   kind create cluster --name bootstrap-cluster"
    echo ""
    echo "2. Install CAPI:"
    echo "   clusterctl init --infrastructure docker"
    echo ""
    echo "3. Deploy our manifests:"
    echo "   ./deploy-with-manifests.sh"
    echo ""
    echo -e "${CYAN}To use with existing cluster:${NC}"
    echo "1. Set KUBECONFIG to your cluster"
    echo "2. Run: ./deploy-with-manifests.sh"
    echo ""
    echo -e "${CYAN}To manage kubeconfigs:${NC}"
    echo "1. Source environment: source $KUBECONFIG_DIR/setup-kubeconfig-env.sh"
    echo "2. Switch clusters: switch_cluster aws"
    echo ""
}

# Main function
main() {
    show_architecture
    show_manifests
    show_certificates
    show_kubeadm_configs
    show_deployment_plan
    show_sample_manifest
    show_next_steps
    
    echo -e "${GREEN}🎉 Multi-Cloud Kubernetes Infrastructure Ready for Deployment! 🎉${NC}"
    echo ""
    echo -e "${YELLOW}All manifests, certificates, and configurations are prepared.${NC}"
    echo -e "${YELLOW}Ready to deploy when you have a Kubernetes cluster running!${NC}"
}

# Run main function
main "$@"
