# Cross-Cloud Networking Architecture

## Simplified Flow
```
┌─────────────────────────────────────────────────────────────────┐
│                    Simplified Architecture                     │
├─────────────────────────────────────────────────────────────────┤
│  local → Ingress Gateway → Cilium → VPN → Cross-cloud Pods     │
├─────────────────────────────────────────────────────────────────┤
│  Your Operator (Orchestration)                                 │
├─────────────────────────────────────────────────────────────────┤
│  Talos (Kubernetes OS)                                         │
├─────────────────────────────────────────────────────────────────┤
│  Flatcar (Base OS)                                             │
└─────────────────────────────────────────────────────────────────┘
```

## Network Topology
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   AWS Cluster   │    │  Azure Cluster  │    │   GCP Cluster   │
│                 │    │                 │    │                 │
│  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │
│  │ Talos VM  │  │    │  │ Talos VM  │  │    │  │ Talos VM  │  │
│  │ 10.0.1.5  │  │    │  │ 10.1.1.5  │  │    │  │ 10.2.1.5  │  │
│  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        └───────────────────────┼───────────────────────┘
                                │
                    WireGuard VPN Mesh
```

## Components

### 1. Cilium CNI
- **Purpose**: Cross-cloud pod-to-pod communication
- **Features**: WireGuard encryption, network policies, service mesh integration
- **Configuration**: Cluster pool IPAM, cross-cloud networking enabled

### 2. Istio Service Mesh
- **Purpose**: Cross-cloud service-to-service communication
- **Features**: mTLS, traffic management, observability
- **Configuration**: Cross-cluster workload entry, multi-cluster mesh

### 3. WireGuard VPN
- **Purpose**: Secure cross-cloud tunnel
- **Features**: Point-to-point encryption, low latency
- **Configuration**: Mesh topology, persistent keepalive

### 4. Custom Operator
- **Purpose**: Orchestration and management
- **Features**: Cross-cloud resource management, network policy enforcement
- **Configuration**: Multi-cluster awareness, provider-specific logic

## Communication Flow

1. **Local Request** → Ingress Gateway (Istio)
2. **Ingress Gateway** → Cilium CNI (routing decision)
3. **Cilium** → WireGuard VPN (if cross-cloud)
4. **WireGuard** → Remote cluster pod
5. **Response** → Reverse path with same security

## Security Features

- **mTLS**: All service-to-service communication encrypted
- **WireGuard**: Cross-cloud tunnel encryption
- **Network Policies**: Cilium-based micro-segmentation
- **RBAC**: Kubernetes role-based access control
- **Pod Security**: Talos immutable OS security
