# Provider-Grouped Volume Networking Architecture

## Network Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                    Provider-Grouped Networking                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   AWS Provider  │  │ Azure Provider  │  │   GCP Provider  │ │
│  │  10.0.0.0/16    │  │  10.1.0.0/16    │  │  10.2.0.0/16    │ │
│  │                 │  │                 │  │                 │ │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │ │
│  │ │   etcd-1    │ │  │ │   etcd-2    │ │  │ │   etcd-3    │ │ │
│  │ │ 10.0.1.2    │ │  │ │ 10.1.1.2    │ │  │ │ 10.2.1.2    │ │ │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │ │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │ │
│  │ │talos-cp-1   │ │  │ │talos-cp-2   │ │  │ │talos-cp-3   │ │ │
│  │ │ 10.0.2.2    │ │  │ │ 10.1.2.2    │ │  │ │ 10.2.2.2    │ │ │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │ │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │ │
│  │ │karpenter-1  │ │  │ │karpenter-2  │ │  │ │karpenter-3  │ │ │
│  │ │ 10.0.3.2    │ │  │ │ 10.1.3.2    │ │  │ │ 10.2.3.2    │ │ │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│         │                       │                       │       │
│         └───────────────────────┼───────────────────────┘       │
│                                 │                               │
│  ┌─────────────────┐  ┌─────────────────┐                      │
│  │   IBM Provider  │  │   DO Provider   │                      │
│  │  10.3.0.0/16    │  │  10.4.0.0/16    │                      │
│  │                 │  │                 │                      │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │                      │
│  │ │talos-cp-4   │ │  │ │talos-cp-5   │ │                      │
│  │ │ 10.3.1.2    │ │  │ │ 10.4.1.2    │ │                      │
│  │ └─────────────┘ │  │ └─────────────┘ │                      │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │                      │
│  │ │karpenter-4  │ │  │ │karpenter-5  │ │                      │
│  │ │ 10.3.2.2    │ │  │ │ 10.4.2.2    │ │                      │
│  │ └─────────────┘ │  │ └─────────────┘ │                      │
│  └─────────────────┘  └─────────────────┘                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Provider Groups

### AWS Provider (10.0.0.0/16)
- **etcd-1**: 10.0.1.2
- **talos-control-plane-1**: 10.0.2.2
- **karpenter-worker-1**: 10.0.3.2

### Azure Provider (10.1.0.0/16)
- **etcd-2**: 10.1.1.2
- **talos-control-plane-2**: 10.1.2.2
- **karpenter-worker-2**: 10.1.3.2

### GCP Provider (10.2.0.0/16)
- **etcd-3**: 10.2.1.2
- **talos-control-plane-3**: 10.2.2.2
- **karpenter-worker-3**: 10.2.3.2

### IBM Provider (10.3.0.0/16)
- **talos-control-plane-4**: 10.3.1.2
- **karpenter-worker-4**: 10.3.2.2

### DigitalOcean Provider (10.4.0.0/16)
- **talos-control-plane-5**: 10.4.1.2
- **karpenter-worker-5**: 10.4.2.2

## Benefits

- **Provider Isolation**: Each cloud provider has its own network segment
- **Logical Grouping**: Volumes are grouped by their intended cloud provider
- **Cross-Cloud Communication**: Different provider networks can communicate
- **Scalable**: Easy to add new providers and volumes
- **Manageable**: Centralized network management per provider

## Management Commands

```bash
# Check status
/opt/nix-volumes/networking/manage-provider-networking.sh status

# Test configurations
/opt/nix-volumes/networking/manage-provider-networking.sh test

# Show detailed info
/opt/nix-volumes/networking/manage-provider-networking.sh info

# Show cross-provider connectivity
/opt/nix-volumes/networking/manage-provider-networking.sh cross-provider
```
