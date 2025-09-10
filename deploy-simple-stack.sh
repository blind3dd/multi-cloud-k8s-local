#!/bin/bash

# Simple Security & Networking + Monitoring Deployment
# Deploy components step by step with proper dependencies

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
echo "║                    🚀 SIMPLE STACK DEPLOYMENT 🚀                           ║"
echo "║                        Security + Networking + Monitoring                  ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if kubectl can connect
echo -e "${CYAN}🔍 Checking Kubernetes cluster connection...${NC}"
if kubectl cluster-info &>/dev/null; then
    echo -e "${GREEN}✓ Connected to Kubernetes cluster${NC}"
    kubectl cluster-info
else
    echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi
echo ""

# Create namespaces
echo -e "${CYAN}📋 Creating namespaces...${NC}"
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace grafana --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace jaeger --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace external-secrets-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace vault-system --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Namespaces created${NC}"
echo ""

# Install Helm repositories
echo -e "${CYAN}📦 Adding Helm repositories...${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo add external-secrets https://charts.external-secrets.io
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
echo -e "${GREEN}✓ Helm repositories added${NC}"
echo ""

# Deploy Prometheus (with CRDs)
echo -e "${CYAN}📊 Deploying Prometheus with CRDs...${NC}"
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false \
  --wait
echo -e "${GREEN}✓ Prometheus deployed with CRDs${NC}"
echo ""

# Deploy Grafana
echo -e "${CYAN}📈 Deploying Grafana...${NC}"
helm install grafana grafana/grafana \
  --namespace grafana \
  --set persistence.enabled=true \
  --set persistence.size=10Gi \
  --set adminPassword=admin \
  --set service.type=ClusterIP \
  --set service.port=3000 \
  --wait
echo -e "${GREEN}✓ Grafana deployed${NC}"
echo ""

# Deploy Jaeger
echo -e "${CYAN}🔍 Deploying Jaeger...${NC}"
helm install jaeger jaegertracing/jaeger \
  --namespace jaeger \
  --set storage.type=memory \
  --set provisionDataStore.cassandra=false \
  --set provisionDataStore.elasticsearch=false \
  --wait
echo -e "${GREEN}✓ Jaeger deployed${NC}"
echo ""

# Deploy External Secrets Operator
echo -e "${CYAN}🔐 Deploying External Secrets Operator...${NC}"
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets-system \
  --create-namespace \
  --wait
echo -e "${GREEN}✓ External Secrets Operator deployed${NC}"
echo ""

# Deploy Vault
echo -e "${CYAN}🏦 Deploying Vault...${NC}"
helm install vault hashicorp/vault \
  --namespace vault-system \
  --set server.dev.enabled=true \
  --set server.dev.devRootToken=root \
  --set server.standalone.enabled=true \
  --set server.standalone.config='
ui = true
listener "tcp" {
  address = "[::]:8200"
  cluster_address = "[::]:8201"
  tls_disable = true
}
storage "file" {
  path = "/vault/data"
}
' \
  --set server.extraEnvironmentVars.VAULT_DEV_ROOT_TOKEN_ID=root \
  --set server.extraEnvironmentVars.VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200 \
  --wait
echo -e "${GREEN}✓ Vault deployed${NC}"
echo ""

# Deploy Cilium CNI (now that CRDs are available)
echo -e "${CYAN}🔌 Deploying Cilium CNI...${NC}"
helm repo add cilium https://helm.cilium.io/
helm repo update
helm install cilium cilium/cilium \
  --namespace cilium-system \
  --create-namespace \
  --set cluster.name=test-cluster \
  --set cluster.id=1 \
  --set ipam.mode=cluster-pool \
  --set ipam.operator.clusterPoolIPv4PodCIDRList=10.244.0.0/16 \
  --set ipam.operator.clusterPoolIPv4MaskSize=24 \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set prometheus.enabled=true \
  --set operator.prometheus.enabled=true \
  --set hubble.metrics.enabled="{dns,drop,tcp,flow,port-distribution,icmp,http}" \
  --set hubble.metrics.serviceMonitor.enabled=true \
  --wait
echo -e "${GREEN}✓ Cilium CNI deployed${NC}"
echo ""

# Show deployment status
echo -e "${CYAN}📊 Deployment Status:${NC}"
echo ""
echo -e "${YELLOW}Namespaces:${NC}"
kubectl get namespaces | grep -E "(monitoring|grafana|jaeger|external-secrets|vault|cilium)"

echo ""
echo -e "${YELLOW}Pods:${NC}"
kubectl get pods --all-namespaces | grep -E "(prometheus|grafana|jaeger|external-secrets|vault|cilium)"

echo ""
echo -e "${YELLOW}Services:${NC}"
kubectl get services --all-namespaces | grep -E "(prometheus|grafana|jaeger|external-secrets|vault|cilium)"

echo ""
echo -e "${GREEN}🎉 Simple Stack Deployment Complete! 🎉${NC}"
echo ""
echo -e "${CYAN}Access Information:${NC}"
echo "• Grafana: kubectl port-forward -n grafana svc/grafana 3000:3000 (admin/admin)"
echo "• Prometheus: kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo "• Jaeger: kubectl port-forward -n jaeger svc/jaeger-query 16686:16686"
echo "• Vault: kubectl port-forward -n vault-system svc/vault 8200:8200 (root token: root)"
echo "• Cilium Hubble: kubectl port-forward -n cilium-system svc/hubble-ui 12000:80"
echo ""
echo -e "${PURPLE}🚀 All components deployed successfully! 🚀${NC}"
