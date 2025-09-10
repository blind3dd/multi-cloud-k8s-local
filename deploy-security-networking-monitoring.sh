#!/bin/bash

# Deploy Security & Networking and Monitoring Components
# This script deploys Cilium, Istio, WireGuard, External Secrets, Vault, Prometheus, Grafana, and Jaeger

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
echo "║                    🚀 DEPLOYING SECURITY & NETWORKING 🚀                   ║"
echo "║                        + MONITORING & OBSERVABILITY                        ║"
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
kubectl create namespace cilium-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace istio-gateway --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace wireguard-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace external-secrets-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace vault-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace security-operator-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace grafana --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace jaeger --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Namespaces created${NC}"
echo ""

# Deploy Cilium CNI
echo -e "${CYAN}🔌 Deploying Cilium CNI...${NC}"
helm repo add cilium https://helm.cilium.io/
helm repo update
helm install cilium cilium/cilium \
  --namespace cilium-system \
  --set cluster.name=test-cluster \
  --set cluster.id=1 \
  --set ipam.mode=cluster-pool \
  --set ipam.operator.clusterPoolIPv4PodCIDRList=10.244.0.0/16 \
  --set ipam.operator.clusterPoolIPv4MaskSize=24 \
  --set encryption.enabled=true \
  --set encryption.type=wireguard \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set prometheus.enabled=true \
  --set operator.prometheus.enabled=true \
  --set hubble.metrics.enabled="{dns,drop,tcp,flow,port-distribution,icmp,http}" \
  --set hubble.metrics.serviceMonitor.enabled=true
echo -e "${GREEN}✓ Cilium CNI deployed${NC}"
echo ""

# Wait for Cilium to be ready
echo -e "${YELLOW}⏳ Waiting for Cilium to be ready...${NC}"
kubectl wait --for=condition=ready pod -l k8s-app=cilium -n cilium-system --timeout=300s
echo -e "${GREEN}✓ Cilium is ready${NC}"
echo ""

# Deploy Istio Service Mesh
echo -e "${CYAN}🕸️  Deploying Istio Service Mesh...${NC}"
curl -L https://istio.io/downloadIstio | sh -
export PATH=$PWD/istio-*/bin:$PATH
istioctl install --set values.defaultRevision=default -y
kubectl label namespace default istio-injection=enabled
echo -e "${GREEN}✓ Istio Service Mesh deployed${NC}"
echo ""

# Deploy Istio Gateway
echo -e "${CYAN}🚪 Deploying Istio Gateway...${NC}"
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: multi-cloud-gateway
  namespace: istio-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: multi-cloud-tls
    hosts:
    - "*"
EOF
echo -e "${GREEN}✓ Istio Gateway deployed${NC}"
echo ""

# Deploy External Secrets Operator
echo -e "${CYAN}🔐 Deploying External Secrets Operator...${NC}"
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets-system \
  --create-namespace
echo -e "${GREEN}✓ External Secrets Operator deployed${NC}"
echo ""

# Deploy Vault
echo -e "${CYAN}🏦 Deploying Vault...${NC}"
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
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
  --set server.extraEnvironmentVars.VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200
echo -e "${GREEN}✓ Vault deployed${NC}"
echo ""

# Deploy Prometheus
echo -e "${CYAN}📊 Deploying Prometheus...${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false
echo -e "${GREEN}✓ Prometheus deployed${NC}"
echo ""

# Deploy Grafana
echo -e "${CYAN}📈 Deploying Grafana...${NC}"
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install grafana grafana/grafana \
  --namespace grafana \
  --set persistence.enabled=true \
  --set persistence.size=10Gi \
  --set adminPassword=admin \
  --set service.type=ClusterIP \
  --set service.port=3000
echo -e "${GREEN}✓ Grafana deployed${NC}"
echo ""

# Deploy Jaeger
echo -e "${CYAN}🔍 Deploying Jaeger...${NC}"
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update
helm install jaeger jaegertracing/jaeger \
  --namespace jaeger \
  --set storage.type=memory \
  --set provisionDataStore.cassandra=false \
  --set provisionDataStore.elasticsearch=false
echo -e "${GREEN}✓ Jaeger deployed${NC}"
echo ""

# Deploy WireGuard VPN
echo -e "${CYAN}🔒 Deploying WireGuard VPN...${NC}"
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: wireguard-config
  namespace: wireguard-system
data:
  wg0.conf: |
    [Interface]
    PrivateKey = $(wg genkey)
    Address = 10.0.0.1/24
    ListenPort = 51820
    PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wireguard-server
  namespace: wireguard-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wireguard-server
  template:
    metadata:
      labels:
        app: wireguard-server
    spec:
      containers:
      - name: wireguard
        image: linuxserver/wireguard:latest
        ports:
        - containerPort: 51820
          protocol: UDP
        volumeMounts:
        - name: config
          mountPath: /config
        - name: lib-modules
          mountPath: /lib/modules
          readOnly: true
        securityContext:
          privileged: true
      volumes:
      - name: config
        configMap:
          name: wireguard-config
      - name: lib-modules
        hostPath:
          path: /lib/modules
      hostNetwork: true
EOF
echo -e "${GREEN}✓ WireGuard VPN deployed${NC}"
echo ""

# Show deployment status
echo -e "${CYAN}📊 Deployment Status:${NC}"
echo ""
echo -e "${YELLOW}Namespaces:${NC}"
kubectl get namespaces | grep -E "(cilium|istio|wireguard|external-secrets|vault|security-operator|monitoring|grafana|jaeger)"

echo ""
echo -e "${YELLOW}Pods:${NC}"
kubectl get pods --all-namespaces | grep -E "(cilium|istio|wireguard|external-secrets|vault|prometheus|grafana|jaeger)"

echo ""
echo -e "${YELLOW}Services:${NC}"
kubectl get services --all-namespaces | grep -E "(cilium|istio|wireguard|external-secrets|vault|prometheus|grafana|jaeger)"

echo ""
echo -e "${GREEN}🎉 Security & Networking + Monitoring Deployment Complete! 🎉${NC}"
echo ""
echo -e "${CYAN}Access Information:${NC}"
echo "• Grafana: kubectl port-forward -n grafana svc/grafana 3000:3000"
echo "• Prometheus: kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo "• Jaeger: kubectl port-forward -n jaeger svc/jaeger-query 16686:16686"
echo "• Vault: kubectl port-forward -n vault-system svc/vault 8200:8200"
echo "• Istio Gateway: kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80"
echo ""
echo -e "${PURPLE}🚀 All components deployed successfully! 🚀${NC}"
