#!/bin/bash

# Multi-Cloud Kubernetes Deployment - Ready to Execute
# This script shows the exact commands to deploy our infrastructure

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
echo "║                    🚀 DEPLOYING MULTI-CLOUD K8S NOW! 🚀                    ║"
echo "║                        Ready to Execute Commands                           ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${CYAN}📋 Step 1: Create Bootstrap Cluster${NC}"
echo "kind create cluster --name bootstrap-cluster"
echo ""

echo -e "${CYAN}📋 Step 2: Install CAPI${NC}"
echo "clusterctl init --infrastructure docker"
echo ""

echo -e "${CYAN}📋 Step 3: Create Namespaces${NC}"
cat << 'EOF'
kubectl create namespace multi-cloud-k8s
kubectl create namespace cilium-system
kubectl create namespace istio-system
kubectl create namespace wireguard-system
kubectl create namespace external-secrets-system
kubectl create namespace vault-system
kubectl create namespace security-operator-system
kubectl create namespace monitoring
kubectl create namespace grafana
kubectl create namespace jaeger
EOF
echo ""

echo -e "${CYAN}📋 Step 4: Deploy All Clusters${NC}"
for cluster in $CLUSTERS; do
    echo "# Deploying $cluster cluster..."
    echo "kubectl apply -f $CAPI_TEMPLATES_DIR/$cluster/cluster.yaml -n multi-cloud-k8s --v=7"
    echo "kubectl apply -f $CAPI_TEMPLATES_DIR/$cluster/control-plane-machine.yaml -n multi-cloud-k8s --v=7"
    echo "kubectl apply -f $CAPI_TEMPLATES_DIR/$cluster/worker-machine.yaml -n multi-cloud-k8s --v=7"
    echo ""
done

echo -e "${CYAN}📋 Step 5: Monitor Deployment${NC}"
cat << 'EOF'
# Watch cluster creation
kubectl get clusters -n multi-cloud-k8s -w

# Watch machine status
kubectl get machines -n multi-cloud-k8s -w

# Watch pods
kubectl get pods --all-namespaces -w
EOF
echo ""

echo -e "${CYAN}📋 Step 6: Access Clusters${NC}"
cat << 'EOF'
# Source kubeconfig environment
source /opt/nix-volumes/kubeconfigs/setup-kubeconfig-env.sh

# Switch between clusters
switch_cluster aws
switch_cluster azure
switch_cluster gcp
switch_cluster ibm
switch_cluster digitalocean
switch_cluster talos
EOF
echo ""

echo -e "${GREEN}🎯 EXECUTE THESE COMMANDS TO DEPLOY:${NC}"
echo ""
echo -e "${YELLOW}1. Start bootstrap cluster:${NC}"
echo "   kind create cluster --name bootstrap-cluster"
echo ""
echo -e "${YELLOW}2. Install CAPI:${NC}"
echo "   clusterctl init --infrastructure docker"
echo ""
echo -e "${YELLOW}3. Run our deployment:${NC}"
echo "   ./deploy-with-manifests.sh"
echo ""

echo -e "${PURPLE}🚀 READY TO DEPLOY MULTI-CLOUD KUBERNETES! 🚀${NC}"
echo -e "${CYAN}All manifests, certificates, and configurations are prepared!${NC}"
