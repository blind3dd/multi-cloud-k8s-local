#!/bin/bash

# Cross-Cloud Networking Setup
# Implements: local → Ingress Gateway → Cilium → VPN → Cross-cloud Pods

set -euo pipefail

# Configuration
BASE_DIR="/opt/nix-volumes"
NETWORK_DIR="$BASE_DIR/networking"

# Network configuration
CLUSTER_NETWORKS=(
    "aws:10.0.0.0/16:10.0.1.5"
    "azure:10.1.0.0/16:10.1.1.5"
    "gcp:10.2.0.0/16:10.2.1.5"
    "ibm:10.3.0.0/16:10.3.1.5"
    "digitalocean:10.4.0.0/16:10.4.1.5"
)

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Create networking directory structure
create_network_structure() {
    log "Creating networking directory structure..."
    mkdir -p "$NETWORK_DIR"/{cilium,istio,wireguard,operator,configs}
}

# Create Cilium CNI configuration
create_cilium_config() {
    log "Creating Cilium CNI configuration..."
    
    # Cilium Helm values for cross-cloud networking
    tee "$NETWORK_DIR/cilium/values.yaml" > /dev/null <<'EOF'
# Cilium Configuration for Cross-Cloud Networking
cluster:
  name: multi-cloud-cluster
  id: 1

# Enable cross-cloud pod communication
ipam:
  mode: cluster-pool
  operator:
    clusterPoolIPv4PodCIDR: "10.0.0.0/8"
    clusterPoolIPv4MaskSize: 24

# Enable WireGuard for cross-cloud encryption
encryption:
  enabled: true
  type: wireguard

# Enable Hubble for observability
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true

# Cross-cloud service mesh integration
serviceMesh:
  integration: istio

# Network policies for cross-cloud security
policyEnforcementMode: default
EOF

    # Cilium network policies for cross-cloud communication
    tee "$NETWORK_DIR/cilium/network-policies.yaml" > /dev/null <<'EOF'
---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-cross-cloud-communication
  namespace: default
spec:
  endpointSelector: {}
  egress:
  - toEndpoints:
    - matchLabels:
        k8s:io.kubernetes.pod.namespace: kube-system
  - toEndpoints:
    - matchLabels:
        k8s:io.kubernetes.pod.namespace: istio-system
  - toCIDR:
    - "10.0.0.0/8"  # Allow cross-cloud pod communication
  - toPorts:
    - ports:
      - port: "443"
        protocol: TCP
      - port: "80"
        protocol: TCP
---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: default
spec:
  endpointSelector: {}
  ingress: []
EOF

    log "Cilium configuration created"
}

# Create Istio Service Mesh configuration
create_istio_config() {
    log "Creating Istio Service Mesh configuration..."
    
    # IstioOperator for cross-cloud service mesh
    tee "$NETWORK_DIR/istio/istio-operator.yaml" > /dev/null <<'EOF'
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: cross-cloud-istio
  namespace: istio-system
spec:
  values:
    global:
      meshID: multi-cloud-mesh
      multiCluster:
        clusterName: local-cluster
      network: cross-cloud-network
  components:
    ingressGateways:
    - name: cross-cloud-gateway
      enabled: true
      k8s:
        service:
          type: LoadBalancer
          ports:
          - port: 80
            targetPort: 8080
            name: http2
          - port: 443
            targetPort: 8443
            name: https
    pilot:
      k8s:
        env:
        - name: PILOT_ENABLE_CROSS_CLUSTER_WORKLOAD_ENTRY
          value: "true"
        - name: PILOT_ENABLE_WORKLOAD_ENTRY_AUTOREGISTRATION
          value: "true"
  meshConfig:
    defaultConfig:
      proxyStatsMatcher:
        inclusionRegexps:
        - ".*circuit_breakers.*"
        - ".*upstream_rq_retry.*"
        - ".*upstream_rq_pending.*"
        - ".*upstream_rq_timeout.*"
        - ".*upstream_cx_connect_timeout.*"
        - ".*upstream_cx_connect_fail.*"
EOF

    # Cross-cloud service mesh policies
    tee "$NETWORK_DIR/istio/cross-cloud-policies.yaml" > /dev/null <<'EOF'
---
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: cross-cloud-mtls
  namespace: default
spec:
  mtls:
    mode: STRICT
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-cross-cloud-traffic
  namespace: default
spec:
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/*/sa/*"]
    to:
    - operation:
        ports: ["80", "443"]
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: cross-cloud-tls
  namespace: default
spec:
  host: "*.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
EOF

    log "Istio configuration created"
}

# Create WireGuard VPN configuration
create_wireguard_config() {
    log "Creating WireGuard VPN configuration..."
    
    # Generate WireGuard keys for each cluster
    for cluster_info in "${CLUSTER_NETWORKS[@]}"; do
        local provider=$(echo "$cluster_info" | cut -d: -f1)
        local network=$(echo "$cluster_info" | cut -d: -f2)
        local endpoint=$(echo "$cluster_info" | cut -d: -f3)
        
        log "Creating WireGuard config for $provider cluster..."
        
        # Generate private key
        local private_key=$(wg genkey)
        local public_key=$(echo "$private_key" | wg pubkey)
        
        # Create WireGuard configuration
        tee "$NETWORK_DIR/wireguard/${provider}-wg.conf" > /dev/null <<EOF
[Interface]
PrivateKey = $private_key
Address = $network
ListenPort = 51820
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o %i -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o %i -j MASQUERADE

# Cross-cloud peers
EOF

        # Add peers for other clusters
        for peer_info in "${CLUSTER_NETWORKS[@]}"; do
            local peer_provider=$(echo "$peer_info" | cut -d: -f1)
            local peer_network=$(echo "$peer_info" | cut -d: -f2)
            local peer_endpoint=$(echo "$peer_info" | cut -d: -f3)
            
            if [[ "$peer_provider" != "$provider" ]]; then
                # Generate peer public key (in real scenario, this would be shared)
                local peer_public_key=$(wg genkey | wg pubkey)
                
                cat >> "$NETWORK_DIR/wireguard/${provider}-wg.conf" <<EOF

[Peer]
PublicKey = $peer_public_key
AllowedIPs = $peer_network
Endpoint = $peer_endpoint:51820
PersistentKeepalive = 25
EOF
            fi
        done
        
        # Store public key for sharing
        echo "$public_key" > "$NETWORK_DIR/wireguard/${provider}-public.key"
        
        log "WireGuard config created for $provider"
    done
    
    log "WireGuard VPN configuration created"
}

# Create custom orchestration operator
create_orchestration_operator() {
    log "Creating custom orchestration operator..."
    
    # Operator deployment
    tee "$NETWORK_DIR/operator/cross-cloud-operator.yaml" > /dev/null <<'EOF'
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cross-cloud-operator
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cross-cloud-operator
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints", "persistentvolumeclaims", "events", "configmaps", "secrets"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets", "replicasets", "statefulsets"]
  verbs: ["*"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "networkpolicies"]
  verbs: ["*"]
- apiGroups: ["cilium.io"]
  resources: ["ciliumnetworkpolicies", "ciliumclusterwidenetworkpolicies"]
  verbs: ["*"]
- apiGroups: ["networking.istio.io"]
  resources: ["virtualservices", "destinationrules", "gateways"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cross-cloud-operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cross-cloud-operator
subjects:
- kind: ServiceAccount
  name: cross-cloud-operator
  namespace: kube-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cross-cloud-operator
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cross-cloud-operator
  template:
    metadata:
      labels:
        app: cross-cloud-operator
    spec:
      serviceAccountName: cross-cloud-operator
      containers:
      - name: operator
        image: cross-cloud-operator:latest
        env:
        - name: CLUSTER_NAME
          value: "local-cluster"
        - name: CLOUD_PROVIDER
          value: "local"
        - name: CILIUM_ENABLED
          value: "true"
        - name: ISTIO_ENABLED
          value: "true"
        - name: WIREGUARD_ENABLED
          value: "true"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
EOF

    # Operator configuration
    tee "$NETWORK_DIR/operator/operator-config.yaml" > /dev/null <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: cross-cloud-operator-config
  namespace: kube-system
data:
  config.yaml: |
    clusters:
      aws:
        endpoint: "https://aws-cluster.example.com:6443"
        network: "10.0.0.0/16"
        gateway: "10.0.1.5"
      azure:
        endpoint: "https://azure-cluster.example.com:6443"
        network: "10.1.0.0/16"
        gateway: "10.1.1.5"
      gcp:
        endpoint: "https://gcp-cluster.example.com:6443"
        network: "10.2.0.0/16"
        gateway: "10.2.1.5"
      ibm:
        endpoint: "https://ibm-cluster.example.com:6443"
        network: "10.3.0.0/16"
        gateway: "10.3.1.5"
      digitalocean:
        endpoint: "https://do-cluster.example.com:6443"
        network: "10.4.0.0/16"
        gateway: "10.4.1.5"
    
    networking:
      cilium:
        enabled: true
        encryption: wireguard
        crossCloud: true
      istio:
        enabled: true
        crossCluster: true
        mtls: strict
      wireguard:
        enabled: true
        port: 51820
        keepalive: 25
EOF

    log "Orchestration operator created"
}

# Create network management script
create_network_management() {
    log "Creating network management script..."
    
    tee "$NETWORK_DIR/manage-networking.sh" > /dev/null <<'EOF'
#!/bin/bash

# Cross-Cloud Networking Management Script
set -euo pipefail

NETWORK_DIR="/opt/nix-volumes/networking"

usage() {
    echo "Usage: $0 {deploy|status|test|cleanup}"
    echo ""
    echo "Commands:"
    echo "  deploy  - Deploy cross-cloud networking stack"
    echo "  status  - Show networking status"
    echo "  test    - Test cross-cloud connectivity"
    echo "  cleanup - Remove networking components"
}

deploy_networking() {
    echo "Deploying cross-cloud networking stack..."
    
    # Deploy Cilium CNI
    echo "Installing Cilium CNI..."
    helm repo add cilium https://helm.cilium.io/
    helm repo update
    helm install cilium cilium/cilium \
        --namespace kube-system \
        --values "$NETWORK_DIR/cilium/values.yaml"
    
    # Deploy Istio Service Mesh
    echo "Installing Istio Service Mesh..."
    istioctl install -f "$NETWORK_DIR/istio/istio-operator.yaml" -y
    
    # Apply Istio policies
    kubectl apply -f "$NETWORK_DIR/istio/cross-cloud-policies.yaml"
    
    # Deploy custom operator
    echo "Installing cross-cloud operator..."
    kubectl apply -f "$NETWORK_DIR/operator/cross-cloud-operator.yaml"
    kubectl apply -f "$NETWORK_DIR/operator/operator-config.yaml"
    
    # Apply Cilium network policies
    kubectl apply -f "$NETWORK_DIR/cilium/network-policies.yaml"
    
    echo "Cross-cloud networking deployed successfully!"
}

status_networking() {
    echo "Cross-Cloud Networking Status:"
    echo "=============================="
    
    echo -e "\n1. Cilium CNI Status:"
    kubectl get pods -n kube-system -l k8s-app=cilium
    
    echo -e "\n2. Istio Service Mesh Status:"
    kubectl get pods -n istio-system
    
    echo -e "\n3. Cross-Cloud Operator Status:"
    kubectl get pods -n kube-system -l app=cross-cloud-operator
    
    echo -e "\n4. Network Policies:"
    kubectl get ciliumnetworkpolicies
    
    echo -e "\n5. Istio Gateways:"
    kubectl get gateways
}

test_connectivity() {
    echo "Testing cross-cloud connectivity..."
    
    # Create test pods
    kubectl run test-pod-1 --image=busybox --rm -it --restart=Never -- \
        sh -c "ping -c 3 10.1.1.5 && echo 'Azure cluster reachable'"
    
    kubectl run test-pod-2 --image=busybox --rm -it --restart=Never -- \
        sh -c "ping -c 3 10.2.1.5 && echo 'GCP cluster reachable'"
    
    echo "Cross-cloud connectivity test completed"
}

cleanup_networking() {
    echo "Cleaning up cross-cloud networking..."
    
    # Remove network policies
    kubectl delete -f "$NETWORK_DIR/cilium/network-policies.yaml" --ignore-not-found=true
    
    # Remove operator
    kubectl delete -f "$NETWORK_DIR/operator/operator-config.yaml" --ignore-not-found=true
    kubectl delete -f "$NETWORK_DIR/operator/cross-cloud-operator.yaml" --ignore-not-found=true
    
    # Remove Istio
    istioctl uninstall --purge -y
    
    # Remove Cilium
    helm uninstall cilium -n kube-system
    
    echo "Cross-cloud networking cleaned up"
}

main() {
    case "${1:-}" in
        deploy)
            deploy_networking
            ;;
        status)
            status_networking
            ;;
        test)
            test_connectivity
            ;;
        cleanup)
            cleanup_networking
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
EOF

    chmod +x "$NETWORK_DIR/manage-networking.sh"
    log "Network management script created"
}

# Create cross-cloud communication diagram
create_architecture_diagram() {
    log "Creating architecture diagram..."
    
    tee "$NETWORK_DIR/architecture.md" > /dev/null <<'EOF'
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
EOF

    log "Architecture diagram created"
}

# Main execution
main() {
    log "Setting up cross-cloud networking..."
    
    create_network_structure
    create_cilium_config
    create_istio_config
    create_wireguard_config
    create_orchestration_operator
    create_network_management
    create_architecture_diagram
    
    log "Cross-cloud networking setup complete!"
    log ""
    log "Next steps:"
    log "1. Deploy networking: $NETWORK_DIR/manage-networking.sh deploy"
    log "2. Check status: $NETWORK_DIR/manage-networking.sh status"
    log "3. Test connectivity: $NETWORK_DIR/manage-networking.sh test"
    log "4. View architecture: cat $NETWORK_DIR/architecture.md"
}

main "$@"
