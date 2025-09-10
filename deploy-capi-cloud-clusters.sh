#!/bin/bash

# Deploy Multi-Cloud Kubernetes Clusters using CAPI
# This script uses CAPI to deploy actual cloud-based Kubernetes clusters
# The local Kind cluster serves as the CAPI management cluster

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
echo "║                    🚀 CAPI CLOUD CLUSTER DEPLOYMENT 🚀                   ║"
echo "║                        Management Cluster → Cloud Clusters                ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if kubectl can connect to management cluster
echo -e "${CYAN}🔍 Checking CAPI management cluster connection...${NC}"
if kubectl cluster-info &>/dev/null; then
    echo -e "${GREEN}✓ Connected to CAPI management cluster${NC}"
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

# Initialize CAPI with cloud providers
echo -e "${CYAN}🚀 Initializing CAPI with cloud providers...${NC}"
echo -e "${YELLOW}Installing AWS provider...${NC}"
clusterctl init --infrastructure aws
echo -e "${YELLOW}Installing Azure provider...${NC}"
clusterctl init --infrastructure azure
echo -e "${YELLOW}Installing GCP provider...${NC}"
clusterctl init --infrastructure gcp
echo -e "${YELLOW}Installing IBM provider...${NC}"
clusterctl init --infrastructure ibmcloud
echo -e "${GREEN}✓ CAPI initialized with cloud providers${NC}"
echo ""

# Check cloud provider credentials
echo -e "${CYAN}🔐 Checking cloud provider credentials...${NC}"

# AWS credentials
if aws sts get-caller-identity &>/dev/null; then
    echo -e "${GREEN}✓ AWS credentials configured${NC}"
    aws sts get-caller-identity
else
    echo -e "${YELLOW}⚠️  AWS credentials not configured${NC}"
    echo -e "${YELLOW}  Please configure AWS credentials: aws configure${NC}"
fi

# Azure credentials
if az account show &>/dev/null; then
    echo -e "${GREEN}✓ Azure credentials configured${NC}"
    az account show --query "name" -o tsv
else
    echo -e "${YELLOW}⚠️  Azure credentials not configured${NC}"
    echo -e "${YELLOW}  Please configure Azure credentials: az login${NC}"
fi

# GCP credentials
if gcloud auth list --filter=status:ACTIVE --format="value(account)" &>/dev/null; then
    echo -e "${GREEN}✓ GCP credentials configured${NC}"
    gcloud auth list --filter=status:ACTIVE --format="value(account)"
else
    echo -e "${YELLOW}⚠️  GCP credentials not configured${NC}"
    echo -e "${YELLOW}  Please configure GCP credentials: gcloud auth login${NC}"
fi

# IBM credentials
if ibmcloud account show &>/dev/null; then
    echo -e "${GREEN}✓ IBM credentials configured${NC}"
    ibmcloud account show
else
    echo -e "${YELLOW}⚠️  IBM credentials not configured${NC}"
    echo -e "${YELLOW}  Please configure IBM credentials: ibmcloud login${NC}"
fi
echo ""

# Create namespaces for each cloud provider
echo -e "${CYAN}📋 Creating namespaces for cloud clusters...${NC}"
kubectl create namespace aws-cluster --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace azure-cluster --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace gcp-cluster --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace ibm-cluster --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Namespaces created${NC}"
echo ""

# Generate cluster manifests
echo -e "${CYAN}📝 Generating cluster manifests...${NC}"

# AWS Cluster
cat > /tmp/aws-cluster.yaml << 'EOF'
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: aws-cluster
  namespace: aws-cluster
spec:
  clusterNetwork:
    pods:
      cidrBlocks: ["10.0.0.0/16"]
    services:
      cidrBlocks: ["10.1.0.0/16"]
  controlPlaneRef:
    apiVersion: controlplane.cluster.x-k8s.io/v1beta1
    kind: KubeadmControlPlane
    name: aws-control-plane
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta2
    kind: AWSCluster
    name: aws-cluster
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta2
kind: AWSCluster
metadata:
  name: aws-cluster
  namespace: aws-cluster
spec:
  region: us-west-2
  sshKeyName: default
  controlPlaneLoadBalancer:
    scheme: internet-facing
    crossZoneLoadBalancing: true
---
apiVersion: controlplane.cluster.x-k8s.io/v1beta1
kind: KubeadmControlPlane
metadata:
  name: aws-control-plane
  namespace: aws-cluster
spec:
  replicas: 3
  version: v1.28.0
  infrastructureTemplate:
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta2
    kind: AWSMachineTemplate
    name: aws-control-plane-template
  kubeadmConfigSpec:
    clusterConfiguration:
      apiServer:
        certSANs:
        - localhost
        - 127.0.0.1
      controlPlaneEndpoint: "aws-cluster-apiserver-123456789.us-west-2.elb.amazonaws.com:6443"
    initConfiguration:
      nodeRegistration:
        kubeletExtraArgs:
          cloud-provider: aws
    joinConfiguration:
      nodeRegistration:
        kubeletExtraArgs:
          cloud-provider: aws
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta2
kind: AWSMachineTemplate
metadata:
  name: aws-control-plane-template
  namespace: aws-cluster
spec:
  template:
    spec:
      instanceType: t3.medium
      ami:
        id: ami-0c55b159cbfafe1d0
      iamInstanceProfile: control-plane.cluster-api-provider-aws.sigs.k8s.io
      sshKeyName: default
EOF

# Azure Cluster
cat > /tmp/azure-cluster.yaml << 'EOF'
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: azure-cluster
  namespace: azure-cluster
spec:
  clusterNetwork:
    pods:
      cidrBlocks: ["10.0.0.0/16"]
    services:
      cidrBlocks: ["10.1.0.0/16"]
  controlPlaneRef:
    apiVersion: controlplane.cluster.x-k8s.io/v1beta1
    kind: KubeadmControlPlane
    name: azure-control-plane
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    kind: AzureCluster
    name: azure-cluster
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: AzureCluster
metadata:
  name: azure-cluster
  namespace: azure-cluster
spec:
  location: eastus
  resourceGroup: azure-cluster-rg
  networkSpec:
    vnet:
      name: azure-cluster-vnet
    subnets:
    - name: azure-cluster-subnet
      cidrBlock: "10.0.0.0/16"
---
apiVersion: controlplane.cluster.x-k8s.io/v1beta1
kind: KubeadmControlPlane
metadata:
  name: azure-control-plane
  namespace: azure-cluster
spec:
  replicas: 3
  version: v1.28.0
  infrastructureTemplate:
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    kind: AzureMachineTemplate
    name: azure-control-plane-template
  kubeadmConfigSpec:
    clusterConfiguration:
      apiServer:
        certSANs:
        - localhost
        - 127.0.0.1
      controlPlaneEndpoint: "azure-cluster-apiserver.eastus.cloudapp.azure.com:6443"
    initConfiguration:
      nodeRegistration:
        kubeletExtraArgs:
          cloud-provider: azure
    joinConfiguration:
      nodeRegistration:
        kubeletExtraArgs:
          cloud-provider: azure
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: AzureMachineTemplate
metadata:
  name: azure-control-plane-template
  namespace: azure-cluster
spec:
  template:
    spec:
      vmSize: Standard_D2s_v3
      image:
        marketplace:
          name: UbuntuServer
          publisher: Canonical
          offer: 0001-com-ubuntu-server-focal
          sku: 20_04-lts-gen2
          version: latest
EOF

# GCP Cluster
cat > /tmp/gcp-cluster.yaml << 'EOF'
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: gcp-cluster
  namespace: gcp-cluster
spec:
  clusterNetwork:
    pods:
      cidrBlocks: ["10.0.0.0/16"]
    services:
      cidrBlocks: ["10.1.0.0/16"]
  controlPlaneRef:
    apiVersion: controlplane.cluster.x-k8s.io/v1beta1
    kind: KubeadmControlPlane
    name: gcp-control-plane
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    kind: GCPCluster
    name: gcp-cluster
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: GCPCluster
metadata:
  name: gcp-cluster
  namespace: gcp-cluster
spec:
  region: us-central1
  project: your-gcp-project
  network:
    name: gcp-cluster-network
    subnets:
    - name: gcp-cluster-subnet
      cidrBlock: "10.0.0.0/16"
      region: us-central1
---
apiVersion: controlplane.cluster.x-k8s.io/v1beta1
kind: KubeadmControlPlane
metadata:
  name: gcp-control-plane
  namespace: gcp-cluster
spec:
  replicas: 3
  version: v1.28.0
  infrastructureTemplate:
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    kind: GCPMachineTemplate
    name: gcp-control-plane-template
  kubeadmConfigSpec:
    clusterConfiguration:
      apiServer:
        certSANs:
        - localhost
        - 127.0.0.1
      controlPlaneEndpoint: "gcp-cluster-apiserver.us-central1.elb.amazonaws.com:6443"
    initConfiguration:
      nodeRegistration:
        kubeletExtraArgs:
          cloud-provider: gce
    joinConfiguration:
      nodeRegistration:
        kubeletExtraArgs:
          cloud-provider: gce
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: GCPMachineTemplate
metadata:
  name: gcp-control-plane-template
  namespace: gcp-cluster
spec:
  template:
    spec:
      machineType: e2-standard-2
      image: projects/ubuntu-os-cloud/global/images/family/ubuntu-2004-lts
EOF

# IBM Cluster
cat > /tmp/ibm-cluster.yaml << 'EOF'
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: ibm-cluster
  namespace: ibm-cluster
spec:
  clusterNetwork:
    pods:
      cidrBlocks: ["10.0.0.0/16"]
    services:
      cidrBlocks: ["10.1.0.0/16"]
  controlPlaneRef:
    apiVersion: controlplane.cluster.x-k8s.io/v1beta1
    kind: KubeadmControlPlane
    name: ibm-control-plane
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    kind: IBMCloudCluster
    name: ibm-cluster
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: IBMCloudCluster
metadata:
  name: ibm-cluster
  namespace: ibm-cluster
spec:
  region: us-south
  resourceGroup: ibm-cluster-rg
  vpc:
    name: ibm-cluster-vpc
    subnets:
    - name: ibm-cluster-subnet
      cidrBlock: "10.0.0.0/16"
      zone: us-south-1
---
apiVersion: controlplane.cluster.x-k8s.io/v1beta1
kind: KubeadmControlPlane
metadata:
  name: ibm-control-plane
  namespace: ibm-cluster
spec:
  replicas: 3
  version: v1.28.0
  infrastructureTemplate:
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    kind: IBMCloudMachineTemplate
    name: ibm-control-plane-template
  kubeadmConfigSpec:
    clusterConfiguration:
      apiServer:
        certSANs:
        - localhost
        - 127.0.0.1
      controlPlaneEndpoint: "ibm-cluster-apiserver.us-south.containers.appdomain.cloud:6443"
    initConfiguration:
      nodeRegistration:
        kubeletExtraArgs:
          cloud-provider: ibm
    joinConfiguration:
      nodeRegistration:
        kubeletExtraArgs:
          cloud-provider: ibm
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: IBMCloudMachineTemplate
metadata:
  name: ibm-control-plane-template
  namespace: ibm-cluster
spec:
  template:
    spec:
      instanceType: bx2-2x8
      image: ibm-ubuntu-20-04-3-minimal-amd64-2
EOF

echo -e "${GREEN}✓ Cluster manifests generated${NC}"
echo ""

# Deploy clusters (only if credentials are available)
echo -e "${CYAN}☁️  Deploying cloud clusters...${NC}"

# Deploy AWS cluster
if aws sts get-caller-identity &>/dev/null; then
    echo -e "${YELLOW}Deploying AWS cluster...${NC}"
    kubectl apply -f /tmp/aws-cluster.yaml
    echo -e "${GREEN}✓ AWS cluster deployed${NC}"
else
    echo -e "${YELLOW}⚠️  Skipping AWS cluster (credentials not configured)${NC}"
fi

# Deploy Azure cluster
if az account show &>/dev/null; then
    echo -e "${YELLOW}Deploying Azure cluster...${NC}"
    kubectl apply -f /tmp/azure-cluster.yaml
    echo -e "${GREEN}✓ Azure cluster deployed${NC}"
else
    echo -e "${YELLOW}⚠️  Skipping Azure cluster (credentials not configured)${NC}"
fi

# Deploy GCP cluster
if gcloud auth list --filter=status:ACTIVE --format="value(account)" &>/dev/null; then
    echo -e "${YELLOW}Deploying GCP cluster...${NC}"
    kubectl apply -f /tmp/gcp-cluster.yaml
    echo -e "${GREEN}✓ GCP cluster deployed${NC}"
else
    echo -e "${YELLOW}⚠️  Skipping GCP cluster (credentials not configured)${NC}"
fi

# Deploy IBM cluster
if ibmcloud account show &>/dev/null; then
    echo -e "${YELLOW}Deploying IBM cluster...${NC}"
    kubectl apply -f /tmp/ibm-cluster.yaml
    echo -e "${GREEN}✓ IBM cluster deployed${NC}"
else
    echo -e "${YELLOW}⚠️  Skipping IBM cluster (credentials not configured)${NC}"
fi

echo ""

# Show cluster status
echo -e "${CYAN}📊 CAPI Cloud Cluster Status:${NC}"
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
echo -e "${GREEN}🎉 CAPI Cloud Cluster Deployment Complete! 🎉${NC}"
echo ""
echo -e "${CYAN}Architecture:${NC}"
echo "• Management Cluster (Kind): Manages all cloud clusters via CAPI"
echo "• AWS Cluster: 3 control planes in us-west-2"
echo "• Azure Cluster: 3 control planes in eastus"
echo "• GCP Cluster: 3 control planes in us-central1"
echo "• IBM Cluster: 3 control planes in us-south"
echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo "1. Configure cloud provider credentials"
echo "2. Deploy clusters: kubectl apply -f /tmp/*-cluster.yaml"
echo "3. Wait for clusters to be ready: kubectl wait --for=condition=ready cluster --all"
echo "4. Get kubeconfig: clusterctl get kubeconfig <cluster-name>"
echo ""
echo -e "${PURPLE}🚀 CAPI managing multi-cloud Kubernetes clusters! 🚀${NC}"
