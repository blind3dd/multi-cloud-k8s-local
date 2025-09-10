#!/bin/bash

# Deploy Multiple Kind Clusters for Multi-Cloud Simulation
# This script creates separate Kind clusters to simulate different cloud providers

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    🚀 KIND MULTI-CLOUD CLUSTERS 🚀                      ║"
echo "║                        Simulating Cloud Providers                        ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if kind is available
echo -e "${CYAN}🔍 Checking Kind availability...${NC}"
if command -v kind &> /dev/null; then
    echo -e "${GREEN}✓ Kind is available${NC}"
    kind version
else
    echo -e "${RED}✗ Kind not found${NC}"
    echo -e "${YELLOW}Please install Kind: go install sigs.k8s.io/kind@latest${NC}"
    exit 1
fi
echo ""

# Function to create a Kind cluster
create_kind_cluster() {
    local cluster_name=$1
    local provider=$2
    local node_count=${3:-1}
    
    echo -e "${CYAN}☁️  Creating $provider cluster: $cluster_name${NC}"
    
    # Create Kind cluster configuration
    cat > /tmp/${cluster_name}-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $cluster_name
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "cloud-provider=$provider,node-type=control-plane"
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "cloud-provider=$provider,node-type=worker"
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "cloud-provider=$provider,node-type=worker"
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
EOF

    # Create the cluster
    kind create cluster --config /tmp/${cluster_name}-config.yaml --wait 5m
    
    # Label the cluster
    kubectl --context kind-${cluster_name} label nodes --all cloud-provider=${provider}
    
    echo -e "${GREEN}  ✓ $provider cluster created successfully${NC}"
    
    # Show cluster info
    echo -e "${YELLOW}  📊 Cluster Info:${NC}"
    kubectl --context kind-${cluster_name} get nodes -o wide
    echo ""
}

# Create clusters for different cloud providers
echo -e "${BLUE}🚀 Creating Multi-Cloud Kubernetes Clusters...${NC}"
echo ""

# AWS Cluster
create_kind_cluster "aws-cluster" "aws" 3

# Azure Cluster  
create_kind_cluster "azure-cluster" "azure" 3

# GCP Cluster
create_kind_cluster "gcp-cluster" "gcp" 3

# IBM Cluster
create_kind_cluster "ibm-cluster" "ibm" 3

# DigitalOcean Cluster
create_kind_cluster "do-cluster" "digitalocean" 3

echo -e "${GREEN}🎉 All Multi-Cloud Clusters Created Successfully!${NC}"
echo ""

# Show all clusters
echo -e "${CYAN}📋 Available Clusters:${NC}"
kind get clusters
echo ""

# Show cluster contexts
echo -e "${CYAN}🔗 Available Contexts:${NC}"
kubectl config get-contexts
echo ""

# Create a summary
echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                            🎯 DEPLOYMENT SUMMARY 🎯                        ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✅ Created 5 Multi-Cloud Kubernetes Clusters:${NC}"
echo -e "   • ${YELLOW}aws-cluster${NC} (AWS simulation)"
echo -e "   • ${YELLOW}azure-cluster${NC} (Azure simulation)"  
echo -e "   • ${YELLOW}gcp-cluster${NC} (GCP simulation)"
echo -e "   • ${YELLOW}ibm-cluster${NC} (IBM simulation)"
echo -e "   • ${YELLOW}do-cluster${NC} (DigitalOcean simulation)"
echo ""
echo -e "${CYAN}🔧 Next Steps:${NC}"
echo -e "   1. Deploy CNI (Cilium) to each cluster"
echo -e "   2. Deploy cross-cluster networking (Istio)"
echo -e "   3. Deploy monitoring stack (Prometheus/Grafana)"
echo -e "   4. Test cross-cluster communication"
echo ""
echo -e "${BLUE}💡 To switch between clusters:${NC}"
echo -e "   kubectl config use-context kind-aws-cluster"
echo -e "   kubectl config use-context kind-azure-cluster"
echo -e "   kubectl config use-context kind-gcp-cluster"
echo -e "   kubectl config use-context kind-ibm-cluster"
echo -e "   kubectl config use-context kind-do-cluster"
echo ""

# Clean up temp files
rm -f /tmp/*-config.yaml

echo -e "${GREEN}🚀 Multi-Cloud Kubernetes Infrastructure Ready!${NC}"

