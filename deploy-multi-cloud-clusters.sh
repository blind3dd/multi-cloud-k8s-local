#!/bin/bash

# Deploy Multi-Cloud Kubernetes Clusters to Encrypted Volumes
# This script uses CAPI to deploy clusters to the encrypted volumes we created

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
echo "║                    🚀 MULTI-CLOUD CLUSTER DEPLOYMENT 🚀                   ║"
echo "║                        Deploying to Encrypted Volumes                      ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if kubectl can connect to management cluster
echo -e "${CYAN}🔍 Checking management cluster connection...${NC}"
if kubectl cluster-info &>/dev/null; then
    echo -e "${GREEN}✓ Connected to management cluster${NC}"
    kubectl cluster-info
else
    echo -e "${RED}✗ Cannot connect to management cluster${NC}"
    echo -e "${YELLOW}Please ensure Kind cluster is running: kind create cluster --name test-cluster${NC}"
    exit 1
fi
echo ""

# Check if clusterctl is available
echo -e "${CYAN}🔧 Checking clusterctl availability...${NC}"
if command -v clusterctl &> /dev/null; then
    echo -e "${GREEN}✓ clusterctl is available${NC}"
    clusterctl version
else
    echo -e "${YELLOW}⚠️  clusterctl not found, installing...${NC}"
    # Install clusterctl
    curl -L https://github.com/kubernetes-sigs/cluster-api/releases/latest/download/clusterctl-darwin-amd64 -o clusterctl
    chmod +x clusterctl
    sudo mv clusterctl /usr/local/bin/
    echo -e "${GREEN}✓ clusterctl installed${NC}"
fi
echo ""

# Initialize CAPI in the management cluster
echo -e "${CYAN}🚀 Initializing Cluster API in management cluster...${NC}"
clusterctl init --infrastructure docker
echo -e "${GREEN}✓ CAPI initialized${NC}"
echo ""

# Create namespaces for each cloud provider
echo -e "${CYAN}📋 Creating namespaces for multi-cloud clusters...${NC}"
kubectl create namespace aws-cluster --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace azure-cluster --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace gcp-cluster --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace ibm-cluster --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace talos-cluster --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Namespaces created${NC}"
echo ""

# Deploy AWS cluster
echo -e "${CYAN}☁️  Deploying AWS cluster to volume...${NC}"
kubectl apply -f /opt/nix-volumes/capi-management/aws-cluster.yaml
echo -e "${GREEN}✓ AWS cluster deployed${NC}"
echo ""

# Deploy Azure cluster
echo -e "${CYAN}☁️  Deploying Azure cluster to volume...${NC}"
kubectl apply -f /opt/nix-volumes/capi-management/azure-cluster.yaml
echo -e "${GREEN}✓ Azure cluster deployed${NC}"
echo ""

# Deploy GCP cluster
echo -e "${CYAN}☁️  Deploying GCP cluster to volume...${NC}"
kubectl apply -f /opt/nix-volumes/capi-management/gcp-cluster.yaml
echo -e "${GREEN}✓ GCP cluster deployed${NC}"
echo ""

# Deploy Talos cluster
echo -e "${CYAN}☁️  Deploying Talos cluster to volume...${NC}"
kubectl apply -f /opt/nix-volumes/capi-management/talos-cluster.yaml
echo -e "${GREEN}✓ Talos cluster deployed${NC}"
echo ""

# Wait for clusters to be ready
echo -e "${YELLOW}⏳ Waiting for clusters to be ready...${NC}"
kubectl wait --for=condition=ready cluster --all --timeout=600s
echo -e "${GREEN}✓ All clusters are ready${NC}"
echo ""

# Show cluster status
echo -e "${CYAN}📊 Multi-Cloud Cluster Status:${NC}"
echo ""
echo -e "${YELLOW}Clusters:${NC}"
kubectl get clusters --all-namespaces

echo ""
echo -e "${YELLOW}Machines:${NC}"
kubectl get machines --all-namespaces

echo ""
echo -e "${YELLOW}Machine Deployments:${NC}"
kubectl get machinedeployments --all-namespaces

echo ""
echo -e "${YELLOW}Kubeadm Configs:${NC}"
kubectl get kubeadmconfigs --all-namespaces

echo ""
echo -e "${YELLOW}Docker Machines:${NC}"
kubectl get dockermachines --all-namespaces

echo ""
echo -e "${GREEN}🎉 Multi-Cloud Cluster Deployment Complete! 🎉${NC}"
echo ""
echo -e "${CYAN}Cluster Information:${NC}"
echo "• AWS Cluster: kubectl get cluster aws-cluster -n aws-cluster"
echo "• Azure Cluster: kubectl get cluster azure-cluster -n azure-cluster"
echo "• GCP Cluster: kubectl get cluster gcp-cluster -n gcp-cluster"
echo "• Talos Cluster: kubectl get cluster talos-cluster -n talos-cluster"
echo ""
echo -e "${CYAN}Volume Mount Points:${NC}"
echo "• AWS Control Planes: /opt/nix-volumes/talos-control-plane-1,2,3"
echo "• Azure Control Planes: /opt/nix-volumes/talos-control-plane-4,5"
echo "• GCP Workers: /opt/nix-volumes/karpenter-worker-1,2,3,4,5"
echo "• Etcd Nodes: /opt/nix-volumes/etcd-1,2,3"
echo ""
echo -e "${PURPLE}🚀 Multi-cloud clusters deployed to encrypted volumes! 🚀${NC}"
