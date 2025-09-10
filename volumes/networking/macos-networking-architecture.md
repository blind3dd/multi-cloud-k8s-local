# macOS Networking Architecture for Multi-Cloud Kubernetes Volumes

## Overview

This implementation creates network interfaces, bridges, and NAT for actual communication between mounted volumes and localhost on macOS using `ifconfig` and `pfctl`.

## Network Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                    macOS Host Network Stack                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   AWS Bridge    │  │ Azure Bridge    │  │   GCP Bridge    │ │
│  │   bridge-aws    │  │   bridge-azure  │  │   bridge-gcp    │ │
│  │   10.0.1.1/24   │  │   10.1.1.1/24   │  │   10.2.1.1/24   │ │
│  │                 │  │                 │  │                 │ │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │ │
│  │ │ veth-etcd-1 │ │  │ │veth-etcd-2  │ │  │ │veth-etcd-3  │ │ │
│  │ │     │       │ │  │ │     │       │ │  │ │     │       │ │ │
│  │ │ ┌─────────┐ │ │  │ │ ┌─────────┐ │ │  │ │ ┌─────────┐ │ │ │
│  │ │ │etcd-1   │ │ │  │ │ │etcd-2   │ │ │  │ │ │etcd-3   │ │ │ │
│  │ │ │10.0.1.2 │ │ │  │ │ │10.1.1.2 │ │ │  │ │ │10.2.1.2 │ │ │ │
│  │ │ └─────────┘ │ │  │ │ └─────────┘ │ │  │ │ └─────────┘ │ │ │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│         │                       │                       │       │
│         └───────────────────────┼───────────────────────┘       │
│                                 │                               │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   IBM Bridge    │  │   DO Bridge     │  │ Localhost Bridge│ │
│  │   bridge-ibm    │  │   bridge-do     │  │bridge-localhost │ │
│  │   10.3.1.1/24   │  │   10.4.1.1/24   │  │   127.0.1.1/24  │ │
│  │                 │  │                 │  │                 │ │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │ │
│  │ │veth-talos-4 │ │  │ │veth-talos-5 │ │  │ │localhost-*  │ │ │
│  │ │     │       │ │  │ │     │       │ │  │ │     │       │ │ │
│  │ │ ┌─────────┐ │ │  │ │ ┌─────────┐ │ │  │ │ ┌─────────┐ │ │ │
│  │ │ │talos-4  │ │ │  │ │ │talos-5  │ │ │  │ │ │volumes  │ │ │ │
│  │ │ │10.3.1.2 │ │ │  │ │ │10.4.1.2 │ │ │  │ │ │127.0.1.*│ │ │ │
│  │ │ └─────────┘ │ │  │ │ └─────────┘ │ │  │ │ └─────────┘ │ │ │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### Bridge Interfaces
- **AWS Bridge**: `bridge-aws` (10.0.1.1/24)
- **Azure Bridge**: `bridge-azure` (10.1.1.1/24)
- **GCP Bridge**: `bridge-gcp` (10.2.1.1/24)
- **IBM Bridge**: `bridge-ibm` (10.3.1.1/24)
- **DigitalOcean Bridge**: `bridge-do` (10.4.1.1/24)
- **Localhost Bridge**: `bridge-localhost` (127.0.1.1/24)

### Volume Interfaces
- **Purpose**: Virtual interfaces for each volume
- **Naming**: `veth-{volume-name}`
- **Function**: Connect volumes to provider bridges

### Localhost Connectivity
- **Interface**: `lo0` with aliases
- **Range**: 127.0.1.0/24
- **Function**: Localhost communication for volumes

### NAT and Routing
- **Tool**: `pfctl` (Packet Filter)
- **NAT Rules**: MASQUERADE for each provider network
- **Cross-Provider**: Allow traffic between provider networks

## Communication Flow

### Internal Communication (Same Provider)
```
Volume A (10.0.1.2) -> bridge-aws (10.0.1.1) -> Volume B (10.0.2.2)
```

### Cross-Provider Communication
```
Volume A (10.0.1.2) -> bridge-aws -> pfctl NAT -> bridge-azure -> Volume B (10.1.1.2)
```

### Localhost Communication
```
Volume A -> lo0 alias (127.0.1.x) -> Host localhost (127.0.0.1)
```

## Management Commands

```bash
# Check network status
sudo /opt/nix-volumes/networking/manage-macos-networking.sh status

# Start networking
sudo /opt/nix-volumes/networking/manage-macos-networking.sh start

# Stop networking
sudo /opt/nix-volumes/networking/manage-macos-networking.sh stop

# Test connectivity
sudo /opt/nix-volumes/networking/manage-macos-networking.sh test

# Clean up all networking
sudo /opt/nix-volumes/networking/manage-macos-networking.sh cleanup

# Show network logs
sudo /opt/nix-volumes/networking/manage-macos-networking.sh logs
```

## Network Configuration

### Provider Networks
- **AWS**: 10.0.0.0/16 (gateway: 10.0.1.1, bridge: bridge-aws)
- **Azure**: 10.1.0.0/16 (gateway: 10.1.1.1, bridge: bridge-azure)
- **GCP**: 10.2.0.0/16 (gateway: 10.2.1.1, bridge: bridge-gcp)
- **IBM**: 10.3.0.0/16 (gateway: 10.3.1.1, bridge: bridge-ibm)
- **DigitalOcean**: 10.4.0.0/16 (gateway: 10.4.1.1, bridge: bridge-do)

### Volume IP Assignments
- **etcd-1**: 10.0.1.2 (AWS)
- **etcd-2**: 10.1.1.2 (Azure)
- **etcd-3**: 10.2.1.2 (GCP)
- **talos-control-plane-1**: 10.0.2.2 (AWS)
- **talos-control-plane-2**: 10.1.2.2 (Azure)
- **talos-control-plane-3**: 10.2.2.2 (GCP)
- **talos-control-plane-4**: 10.3.1.2 (IBM)
- **talos-control-plane-5**: 10.4.1.2 (DigitalOcean)
- **karpenter-worker-1**: 10.0.3.2 (AWS)
- **karpenter-worker-2**: 10.1.3.2 (Azure)
- **karpenter-worker-3**: 10.2.3.2 (GCP)
- **karpenter-worker-4**: 10.3.2.2 (IBM)
- **karpenter-worker-5**: 10.4.2.2 (DigitalOcean)

## Security Features

- **Network Isolation**: Each provider has its own bridge
- **Provider Grouping**: Logical separation by cloud provider
- **NAT**: Masquerading for external connectivity via pfctl
- **Controlled Routing**: Explicit rules for cross-provider communication

## Benefits

- **macOS Native**: Uses ifconfig and pfctl for macOS compatibility
- **Real Networking**: Actual network interfaces and communication
- **Provider Isolation**: Each provider has its own bridge and network
- **Cross-Provider Communication**: Volumes can communicate across providers
- **Localhost Access**: Volumes can reach host localhost
- **Scalable**: Easy to add new providers and volumes
- **Manageable**: Centralized network management
