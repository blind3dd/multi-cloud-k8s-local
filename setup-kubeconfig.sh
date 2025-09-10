#!/bin/bash

# Setup KUBECONFIG and kubeadm-generated keys for Multi-Cloud Kubernetes
# This script generates the necessary kubeconfig files and certificates for CAPI

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VOLUMES_DIR="/opt/nix-volumes"
KUBECONFIG_DIR="$VOLUMES_DIR/kubeconfigs"
CERTS_DIR="$VOLUMES_DIR/certificates"

# Cluster configurations
CLUSTERS="aws azure gcp ibm digitalocean talos"

get_cluster_endpoint() {
    case "$1" in
        "aws") echo "10.0.1.1:6443" ;;
        "azure") echo "10.1.1.1:6443" ;;
        "gcp") echo "10.2.1.1:6443" ;;
        "ibm") echo "10.3.1.1:6443" ;;
        "digitalocean") echo "10.4.1.1:6443" ;;
        "talos") echo "10.4.1.1:6443" ;;
        *) echo "10.0.1.1:6443" ;;
    esac
}

echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    KUBECONFIG and Certificate Setup                         ║"
echo "║                        Multi-Cloud Kubernetes                               ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Create directories
create_directories() {
    log "Creating kubeconfig and certificate directories..."
    
    sudo mkdir -p "$KUBECONFIG_DIR"
    sudo mkdir -p "$CERTS_DIR"
    
    # Create subdirectories for each cluster
    for cluster in $CLUSTERS; do
        sudo mkdir -p "$KUBECONFIG_DIR/$cluster"
        sudo mkdir -p "$CERTS_DIR/$cluster"
    done
    
    sudo chown -R "$(whoami):staff" "$KUBECONFIG_DIR"
    sudo chown -R "$(whoami):staff" "$CERTS_DIR"
    
    log_success "Directories created"
}

# Generate CA certificates
generate_ca_certificates() {
    log "Generating CA certificates for each cluster..."
    
    for cluster in $CLUSTERS; do
        log "Generating CA certificate for $cluster cluster..."
        
        local ca_dir="$CERTS_DIR/$cluster"
        local ca_key="$ca_dir/ca.key"
        local ca_crt="$ca_dir/ca.crt"
        
        # Generate CA private key (following proper kubeadm format)
        openssl genrsa -out "$ca_key" 2048
        
        # Generate CA certificate
        openssl req -x509 -new -nodes -key "$ca_key" -subj "/CN=kubernetes-ca/O=kubernetes" -days 10000 -out "$ca_crt"
        
        log_success "CA certificate generated for $cluster"
    done
}

# Generate kubeadm configuration for each cluster
generate_kubeadm_configs() {
    log "Generating kubeadm configurations for each cluster..."
    
    for cluster in $CLUSTERS; do
        log "Generating kubeadm configuration for $cluster cluster..."
        
        local endpoint=$(get_cluster_endpoint "$cluster")
        local advertise_ip="${endpoint%:*}"
        local kubeadm_config="$CERTS_DIR/$cluster/kubeadm-config.yaml"
        
        # Generate kubeadm token
        local kubeadm_token=$(openssl rand -hex 3).$(openssl rand -hex 8)
        
        # Create kubeadm configuration with proper SAN and JWT keys
        cat > "$kubeadm_config" << EOF
apiVersion: kubeadm.k8s.io/v1beta1
kind: InitConfiguration
bootstrapTokens:
- token: "${kubeadm_token}"
  description: "default kubeadm bootstrap token"
  ttl: "0"
localAPIEndpoint:
  advertiseAddress: ${advertise_ip}
  bindPort: 6443
---
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
kubernetesVersion: v1.28.0
clusterName: ${cluster}-cluster
controlPlaneEndpoint: ${endpoint}
certificatesDir: ${CERTS_DIR}/${cluster}
networking:
  podSubnet: 10.244.0.0/16
apiServer:
  certSANs:
  - ${advertise_ip}
  - ${endpoint}
  - localhost
  - 127.0.0.1
  - ${cluster}-api-server
  - ${cluster}-control-plane
  extraArgs:
    max-requests-inflight: "1000"
    max-mutating-requests-inflight: "500"        
    default-watch-cache-size: "500"
    watch-cache-sizes: "persistentvolumeclaims#1000,persistentvolumes#1000"
    service-account-key-file: ${CERTS_DIR}/${cluster}/sa.pub
    service-account-signing-key-file: ${CERTS_DIR}/${cluster}/sa.key
controllerManager:
  extraArgs:
    deployment-controller-sync-period: "50s"
    service-account-private-key-file: ${CERTS_DIR}/${cluster}/sa.key
---
apiVersion: kubeadm.k8s.io/v1beta1
kind: JoinConfiguration
discovery:
  bootstrapToken:
    apiServerEndpoint: ${endpoint}
    token: "${kubeadm_token}"
    unsafeSkipCAVerification: false
    caCertHashes:
    - sha256:$(openssl x509 -pubkey -in ${CERTS_DIR}/${cluster}/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
nodeRegistration:
  kubeletExtraArgs:
    node-ip: ${advertise_ip}
EOF
        
        # Save token for later use
        echo "$kubeadm_token" > "$CERTS_DIR/$cluster/kubeadm-token.txt"
        
        log_success "Kubeadm configuration generated for $cluster"
    done
}

# Generate CAPI machine templates
generate_capi_templates() {
    log "Generating CAPI machine templates for each cluster..."
    
    local capi_dir="$VOLUMES_DIR/capi-templates"
    sudo mkdir -p "$capi_dir"
    
    for cluster in $CLUSTERS; do
        log "Generating CAPI templates for $cluster cluster..."
        
        local cluster_dir="$capi_dir/$cluster"
        sudo mkdir -p "$cluster_dir"
        
        # Generate control plane machine template
        cat > "$cluster_dir/control-plane-machine.yaml" << EOF
apiVersion: cluster.x-k8s.io/v1beta2
kind: Machine
metadata:
  name: ${cluster}-control-plane-1
  namespace: default
  labels:
    cluster.x-k8s.io/cluster-name: ${cluster}-cluster
    cluster.x-k8s.io/control-plane: "true"
    set: controlplane
spec:
  bootstrap:
    configRef:
      apiGroup: bootstrap.cluster.x-k8s.io
      kind: KubeadmConfig
      name: ${cluster}-control-plane-1-config
  infrastructureRef:
    apiGroup: infrastructure.cluster.x-k8s.io
    kind: DockerMachine
    name: ${cluster}-control-plane-1-docker
  version: "v1.28.0"
---
apiVersion: bootstrap.cluster.x-k8s.io/v1beta2
kind: KubeadmConfig
metadata:
  name: ${cluster}-control-plane-1-config
  namespace: default
spec:
  clusterConfiguration:
    apiServer:
      certSANs:
      - ${cluster}-api-server
      - ${cluster}-control-plane
      - localhost
      - 127.0.0.1
    controlPlaneEndpoint: ${cluster}-control-plane:6443
    clusterName: ${cluster}-cluster
    kubernetesVersion: v1.28.0
    networking:
      podSubnet: 10.244.0.0/16
  initConfiguration:
    localAPIEndpoint:
      advertiseAddress: $(get_cluster_endpoint "$cluster" | cut -d: -f1)
      bindPort: 6443
  joinConfiguration:
    controlPlane:
      localAPIEndpoint:
        advertiseAddress: $(get_cluster_endpoint "$cluster" | cut -d: -f1)
        bindPort: 6443
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta2
kind: DockerMachine
metadata:
  name: ${cluster}-control-plane-1-docker
  namespace: default
spec:
  providerID: docker://${cluster}-control-plane-1
EOF
        
        # Generate worker machine template
        cat > "$cluster_dir/worker-machine.yaml" << EOF
apiVersion: cluster.x-k8s.io/v1beta2
kind: Machine
metadata:
  name: ${cluster}-worker-1
  namespace: default
  labels:
    cluster.x-k8s.io/cluster-name: ${cluster}-cluster
    set: worker
spec:
  bootstrap:
    configRef:
      apiGroup: bootstrap.cluster.x-k8s.io
      kind: KubeadmConfig
      name: ${cluster}-worker-1-config
  infrastructureRef:
    apiGroup: infrastructure.cluster.x-k8s.io
    kind: DockerMachine
    name: ${cluster}-worker-1-docker
  version: "v1.28.0"
---
apiVersion: bootstrap.cluster.x-k8s.io/v1beta2
kind: KubeadmConfig
metadata:
  name: ${cluster}-worker-1-config
  namespace: default
spec:
  joinConfiguration:
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: $(get_cluster_endpoint "$cluster" | cut -d: -f1)
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta2
kind: DockerMachine
metadata:
  name: ${cluster}-worker-1-docker
  namespace: default
spec:
  providerID: docker://${cluster}-worker-1
EOF
        
        # Generate cluster template
        cat > "$cluster_dir/cluster.yaml" << EOF
apiVersion: cluster.x-k8s.io/v1beta2
kind: Cluster
metadata:
  name: ${cluster}-cluster
  namespace: default
spec:
  clusterNetwork:
    pods:
      cidrBlocks:
      - 10.244.0.0/16
    serviceDomain: cluster.local
  controlPlaneEndpoint:
    host: ${cluster}-control-plane
    port: 6443
  controlPlaneRef:
    apiGroup: controlplane.cluster.x-k8s.io
    kind: KubeadmControlPlane
    name: ${cluster}-control-plane
  infrastructureRef:
    apiGroup: infrastructure.cluster.x-k8s.io
    kind: DockerCluster
    name: ${cluster}-cluster
---
apiVersion: controlplane.cluster.x-k8s.io/v1beta2
kind: KubeadmControlPlane
metadata:
  name: ${cluster}-control-plane
  namespace: default
spec:
  kubeadmConfigSpec:
    clusterConfiguration:
      apiServer:
        certSANs:
        - ${cluster}-api-server
        - ${cluster}-control-plane
        - localhost
        - 127.0.0.1
      controlPlaneEndpoint: ${cluster}-control-plane:6443
      clusterName: ${cluster}-cluster
      kubernetesVersion: v1.28.0
      networking:
        podSubnet: 10.244.0.0/16
    initConfiguration:
      localAPIEndpoint:
        advertiseAddress: $(get_cluster_endpoint "$cluster" | cut -d: -f1)
        bindPort: 6443
    joinConfiguration:
      controlPlane:
        localAPIEndpoint:
          advertiseAddress: $(get_cluster_endpoint "$cluster" | cut -d: -f1)
          bindPort: 6443
  replicas: 3
  version: v1.28.0
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta2
kind: DockerCluster
metadata:
  name: ${cluster}-cluster
  namespace: default
spec: {}
EOF
        
        log_success "CAPI templates generated for $cluster"
    done
    
    sudo chown -R "$(whoami):staff" "$capi_dir"
    log_success "CAPI templates created in $capi_dir"
}

# Generate proxy certificates for cross-cloud communication
generate_proxy_certificates() {
    log "Generating proxy certificates for cross-cloud communication..."
    
    local proxy_certs_dir="$CERTS_DIR/proxy"
    sudo mkdir -p "$proxy_certs_dir"
    
    # Generate proxy CA
    local proxy_ca_key="$proxy_certs_dir/proxy-ca.key"
    local proxy_ca_crt="$proxy_certs_dir/proxy-ca.crt"
    
    openssl genrsa -out "$proxy_ca_key" 4096
    openssl req -new -x509 -days 365 -key "$proxy_ca_key" -out "$proxy_ca_crt" -subj "/CN=proxy-ca/O=multi-cloud-proxy"
    
    # Generate proxy server certificate
    local proxy_server_key="$proxy_certs_dir/proxy-server.key"
    local proxy_server_crt="$proxy_certs_dir/proxy-server.crt"
    
    openssl genrsa -out "$proxy_server_key" 4096
    openssl req -new -key "$proxy_server_key" -out "$proxy_certs_dir/proxy-server.csr" -subj "/CN=proxy-server/O=multi-cloud-proxy"
    openssl x509 -req -in "$proxy_certs_dir/proxy-server.csr" -CA "$proxy_ca_crt" -CAkey "$proxy_ca_key" -CAcreateserial -out "$proxy_server_crt" -days 365
    
    # Generate proxy client certificates for each cluster
    for cluster in $CLUSTERS; do
        log "Generating proxy client certificate for $cluster cluster..."
        
        local proxy_client_key="$proxy_certs_dir/${cluster}-proxy-client.key"
        local proxy_client_crt="$proxy_certs_dir/${cluster}-proxy-client.crt"
        
        openssl genrsa -out "$proxy_client_key" 4096
        openssl req -new -key "$proxy_client_key" -out "$proxy_certs_dir/${cluster}-proxy-client.csr" -subj "/CN=${cluster}-proxy-client/O=multi-cloud-proxy"
        openssl x509 -req -in "$proxy_certs_dir/${cluster}-proxy-client.csr" -CA "$proxy_ca_crt" -CAkey "$proxy_ca_key" -CAcreateserial -out "$proxy_client_crt" -days 365
        
        log_success "Proxy client certificate generated for $cluster"
    done
    
    # Generate WireGuard certificates for VPN mesh
    local wg_certs_dir="$proxy_certs_dir/wireguard"
    sudo mkdir -p "$wg_certs_dir"
    
    # Generate WireGuard server certificate
    local wg_server_key="$wg_certs_dir/wg-server.key"
    local wg_server_crt="$wg_certs_dir/wg-server.crt"
    
    openssl genrsa -out "$wg_server_key" 4096
    openssl req -new -key "$wg_server_key" -out "$wg_certs_dir/wg-server.csr" -subj "/CN=wireguard-server/O=multi-cloud-vpn"
    openssl x509 -req -in "$wg_certs_dir/wg-server.csr" -CA "$proxy_ca_crt" -CAkey "$proxy_ca_key" -CAcreateserial -out "$wg_server_crt" -days 365
    
    # Generate WireGuard client certificates for each cluster
    for cluster in $CLUSTERS; do
        log "Generating WireGuard client certificate for $cluster cluster..."
        
        local wg_client_key="$wg_certs_dir/${cluster}-wg-client.key"
        local wg_client_crt="$wg_certs_dir/${cluster}-wg-client.crt"
        
        openssl genrsa -out "$wg_client_key" 4096
        openssl req -new -key "$wg_client_key" -out "$wg_certs_dir/${cluster}-wg-client.csr" -subj "/CN=${cluster}-wireguard-client/O=multi-cloud-vpn"
        openssl x509 -req -in "$wg_certs_dir/${cluster}-wg-client.csr" -CA "$proxy_ca_crt" -CAkey "$proxy_ca_key" -CAcreateserial -out "$wg_client_crt" -days 365
        
        log_success "WireGuard client certificate generated for $cluster"
    done
    
    # Clean up CSR files
    rm -f "$proxy_certs_dir"/*.csr
    rm -f "$wg_certs_dir"/*.csr
    
    sudo chown -R "$(whoami):staff" "$proxy_certs_dir"
    log_success "Proxy certificates generated"
}

# Generate kubeadm certificates
generate_kubeadm_certificates() {
    log "Generating kubeadm certificates for each cluster..."
    
    for cluster in $CLUSTERS; do
        log "Generating kubeadm certificates for $cluster cluster..."
        
        local certs_dir="$CERTS_DIR/$cluster"
        local ca_key="$certs_dir/ca.key"
        local ca_crt="$certs_dir/ca.crt"
        
        # Generate API server certificate with proper SANs
        local apiserver_key="$certs_dir/apiserver.key"
        local apiserver_crt="$certs_dir/apiserver.crt"
        local endpoint=$(get_cluster_endpoint "$cluster")
        local advertise_ip="${endpoint%:*}"
        local master_cluster_ip="10.96.0.1"  # Default service cluster IP
        
        openssl genrsa -out "$apiserver_key" 4096
        
        # Create CSR config for API server with proper SANs
        cat > "$certs_dir/apiserver-csr.conf" << EOF
[ req ]
default_bits = 4096
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C = US
ST = CA
L = San Francisco
O = Kubernetes
OU = Multi-Cloud
CN = kube-apiserver

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster
DNS.5 = kubernetes.default.svc.cluster.local
DNS.6 = ${cluster}-api-server
DNS.7 = ${cluster}-control-plane
DNS.8 = ${cluster}-cluster
IP.1 = ${advertise_ip}
IP.2 = ${master_cluster_ip}
IP.3 = 127.0.0.1
IP.4 = ::1

[ v3_ext ]
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=@alt_names
EOF
        
        openssl req -new -key "$apiserver_key" -out "$certs_dir/apiserver.csr" -config "$certs_dir/apiserver-csr.conf"
        openssl x509 -req -in "$certs_dir/apiserver.csr" -CA "$ca_crt" -CAkey "$ca_key" -CAcreateserial -out "$apiserver_crt" -days 365 -extensions v3_ext -extfile "$certs_dir/apiserver-csr.conf" -sha256
        
        # Generate etcd server certificate
        local etcd_key="$certs_dir/etcd-server.key"
        local etcd_crt="$certs_dir/etcd-server.crt"
        
        openssl genrsa -out "$etcd_key" 4096
        openssl req -new -key "$etcd_key" -out "$certs_dir/etcd-server.csr" -subj "/CN=etcd-server/O=kubernetes"
        openssl x509 -req -in "$certs_dir/etcd-server.csr" -CA "$ca_crt" -CAkey "$ca_key" -CAcreateserial -out "$etcd_crt" -days 365
        
        # Generate front-proxy CA
        local front_proxy_ca_key="$certs_dir/front-proxy-ca.key"
        local front_proxy_ca_crt="$certs_dir/front-proxy-ca.crt"
        
        openssl genrsa -out "$front_proxy_ca_key" 4096
        openssl req -new -x509 -days 365 -key "$front_proxy_ca_key" -out "$front_proxy_ca_crt" -subj "/CN=front-proxy-ca/O=kubernetes"
        
        # Generate front-proxy client certificate
        local front_proxy_client_key="$certs_dir/front-proxy-client.key"
        local front_proxy_client_crt="$certs_dir/front-proxy-client.crt"
        
        openssl genrsa -out "$front_proxy_client_key" 4096
        openssl req -new -key "$front_proxy_client_key" -out "$certs_dir/front-proxy-client.csr" -subj "/CN=front-proxy-client/O=kubernetes"
        openssl x509 -req -in "$certs_dir/front-proxy-client.csr" -CA "$front_proxy_ca_crt" -CAkey "$front_proxy_ca_key" -CAcreateserial -out "$front_proxy_client_crt" -days 365
        
        # Generate API extensions certificates
        local api_ext_key="$certs_dir/apiserver-extensions.key"
        local api_ext_crt="$certs_dir/apiserver-extensions.crt"
        
        openssl genrsa -out "$api_ext_key" 4096
        openssl req -new -key "$api_ext_key" -out "$certs_dir/apiserver-extensions.csr" -subj "/CN=kube-apiserver-extensions/O=kubernetes"
        openssl x509 -req -in "$certs_dir/apiserver-extensions.csr" -CA "$ca_crt" -CAkey "$ca_key" -CAcreateserial -out "$api_ext_crt" -days 365
        
        # Generate CRD (Custom Resource Definition) certificates
        local crd_key="$certs_dir/crd-server.key"
        local crd_crt="$certs_dir/crd-server.crt"
        
        openssl genrsa -out "$crd_key" 4096
        openssl req -new -key "$crd_key" -out "$certs_dir/crd-server.csr" -subj "/CN=crd-server/O=kubernetes"
        openssl x509 -req -in "$certs_dir/crd-server.csr" -CA "$ca_crt" -CAkey "$ca_key" -CAcreateserial -out "$crd_crt" -days 365
        
        # Generate aggregation layer certificates
        local agg_ca_key="$certs_dir/aggregation-ca.key"
        local agg_ca_crt="$certs_dir/aggregation-ca.crt"
        
        openssl genrsa -out "$agg_ca_key" 4096
        openssl req -new -x509 -days 365 -key "$agg_ca_key" -out "$agg_ca_crt" -subj "/CN=aggregation-ca/O=kubernetes"
        
        # Generate aggregation client certificate
        local agg_client_key="$certs_dir/aggregation-client.key"
        local agg_client_crt="$certs_dir/aggregation-client.crt"
        
        openssl genrsa -out "$agg_client_key" 4096
        openssl req -new -key "$agg_client_key" -out "$certs_dir/aggregation-client.csr" -subj "/CN=aggregation-client/O=kubernetes"
        openssl x509 -req -in "$certs_dir/aggregation-client.csr" -CA "$agg_ca_crt" -CAkey "$agg_ca_key" -CAcreateserial -out "$agg_client_crt" -days 365
        
        # Generate JWT signing keys for kubeadm bootstrap tokens
        local jwt_sa_key="$certs_dir/sa.key"
        local jwt_sa_pub="$certs_dir/sa.pub"
        
        openssl genrsa -out "$jwt_sa_key" 2048
        openssl rsa -in "$jwt_sa_key" -pubout -out "$jwt_sa_pub"
        
        # Generate additional JWT key for service account tokens
        local jwt_sa_legacy_key="$certs_dir/sa-legacy.key"
        local jwt_sa_legacy_pub="$certs_dir/sa-legacy.pub"
        
        openssl genrsa -out "$jwt_sa_legacy_key" 2048
        openssl rsa -in "$jwt_sa_legacy_key" -pubout -out "$jwt_sa_legacy_pub"
        
        # Generate kubelet client certificates for node joining
        local kubelet_client_key="$certs_dir/kubelet-client.key"
        local kubelet_client_crt="$certs_dir/kubelet-client.crt"
        
        openssl genrsa -out "$kubelet_client_key" 4096
        openssl req -new -key "$kubelet_client_key" -out "$certs_dir/kubelet-client.csr" -subj "/CN=system:node:${cluster}-node/O=system:nodes"
        openssl x509 -req -in "$certs_dir/kubelet-client.csr" -CA "$ca_crt" -CAkey "$ca_key" -CAcreateserial -out "$kubelet_client_crt" -days 365
        
        # Generate kubelet server certificate with proper SANs for node joining
        local kubelet_server_key="$certs_dir/kubelet-server.key"
        local kubelet_server_crt="$certs_dir/kubelet-server.crt"
        local endpoint=$(get_cluster_endpoint "$cluster")
        local advertise_ip="${endpoint%:*}"
        
        openssl genrsa -out "$kubelet_server_key" 4096
        
        # Create SAN configuration for kubelet server
        cat > "$certs_dir/kubelet-server.conf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = system:node:${cluster}-node
O = system:nodes

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
IP.1 = ${advertise_ip}
IP.2 = 127.0.0.1
IP.3 = ::1
DNS.1 = ${cluster}-node
DNS.2 = ${cluster}-kubelet
DNS.3 = localhost
EOF
        
        openssl req -new -key "$kubelet_server_key" -out "$certs_dir/kubelet-server.csr" -config "$certs_dir/kubelet-server.conf"
        openssl x509 -req -in "$certs_dir/kubelet-server.csr" -CA "$ca_crt" -CAkey "$ca_key" -CAcreateserial -out "$kubelet_server_crt" -days 365 -extensions v3_req -extfile "$certs_dir/kubelet-server.conf"
        
        # Generate proxy client certificate for kubelet
        local kubelet_proxy_key="$certs_dir/kubelet-proxy.key"
        local kubelet_proxy_crt="$certs_dir/kubelet-proxy.crt"
        
        openssl genrsa -out "$kubelet_proxy_key" 4096
        openssl req -new -key "$kubelet_proxy_key" -out "$certs_dir/kubelet-proxy.csr" -subj "/CN=system:node-proxier:${cluster}-node/O=system:node-proxiers"
        openssl x509 -req -in "$certs_dir/kubelet-proxy.csr" -CA "$ca_crt" -CAkey "$ca_key" -CAcreateserial -out "$kubelet_proxy_crt" -days 365
        
        # Clean up CSR files and temporary config
        rm -f "$certs_dir"/*.csr
        rm -f "$certs_dir/kubelet-server.conf"
        rm -f "$certs_dir/apiserver-csr.conf"
        
        log_success "Kubeadm certificates generated for $cluster (including API extensions, CRD, aggregation layer, JWT keys, and kubelet certificates)"
    done
}

# Generate kubeconfig files
generate_kubeconfig_files() {
    log "Generating kubeconfig files for each cluster..."
    
    for cluster in $CLUSTERS; do
        log "Generating kubeconfig for $cluster cluster..."
        
        local kubeconfig_dir="$KUBECONFIG_DIR/$cluster"
        local certs_dir="$CERTS_DIR/$cluster"
        local endpoint=$(get_cluster_endpoint "$cluster")
        
        # Generate admin kubeconfig
        local admin_key="$certs_dir/admin.key"
        local admin_crt="$certs_dir/admin.crt"
        local ca_crt="$certs_dir/ca.crt"
        
        # Generate admin certificate
        openssl genrsa -out "$admin_key" 4096
        openssl req -new -key "$admin_key" -out "$certs_dir/admin.csr" -subj "/CN=admin/O=system:masters"
        openssl x509 -req -in "$certs_dir/admin.csr" -CA "$ca_crt" -CAkey "$certs_dir/ca.key" -CAcreateserial -out "$admin_crt" -days 365
        
        # Create kubeconfig file
        local kubeconfig="$kubeconfig_dir/admin.conf"
        
        cat > "$kubeconfig" << EOF
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: $(base64 -i "$ca_crt" | tr -d '\n')
    server: https://$endpoint
  name: $cluster-cluster
contexts:
- context:
    cluster: $cluster-cluster
    user: $cluster-admin
  name: $cluster-admin@$cluster-cluster
current-context: $cluster-admin@$cluster-cluster
kind: Config
preferences: {}
users:
- name: $cluster-admin
  user:
    client-certificate-data: $(base64 -i "$admin_crt" | tr -d '\n')
    client-key-data: $(base64 -i "$admin_key" | tr -d '\n')
EOF
        
        # Generate controller-manager kubeconfig
        local cm_key="$certs_dir/controller-manager.key"
        local cm_crt="$certs_dir/controller-manager.crt"
        
        openssl genrsa -out "$cm_key" 4096
        openssl req -new -key "$cm_key" -out "$certs_dir/controller-manager.csr" -subj "/CN=system:kube-controller-manager/O=system:kube-controller-manager"
        openssl x509 -req -in "$certs_dir/controller-manager.csr" -CA "$ca_crt" -CAkey "$certs_dir/ca.key" -CAcreateserial -out "$cm_crt" -days 365
        
        local cm_kubeconfig="$kubeconfig_dir/controller-manager.conf"
        cat > "$cm_kubeconfig" << EOF
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: $(base64 -i "$ca_crt" | tr -d '\n')
    server: https://$endpoint
  name: $cluster-cluster
contexts:
- context:
    cluster: $cluster-cluster
    user: $cluster-controller-manager
  name: $cluster-controller-manager@$cluster-cluster
current-context: $cluster-controller-manager@$cluster-cluster
kind: Config
preferences: {}
users:
- name: $cluster-controller-manager
  user:
    client-certificate-data: $(base64 -i "$cm_crt" | tr -d '\n')
    client-key-data: $(base64 -i "$cm_key" | tr -d '\n')
EOF
        
        # Generate scheduler kubeconfig
        local scheduler_key="$certs_dir/scheduler.key"
        local scheduler_crt="$certs_dir/scheduler.crt"
        
        openssl genrsa -out "$scheduler_key" 4096
        openssl req -new -key "$scheduler_key" -out "$certs_dir/scheduler.csr" -subj "/CN=system:kube-scheduler/O=system:kube-scheduler"
        openssl x509 -req -in "$certs_dir/scheduler.csr" -CA "$ca_crt" -CAkey "$certs_dir/ca.key" -CAcreateserial -out "$scheduler_crt" -days 365
        
        local scheduler_kubeconfig="$kubeconfig_dir/scheduler.conf"
        cat > "$scheduler_kubeconfig" << EOF
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: $(base64 -i "$ca_crt" | tr -d '\n')
    server: https://$endpoint
  name: $cluster-cluster
contexts:
- context:
    cluster: $cluster-cluster
    user: $cluster-scheduler
  name: $cluster-scheduler@$cluster-cluster
current-context: $cluster-scheduler@$cluster-cluster
kind: Config
preferences: {}
users:
- name: $cluster-scheduler
  user:
    client-certificate-data: $(base64 -i "$scheduler_crt" | tr -d '\n')
    client-key-data: $(base64 -i "$scheduler_key" | tr -d '\n')
EOF
        
        # Clean up CSR files
        rm -f "$certs_dir"/*.csr
        
        log_success "Kubeconfig files generated for $cluster"
    done
}

# Create master kubeconfig
create_master_kubeconfig() {
    log "Creating master kubeconfig for multi-cluster management..."
    
    local master_kubeconfig="$KUBECONFIG_DIR/master.conf"
    
    cat > "$master_kubeconfig" << EOF
apiVersion: v1
clusters:
EOF
    
    # Add all clusters to master kubeconfig
    for cluster in $CLUSTERS; do
        local endpoint=$(get_cluster_endpoint "$cluster")
        local ca_crt="$CERTS_DIR/$cluster/ca.crt"
        
        cat >> "$master_kubeconfig" << EOF
- cluster:
    certificate-authority-data: $(base64 -i "$ca_crt" | tr -d '\n')
    server: https://$endpoint
  name: $cluster-cluster
EOF
    done
    
    cat >> "$master_kubeconfig" << EOF
contexts:
EOF
    
    # Add contexts for all clusters
    for cluster in $CLUSTERS; do
        cat >> "$master_kubeconfig" << EOF
- context:
    cluster: $cluster-cluster
    user: $cluster-admin
  name: $cluster-admin@$cluster-cluster
EOF
    done
    
    cat >> "$master_kubeconfig" << EOF
current-context: aws-admin@aws-cluster
kind: Config
preferences: {}
users:
EOF
    
    # Add users for all clusters
    for cluster in $CLUSTERS; do
        local admin_crt="$CERTS_DIR/$cluster/admin.crt"
        local admin_key="$CERTS_DIR/$cluster/admin.key"
        
        cat >> "$master_kubeconfig" << EOF
- name: $cluster-admin
  user:
    client-certificate-data: $(base64 -i "$admin_crt" | tr -d '\n')
    client-key-data: $(base64 -i "$admin_key" | tr -d '\n')
EOF
    done
    
    log_success "Master kubeconfig created"
}

# Create kubeconfig management script
create_kubeconfig_management() {
    log "Creating kubeconfig management script..."
    
    local manage_script="$KUBECONFIG_DIR/manage-kubeconfigs.sh"
    
    cat > "$manage_script" << 'EOF'
#!/bin/bash

# Kubeconfig Management Script for Multi-Cloud Kubernetes
set -euo pipefail

KUBECONFIG_DIR="/opt/nix-volumes/kubeconfigs"
CERTS_DIR="/opt/nix-volumes/certificates"

usage() {
    echo "Usage: $0 {status|switch|list|export|import|backup|restore}"
    echo ""
    echo "Commands:"
    echo "  status  - Show current kubeconfig status"
    echo "  switch  - Switch to a specific cluster"
    echo "  list    - List all available clusters"
    echo "  export  - Export kubeconfig for a cluster"
    echo "  import  - Import kubeconfig for a cluster"
    echo "  backup  - Backup all kubeconfigs"
    echo "  restore - Restore kubeconfigs from backup"
}

status_kubeconfig() {
    echo "Kubeconfig Status:"
    echo "=================="
    
    echo -e "\nCurrent KUBECONFIG:"
    echo "${KUBECONFIG:-not set}"
    
    echo -e "\nAvailable Clusters:"
    for cluster_dir in "$KUBECONFIG_DIR"/*/; do
        if [ -d "$cluster_dir" ]; then
            local cluster=$(basename "$cluster_dir")
            echo "  - $cluster"
        fi
    done
    
    echo -e "\nCertificate Status:"
    for cert_dir in "$CERTS_DIR"/*/; do
        if [ -d "$cert_dir" ]; then
            local cluster=$(basename "$cert_dir")
            local cert_count=$(find "$cert_dir" -name "*.crt" | wc -l)
            echo "  - $cluster: $cert_count certificates"
        fi
    done
}

switch_cluster() {
    local cluster="${1:-}"
    if [ -z "$cluster" ]; then
        echo "Usage: $0 switch <cluster-name>"
        echo "Available clusters:"
        list_clusters
        exit 1
    fi
    
    local kubeconfig="$KUBECONFIG_DIR/$cluster/admin.conf"
    if [ -f "$kubeconfig" ]; then
        export KUBECONFIG="$kubeconfig"
        echo "Switched to $cluster cluster"
        echo "KUBECONFIG=$KUBECONFIG"
    else
        echo "Error: Kubeconfig for $cluster not found"
        exit 1
    fi
}

list_clusters() {
    echo "Available Clusters:"
    for cluster_dir in "$KUBECONFIG_DIR"/*/; do
        if [ -d "$cluster_dir" ]; then
            local cluster=$(basename "$cluster_dir")
            echo "  - $cluster"
        fi
    done
}

export_kubeconfig() {
    local cluster="${1:-}"
    if [ -z "$cluster" ]; then
        echo "Usage: $0 export <cluster-name>"
        exit 1
    fi
    
    local kubeconfig="$KUBECONFIG_DIR/$cluster/admin.conf"
    if [ -f "$kubeconfig" ]; then
        cp "$kubeconfig" "./${cluster}-kubeconfig.conf"
        echo "Exported kubeconfig for $cluster to ./${cluster}-kubeconfig.conf"
    else
        echo "Error: Kubeconfig for $cluster not found"
        exit 1
    fi
}

import_kubeconfig() {
    local cluster="${1:-}"
    local file="${2:-}"
    
    if [ -z "$cluster" ] || [ -z "$file" ]; then
        echo "Usage: $0 import <cluster-name> <kubeconfig-file>"
        exit 1
    fi
    
    if [ -f "$file" ]; then
        cp "$file" "$KUBECONFIG_DIR/$cluster/admin.conf"
        echo "Imported kubeconfig for $cluster from $file"
    else
        echo "Error: File $file not found"
        exit 1
    fi
}

backup_kubeconfigs() {
    local backup_dir="./kubeconfig-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    cp -r "$KUBECONFIG_DIR" "$backup_dir/"
    cp -r "$CERTS_DIR" "$backup_dir/"
    
    echo "Backed up kubeconfigs to $backup_dir"
}

restore_kubeconfigs() {
    local backup_dir="${1:-}"
    if [ -z "$backup_dir" ]; then
        echo "Usage: $0 restore <backup-directory>"
        exit 1
    fi
    
    if [ -d "$backup_dir" ]; then
        cp -r "$backup_dir/kubeconfigs" "$(dirname "$KUBECONFIG_DIR")/"
        cp -r "$backup_dir/certificates" "$(dirname "$CERTS_DIR")/"
        echo "Restored kubeconfigs from $backup_dir"
    else
        echo "Error: Backup directory $backup_dir not found"
        exit 1
    fi
}

main() {
    case "${1:-}" in
        status)
            status_kubeconfig
            ;;
        switch)
            switch_cluster "$2"
            ;;
        list)
            list_clusters
            ;;
        export)
            export_kubeconfig "$2"
            ;;
        import)
            import_kubeconfig "$2" "$3"
            ;;
        backup)
            backup_kubeconfigs
            ;;
        restore)
            restore_kubeconfigs "$2"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
EOF
    
    chmod +x "$manage_script"
    log_success "Kubeconfig management script created"
}

# Create environment setup script
create_environment_setup() {
    log "Creating environment setup script..."
    
    local env_script="$KUBECONFIG_DIR/setup-kubeconfig-env.sh"
    
    cat > "$env_script" << 'EOF'
#!/bin/bash

# Kubeconfig Environment Setup Script
# Source this script to set up kubeconfig environment for multi-cloud Kubernetes

KUBECONFIG_DIR="/opt/nix-volumes/kubeconfigs"
CERTS_DIR="/opt/nix-volumes/certificates"

# Set default cluster (AWS)
export KUBECONFIG="$KUBECONFIG_DIR/aws/admin.conf"

# Add kubectl completion
if command -v kubectl &> /dev/null; then
    source <(kubectl completion bash)
fi

# Function to switch clusters
switch_cluster() {
    local cluster="${1:-}"
    if [ -z "$cluster" ]; then
        echo "Usage: switch_cluster <cluster-name>"
        echo "Available clusters: aws, azure, gcp, ibm, digitalocean, talos"
        return 1
    fi
    
    local kubeconfig="$KUBECONFIG_DIR/$cluster/admin.conf"
    if [ -f "$kubeconfig" ]; then
        export KUBECONFIG="$kubeconfig"
        echo "Switched to $cluster cluster"
        echo "KUBECONFIG=$KUBECONFIG"
    else
        echo "Error: Kubeconfig for $cluster not found"
        return 1
    fi
}

# Function to show current cluster
current_cluster() {
    if [ -n "${KUBECONFIG:-}" ]; then
        local cluster=$(basename "$(dirname "$KUBECONFIG")")
        echo "Current cluster: $cluster"
        echo "KUBECONFIG: $KUBECONFIG"
    else
        echo "No cluster selected"
    fi
}

echo "Kubeconfig environment setup complete!"
echo "Use 'switch_cluster <name>' to switch between clusters"
echo "Use 'current_cluster' to show current cluster"
echo "Available clusters: aws, azure, gcp, ibm, digitalocean, talos"
EOF
    
    chmod +x "$env_script"
    log_success "Environment setup script created"
}

# Main execution
main() {
    log "Starting kubeconfig and certificate setup..."
    
    create_directories
    generate_ca_certificates
    generate_kubeadm_configs
    generate_capi_templates
    generate_proxy_certificates
    generate_kubeadm_certificates
    generate_kubeconfig_files
    create_master_kubeconfig
    create_kubeconfig_management
    create_environment_setup
    
    echo -e "\n${GREEN}🎉 KUBECONFIG and Certificate Setup Complete! 🎉${NC}"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Source the environment setup:"
    echo "   source $KUBECONFIG_DIR/setup-kubeconfig-env.sh"
    echo ""
    echo "2. Switch between clusters:"
    echo "   switch_cluster aws"
    echo "   switch_cluster azure"
    echo "   switch_cluster gcp"
    echo "   switch_cluster ibm"
    echo "   switch_cluster digitalocean"
    echo "   switch_cluster talos"
    echo ""
    echo "3. Manage kubeconfigs:"
    echo "   $KUBECONFIG_DIR/manage-kubeconfigs.sh status"
    echo "   $KUBECONFIG_DIR/manage-kubeconfigs.sh switch aws"
    echo "   $KUBECONFIG_DIR/manage-kubeconfigs.sh list"
    echo ""
    echo -e "${BLUE}All kubeconfig files and certificates are ready for CAPI deployment!${NC}"
}

# Run main function
main "$@"
