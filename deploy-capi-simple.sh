#!/bin/bash

# Simplified CAPI Deployment for Multi-Cloud Kubernetes Orchestration
# This version focuses on CAPI configuration without requiring Docker/kind

set -euo pipefail

# Configuration
BASE_DIR="/opt/nix-volumes"
CAPI_DIR="$BASE_DIR/capi-management"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Create CAPI management directory
create_capi_directory() {
    log "Creating CAPI management directory..."
    mkdir -p "$CAPI_DIR"
    log "CAPI directory created at $CAPI_DIR"
}

# Initialize CAPI with provider configurations
init_capi() {
    log "Initializing CAPI with multi-cloud provider configurations..."
    
    # Create CAPI initialization script
    tee "$CAPI_DIR/init-capi.sh" > /dev/null <<'EOF'
#!/bin/bash

# CAPI Initialization Script
set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Initialize CAPI
log "Initializing Cluster API..."

# Set CAPI environment variables
export CLUSTER_TOPOLOGY=true
export EXP_CLUSTER_RESOURCE_SET=true
export EXP_MACHINE_POOL=true

# Initialize CAPI core
log "Initializing CAPI core components..."
clusterctl init --core cluster-api:v1.11.0 --bootstrap kubeadm:v1.11.0 --control-plane kubeadm:v1.11.0

# Initialize AWS provider
log "Initializing AWS provider..."
clusterctl init --infrastructure aws:v2.8.0

# Initialize Azure provider
log "Initializing Azure provider..."
clusterctl init --infrastructure azure:v1.15.0

# Initialize GCP provider
log "Initializing GCP provider..."
clusterctl init --infrastructure gcp:v1.10.0

# Initialize IBM provider
log "Initializing IBM provider..."
clusterctl init --infrastructure ibmcloud:v0.5.0

# Initialize DigitalOcean provider
log "Initializing DigitalOcean provider..."
clusterctl init --infrastructure digitalocean:v1.5.0

# Initialize Talos provider
log "Initializing Talos provider..."
clusterctl init --infrastructure talos:v1.8.0

log "CAPI initialization completed"
EOF

    chmod +x "$CAPI_DIR/init-capi.sh"
    log "CAPI initialization script created"
}

# Create cluster configurations for each provider
create_cluster_configs() {
    log "Creating cluster configurations for each provider..."
    
    # AWS cluster configuration
    tee "$CAPI_DIR/aws-cluster.yaml" > /dev/null <<'EOF'
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: aws-cluster
  namespace: default
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
  namespace: default
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
  namespace: default
spec:
  replicas: 3
  version: v1.33.4
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
        - 10.0.1.1
      controlPlaneEndpoint: "10.0.1.1:6443"
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
  namespace: default
spec:
  template:
    spec:
      instanceType: t3.medium
      ami:
        id: ami-0c55b159cbfafe1d0
      iamInstanceProfile: control-plane.cluster-api-provider-aws.sigs.k8s.io
      sshKeyName: default
EOF

    # Azure cluster configuration
    tee "$CAPI_DIR/azure-cluster.yaml" > /dev/null <<'EOF'
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: azure-cluster
  namespace: default
spec:
  clusterNetwork:
    pods:
      cidrBlocks: ["10.1.0.0/16"]
    services:
      cidrBlocks: ["10.2.0.0/16"]
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
  namespace: default
spec:
  location: westus2
  resourceGroup: azure-cluster-rg
  networkSpec:
    vnet:
      name: azure-cluster-vnet
      cidrBlock: "10.1.0.0/16"
    subnets:
    - name: azure-cluster-subnet
      cidrBlock: "10.1.0.0/24"
      role: node
  controlPlaneEndpoint:
    host: "10.1.1.1"
    port: 6443
---
apiVersion: controlplane.cluster.x-k8s.io/v1beta1
kind: KubeadmControlPlane
metadata:
  name: azure-control-plane
  namespace: default
spec:
  replicas: 3
  version: v1.33.4
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
        - 10.1.1.1
      controlPlaneEndpoint: "10.1.1.1:6443"
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
  namespace: default
spec:
  template:
    spec:
      vmSize: Standard_D2s_v3
      osDisk:
        diskSizeGB: 30
        osType: Linux
      image:
        marketplace:
          name: "0001-com-ubuntu-server-focal"
          publisher: "Canonical"
          offer: "0001-com-ubuntu-server-focal"
          sku: "20_04-lts-gen2"
          version: "latest"
EOF

    # GCP cluster configuration
    tee "$CAPI_DIR/gcp-cluster.yaml" > /dev/null <<'EOF'
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: gcp-cluster
  namespace: default
spec:
  clusterNetwork:
    pods:
      cidrBlocks: ["10.2.0.0/16"]
    services:
      cidrBlocks: ["10.3.0.0/16"]
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
  namespace: default
spec:
  project: my-gcp-project
  region: us-central1
  network:
    name: gcp-cluster-network
    subnets:
    - name: gcp-cluster-subnet
      cidr: "10.2.0.0/24"
      region: us-central1
  controlPlaneEndpoint:
    host: "10.2.1.1"
    port: 6443
---
apiVersion: controlplane.cluster.x-k8s.io/v1beta1
kind: KubeadmControlPlane
metadata:
  name: gcp-control-plane
  namespace: default
spec:
  replicas: 3
  version: v1.33.4
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
        - 10.2.1.1
      controlPlaneEndpoint: "10.2.1.1:6443"
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
  namespace: default
spec:
  template:
    spec:
      machineType: e2-medium
      imageFamily: ubuntu-2004-lts
      imageProject: ubuntu-os-cloud
      diskSize: 30
      diskType: pd-standard
EOF

    # Talos cluster configuration
    tee "$CAPI_DIR/talos-cluster.yaml" > /dev/null <<'EOF'
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: talos-cluster
  namespace: default
spec:
  clusterNetwork:
    pods:
      cidrBlocks: ["10.4.0.0/16"]
    services:
      cidrBlocks: ["10.5.0.0/16"]
  controlPlaneRef:
    apiVersion: controlplane.cluster.x-k8s.io/v1beta1
    kind: TalosControlPlane
    name: talos-control-plane
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    kind: TalosCluster
    name: talos-cluster
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: TalosCluster
metadata:
  name: talos-cluster
  namespace: default
spec:
  controlPlaneEndpoint:
    host: "10.4.1.1"
    port: 6443
---
apiVersion: controlplane.cluster.x-k8s.io/v1beta1
kind: TalosControlPlane
metadata:
  name: talos-control-plane
  namespace: default
spec:
  replicas: 3
  version: v1.33.4
  infrastructureTemplate:
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    kind: TalosMachineTemplate
    name: talos-control-plane-template
  talosConfigSpec:
    generateType: controlplane
    talosVersion: v1.10.7
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: TalosMachineTemplate
metadata:
  name: talos-control-plane-template
  namespace: default
spec:
  template:
    spec:
      talosVersion: v1.10.7
      installDisk: /dev/sda
      installImage: ghcr.io/siderolabs/installer:v1.10.7
EOF

    log "Cluster configurations created for all providers"
}

# Create CAPI management script
create_capi_management() {
    log "Creating CAPI management script..."
    
    tee "$CAPI_DIR/manage-capi.sh" > /dev/null <<'EOF'
#!/bin/bash

# CAPI Management Script
set -euo pipefail

CAPI_DIR="/opt/nix-volumes/capi-management"

usage() {
    echo "Usage: $0 {init|deploy|status|delete|help}"
    echo ""
    echo "Commands:"
    echo "  init    - Initialize CAPI with all providers"
    echo "  deploy  - Deploy clusters for all providers"
    echo "  status  - Show cluster status"
    echo "  delete  - Delete all clusters"
    echo "  help    - Show this help message"
}

init_capi() {
    echo "Initializing CAPI..."
    "$CAPI_DIR/init-capi.sh"
}

deploy_clusters() {
    echo "Deploying multi-cloud clusters..."
    
    echo "Deploying AWS cluster..."
    kubectl apply -f "$CAPI_DIR/aws-cluster.yaml"
    
    echo "Deploying Azure cluster..."
    kubectl apply -f "$CAPI_DIR/azure-cluster.yaml"
    
    echo "Deploying GCP cluster..."
    kubectl apply -f "$CAPI_DIR/gcp-cluster.yaml"
    
    echo "Deploying Talos cluster..."
    kubectl apply -f "$CAPI_DIR/talos-cluster.yaml"
    
    echo "All clusters deployed"
}

status_clusters() {
    echo "Multi-Cloud Cluster Status:"
    echo "=========================="
    
    echo -e "\nCAPI Resources:"
    kubectl get clusters
    kubectl get machines
    kubectl get machinedeployments
    
    echo -e "\nProvider Resources:"
    kubectl get awsclusters
    kubectl get azureclusters
    kubectl get gcpclusters
    kubectl get talosclusters
    
    echo -e "\nControl Planes:"
    kubectl get kubeadmcontrolplanes
    kubectl get taloscontrolplanes
}

delete_clusters() {
    echo "Deleting all clusters..."
    
    kubectl delete -f "$CAPI_DIR/talos-cluster.yaml" || true
    kubectl delete -f "$CAPI_DIR/gcp-cluster.yaml" || true
    kubectl delete -f "$CAPI_DIR/azure-cluster.yaml" || true
    kubectl delete -f "$CAPI_DIR/aws-cluster.yaml" || true
    
    echo "All clusters deleted"
}

main() {
    case "${1:-}" in
        init)
            init_capi
            ;;
        deploy)
            deploy_clusters
            ;;
        status)
            status_clusters
            ;;
        delete)
            delete_clusters
            ;;
        help|*)
            usage
            exit 1
            ;;
    esac
}

main "$@"
EOF

    chmod +x "$CAPI_DIR/manage-capi.sh"
    log "CAPI management script created"
}

# Create CAPI architecture documentation
create_capi_architecture() {
    log "Creating CAPI architecture documentation..."
    
    tee "$CAPI_DIR/capi-architecture.md" > /dev/null <<'EOF'
# Cluster API (CAPI) Multi-Cloud Architecture

## Overview

This CAPI setup provides multi-cloud Kubernetes orchestration across multiple cloud providers using Cluster API for declarative cluster management.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CAPI Management Layer                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   AWS Cluster   │  │  Azure Cluster  │  │   GCP Cluster   │ │
│  │                 │  │                 │  │                 │ │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │ │
│  │ │Control Plane│ │  │ │Control Plane│ │  │ │Control Plane│ │ │
│  │ │  3 nodes    │ │  │ │  3 nodes    │ │  │ │  3 nodes    │ │ │
│  │ │ 10.0.1.1    │ │  │ │ 10.1.1.1    │ │  │ │ 10.2.1.1    │ │ │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │ │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │ │
│  │ │   Workers   │ │  │ │   Workers   │ │  │ │   Workers   │ │ │
│  │ │  Karpenter  │ │  │ │  Karpenter  │ │  │ │  Karpenter  │ │ │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│         │                       │                       │       │
│         └───────────────────────┼───────────────────────┘       │
│                                 │                               │
│  ┌─────────────────┐  ┌─────────────────┐                      │
│  │   IBM Cluster   │  │  Talos Cluster  │                      │
│  │                 │  │                 │                      │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │                      │
│  │ │Control Plane│ │  │ │Control Plane│ │                      │
│  │ │  3 nodes    │ │  │ │  3 nodes    │ │                      │
│  │ │ 10.3.1.1    │ │  │ │ 10.4.1.1    │ │                      │
│  │ └─────────────┘ │  │ └─────────────┘ │                      │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │                      │
│  │ │   Workers   │ │  │ │   Workers   │ │                      │
│  │ │  Karpenter  │ │  │ │  Karpenter  │ │                      │
│  │ └─────────────┘ │  │ └─────────────┘ │                      │
│  └─────────────────┘  └─────────────────┘                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Provider Configurations

### AWS Provider
- **Region**: us-west-2
- **Instance Type**: t3.medium
- **Control Plane**: 3 nodes
- **Network**: 10.0.0.0/16
- **Endpoint**: 10.0.1.1:6443

### Azure Provider
- **Region**: westus2
- **VM Size**: Standard_D2s_v3
- **Control Plane**: 3 nodes
- **Network**: 10.1.0.0/16
- **Endpoint**: 10.1.1.1:6443

### GCP Provider
- **Region**: us-central1
- **Machine Type**: e2-medium
- **Control Plane**: 3 nodes
- **Network**: 10.2.0.0/16
- **Endpoint**: 10.2.1.1:6443

### Talos Provider
- **Talos Version**: v1.10.7
- **Control Plane**: 3 nodes
- **Network**: 10.4.0.0/16
- **Endpoint**: 10.4.1.1:6443

## Management Commands

```bash
# Initialize CAPI
/opt/nix-volumes/capi-management/manage-capi.sh init

# Deploy all clusters
/opt/nix-volumes/capi-management/manage-capi.sh deploy

# Check cluster status
/opt/nix-volumes/capi-management/manage-capi.sh status

# Delete all clusters
/opt/nix-volumes/capi-management/manage-capi.sh delete
```

## Integration with Volume Networking

The CAPI clusters are designed to integrate with the provider-grouped volume networking:

- **AWS volumes** (etcd-1, talos-control-plane-1, karpenter-worker-1) → AWS cluster
- **Azure volumes** (etcd-2, talos-control-plane-2, karpenter-worker-2) → Azure cluster
- **GCP volumes** (etcd-3, talos-control-plane-3, karpenter-worker-3) → GCP cluster
- **IBM volumes** (talos-control-plane-4, karpenter-worker-4) → IBM cluster
- **DigitalOcean volumes** (talos-control-plane-5, karpenter-worker-5) → Talos cluster

## Next Steps

1. Initialize CAPI with all providers
2. Deploy clusters for each provider
3. Configure cross-cloud networking (Cilium, Istio)
4. Deploy security layer (Vault, Network Policies)
5. Test cross-cloud connectivity
EOF

    log "CAPI architecture documentation created"
}

# Main execution
main() {
    log "Setting up simplified CAPI deployment for multi-cloud orchestration..."
    
    create_capi_directory
    init_capi
    create_cluster_configs
    create_capi_management
    create_capi_architecture
    
    log "Simplified CAPI deployment setup complete!"
    log ""
    log "Next steps:"
    log "1. Initialize CAPI: $CAPI_DIR/manage-capi.sh init"
    log "2. Deploy clusters: $CAPI_DIR/manage-capi.sh deploy"
    log "3. Check status: $CAPI_DIR/manage-capi.sh status"
    log "4. View architecture: cat $CAPI_DIR/capi-architecture.md"
    log ""
    log "Note: This setup creates CAPI configurations without requiring Docker/kind."
    log "You'll need a Kubernetes cluster to run CAPI against."
}

main "$@"
