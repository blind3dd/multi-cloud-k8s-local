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
