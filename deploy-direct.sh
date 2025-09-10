#!/bin/bash

# Multi-Cloud Kubernetes Direct Deployment
# Deploy directly to any existing Kubernetes cluster without Docker

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
CAPI_TEMPLATES_DIR="/opt/nix-volumes/capi-templates"
CLUSTERS="aws azure gcp ibm digitalocean talos"

echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    🚀 DIRECT MULTI-CLOUD K8S DEPLOYMENT 🚀                 ║"
echo "║                        No Docker Required!                                 ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if kubectl can connect
echo -e "${CYAN}🔍 Checking Kubernetes cluster connection...${NC}"
if kubectl cluster-info &>/dev/null; then
    echo -e "${GREEN}✓ Connected to Kubernetes cluster${NC}"
    kubectl cluster-info
else
    echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
    echo -e "${YELLOW}Please ensure you have a running Kubernetes cluster and kubectl is configured${NC}"
    echo ""
    echo -e "${CYAN}Options:${NC}"
    echo "1. Use an existing cluster: export KUBECONFIG=/path/to/your/kubeconfig"
    echo "2. Use minikube: minikube start"
    echo "3. Use k3s: curl -sfL https://get.k3s.io | sh -"
    echo "4. Use microk8s: microk8s start"
    exit 1
fi
echo ""

# Create namespaces
echo -e "${CYAN}📋 Creating namespaces...${NC}"
kubectl create namespace multi-cloud-k8s --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace cilium-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace wireguard-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace external-secrets-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace vault-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace security-operator-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace grafana --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace jaeger --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Namespaces created${NC}"
echo ""

# Deploy clusters
echo -e "${CYAN}🚀 Deploying multi-cloud clusters...${NC}"
for cluster in $CLUSTERS; do
    echo -e "${YELLOW}Deploying $cluster cluster...${NC}"
    
    # Apply cluster manifest
    if [ -f "$CAPI_TEMPLATES_DIR/$cluster/cluster.yaml" ]; then
        kubectl apply -f "$CAPI_TEMPLATES_DIR/$cluster/cluster.yaml" -n multi-cloud-k8s --v=7
        echo -e "${GREEN}✓ $cluster cluster manifest applied${NC}"
    fi
    
    # Apply control plane machine manifest
    if [ -f "$CAPI_TEMPLATES_DIR/$cluster/control-plane-machine.yaml" ]; then
        kubectl apply -f "$CAPI_TEMPLATES_DIR/$cluster/control-plane-machine.yaml" -n multi-cloud-k8s --v=7
        echo -e "${GREEN}✓ $cluster control plane manifest applied${NC}"
    fi
    
    # Apply worker machine manifest
    if [ -f "$CAPI_TEMPLATES_DIR/$cluster/worker-machine.yaml" ]; then
        kubectl apply -f "$CAPI_TEMPLATES_DIR/$cluster/worker-machine.yaml" -n multi-cloud-k8s --v=7
        echo -e "${GREEN}✓ $cluster worker manifest applied${NC}"
    fi
    
    echo ""
done

# Show deployment status
echo -e "${CYAN}📊 Deployment Status:${NC}"
echo ""
echo -e "${YELLOW}Namespaces:${NC}"
kubectl get namespaces | grep -E "(multi-cloud|cilium|istio|wireguard|external-secrets|vault|security-operator|monitoring|grafana|jaeger)"

echo ""
echo -e "${YELLOW}Clusters:${NC}"
kubectl get clusters -n multi-cloud-k8s 2>/dev/null || echo "No clusters found yet"

echo ""
echo -e "${YELLOW}Machines:${NC}"
kubectl get machines -n multi-cloud-k8s 2>/dev/null || echo "No machines found yet"

echo ""
echo -e "${GREEN}🎉 Multi-Cloud Kubernetes Infrastructure Deployed! 🎉${NC}"
echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo "1. Monitor cluster creation:"
echo "   kubectl get clusters -n multi-cloud-k8s -w"
echo ""
echo "2. Check machine status:"
echo "   kubectl get machines -n multi-cloud-k8s -w"
echo ""
echo "3. Access cluster kubeconfigs:"
echo "   source /opt/nix-volumes/kubeconfigs/setup-kubeconfig-env.sh"
echo "   switch_cluster aws"
echo ""
echo -e "${PURPLE}🚀 All manifests deployed successfully! 🚀${NC}"
