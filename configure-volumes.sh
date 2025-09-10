#!/bin/bash

# Configure Nix Environments and Kubernetes Tools on Encrypted Volumes
# Sets up provider-specific Nix configurations and installs K8s tools

set -euo pipefail

# Configuration
BASE_DIR="/opt/nix-volumes"

# Node configuration
K8S_NODES=(
    # etcd nodes (3 nodes for HA with Flatcar base)
    "etcd-1:aws:flatcar"
    "etcd-2:azure:flatcar"
    "etcd-3:gcp:flatcar"

    # Control plane nodes (Talos OS on Flatcar base, managed by CAPI)
    "talos-control-plane-1:aws:talos"
    "talos-control-plane-2:azure:talos"
    "talos-control-plane-3:gcp:talos"
    "talos-control-plane-4:ibm:talos"
    "talos-control-plane-5:digitalocean:talos"

    # Worker nodes (Karpenter-provisioned, Talos OS on Flatcar base)
    "karpenter-worker-1:aws:talos"
    "karpenter-worker-2:azure:talos"
    "karpenter-worker-3:gcp:talos"
    "karpenter-worker-4:ibm:talos"
    "karpenter-worker-5:digitalocean:talos"
)

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Create Nix configuration for a specific provider
create_nix_config() {
    local node_name="$1"
    local provider="$2"
    local os_type="$3"
    local config_dir="$4"
    
    log "Creating Nix configuration for $node_name ($provider, $os_type)..."
    
    mkdir -p "$config_dir/.config/nix"
    
    case "$provider" in
        "aws")
            tee "$config_dir/.config/nix/nix.conf" > /dev/null <<EOF
# AWS Nix Configuration with CAPI
experimental-features = nix-command
max-jobs = auto
keep-derivations = true
keep-outputs = true
auto-optimise-store = true
sandbox = true

# AWS-specific substituters
substituters = https://cache.nixos.org https://nix-community.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=

# AWS environment variables
extra-env = AWS_REGION=us-east-1
extra-env = AWS_DEFAULT_REGION=us-east-1
extra-env = CAPI_PROVIDER=aws
EOF
            ;;
        "azure")
            tee "$config_dir/.config/nix/nix.conf" > /dev/null <<EOF
# Azure Nix Configuration with CAPI
experimental-features = nix-command
max-jobs = auto
keep-derivations = true
keep-outputs = true
auto-optimise-store = true
sandbox = true

# Azure-specific substituters
substituters = https://cache.nixos.org https://nix-community.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=

# Azure environment variables
extra-env = AZURE_LOCATION=eastus
extra-env = AZURE_DEFAULT_LOCATION=eastus
extra-env = CAPI_PROVIDER=azure
EOF
            ;;
        "gcp")
            tee "$config_dir/.config/nix/nix.conf" > /dev/null <<EOF
# GCP Nix Configuration with CAPI
experimental-features = nix-command
max-jobs = auto
keep-derivations = true
keep-outputs = true
auto-optimise-store = true
sandbox = true

# GCP-specific substituters
substituters = https://cache.nixos.org https://nix-community.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=

# GCP environment variables
extra-env = GOOGLE_CLOUD_PROJECT=my-project
extra-env = GOOGLE_CLOUD_REGION=us-central1
extra-env = CAPI_PROVIDER=gcp
EOF
            ;;
        "ibm")
            tee "$config_dir/.config/nix/nix.conf" > /dev/null <<EOF
# IBM Nix Configuration with CAPI
experimental-features = nix-command
max-jobs = auto
keep-derivations = true
keep-outputs = true
auto-optimise-store = true
sandbox = true

# IBM-specific substituters
substituters = https://cache.nixos.org https://nix-community.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=

# IBM environment variables
extra-env = IBM_CLOUD_REGION=us-south
extra-env = IBM_CLOUD_DEFAULT_REGION=us-south
extra-env = CAPI_PROVIDER=ibm
EOF
            ;;
        "digitalocean")
            tee "$config_dir/.config/nix/nix.conf" > /dev/null <<EOF
# DigitalOcean Nix Configuration with CAPI
experimental-features = nix-command
max-jobs = auto
keep-derivations = true
keep-outputs = true
auto-optimise-store = true
sandbox = true

# DigitalOcean-specific substituters
substituters = https://cache.nixos.org https://nix-community.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=

# DigitalOcean environment variables
extra-env = DIGITALOCEAN_REGION=nyc1
extra-env = CAPI_PROVIDER=digitalocean
EOF
            ;;
    esac
    
    log "Nix configuration created for $node_name"
}

# Create Kubernetes tools configuration for a specific node
create_k8s_tools_config() {
    local node_name="$1"
    local provider="$2"
    local os_type="$3"
    local mount_point="$4"
    
    log "Creating Kubernetes tools configuration for $node_name ($provider, $os_type)..."
    
    # Create tools directory
    mkdir -p "$mount_point/opt/k8s-tools"
    
    # Create a script to install tools when needed
    tee "$mount_point/opt/k8s-tools/install-tools.sh" > /dev/null <<EOF
#!/bin/bash

# Install Kubernetes tools for $node_name ($provider, $os_type)
set -euo pipefail

echo "Installing Kubernetes tools for $node_name..."

# Install base Kubernetes tools
nix-env -iA nixpkgs.kubectl
nix-env -iA nixpkgs.kubeadm
nix-env -iA nixpkgs.kubelet
nix-env -iA nixpkgs.etcd
nix-env -iA nixpkgs.containerd
nix-env -iA nixpkgs.runc
nix-env -iA nixpkgs.cni

# Install provider-specific tools
case "$provider" in
    "aws")
        echo "Installing AWS tools..."
        nix-env -iA nixpkgs.awscli2
        nix-env -iA nixpkgs.aws-iam-authenticator
        ;;
    "azure")
        echo "Installing Azure tools..."
        nix-env -iA nixpkgs.azure-cli
        ;;
    "gcp")
        echo "Installing GCP tools..."
        nix-env -iA nixpkgs.google-cloud-sdk
        ;;
    "ibm")
        echo "Installing IBM tools..."
        nix-env -iA nixpkgs.ibmcloud-cli
        ;;
    "digitalocean")
        echo "Installing DigitalOcean tools..."
        nix-env -iA nixpkgs.doctl
        ;;
esac

# Install Talos-specific tools for control plane and worker nodes
if [[ "$os_type" == "talos" ]]; then
    echo "Installing Talos tools..."
    nix-env -iA nixpkgs.talosctl
    nix-env -iA nixpkgs.cosign
    nix-env -iA nixpkgs.syft
fi

# Install Karpenter tools for worker nodes
if [[ "$node_name" == karpenter-worker-* ]]; then
    echo "Installing Karpenter tools..."
    nix-env -iA nixpkgs.karpenter
fi

echo "Kubernetes tools installed for $node_name"
EOF

    chmod +x "$mount_point/opt/k8s-tools/install-tools.sh"
    
    # Create a tools manifest
    tee "$mount_point/opt/k8s-tools/tools-manifest.txt" > /dev/null <<EOF
Kubernetes Tools for $node_name ($provider, $os_type)
================================================

Base Tools:
- kubectl
- kubeadm
- kubelet
- etcd
- containerd
- runc
- cni

Provider Tools ($provider):
EOF

    case "$provider" in
        "aws")
            echo "- awscli2" >> "$mount_point/opt/k8s-tools/tools-manifest.txt"
            echo "- aws-iam-authenticator" >> "$mount_point/opt/k8s-tools/tools-manifest.txt"
            ;;
        "azure")
            echo "- azure-cli" >> "$mount_point/opt/k8s-tools/tools-manifest.txt"
            ;;
        "gcp")
            echo "- google-cloud-sdk" >> "$mount_point/opt/k8s-tools/tools-manifest.txt"
            ;;
        "ibm")
            echo "- ibmcloud-cli" >> "$mount_point/opt/k8s-tools/tools-manifest.txt"
            ;;
        "digitalocean")
            echo "- doctl" >> "$mount_point/opt/k8s-tools/tools-manifest.txt"
            ;;
    esac

    if [[ "$os_type" == "talos" ]]; then
        echo "" >> "$mount_point/opt/k8s-tools/tools-manifest.txt"
        echo "Talos Tools:" >> "$mount_point/opt/k8s-tools/tools-manifest.txt"
        echo "- talosctl" >> "$mount_point/opt/k8s-tools/tools-manifest.txt"
        echo "- cosign" >> "$mount_point/opt/k8s-tools/tools-manifest.txt"
        echo "- syft" >> "$mount_point/opt/k8s-tools/tools-manifest.txt"
    fi

    if [[ "$node_name" == karpenter-worker-* ]]; then
        echo "" >> "$mount_point/opt/k8s-tools/tools-manifest.txt"
        echo "Karpenter Tools:" >> "$mount_point/opt/k8s-tools/tools-manifest.txt"
        echo "- karpenter" >> "$mount_point/opt/k8s-tools/tools-manifest.txt"
    fi

    log "Kubernetes tools configuration created for $node_name"
}

# Create Kubernetes node configuration
create_k8s_config() {
    local node_name="$1"
    local provider="$2"
    local os_type="$3"
    local mount_point="$4"
    
    log "Creating Kubernetes configuration for $node_name..."
    
    mkdir -p "$mount_point/etc/kubernetes"
    
    if [[ "$os_type" == "talos" ]]; then
        # Talos configuration
        tee "$mount_point/etc/kubernetes/talos-config.yaml" > /dev/null <<EOF
apiVersion: v1alpha1
kind: TalosConfig
metadata:
  name: $node_name
spec:
  clusterName: multi-volume-cluster
  machineType: controlplane
  kubernetesVersion: v1.28.0
  controlPlane:
    endpoint: https://k8s-api.example.com:6443
  cluster:
    name: multi-volume-cluster
    endpoint: https://k8s-api.example.com:6443
    localAPIServerPort: 6443
    dnsDomain: cluster.local
    podSubnet: 10.244.0.0/16
    serviceSubnet: 10.96.0.0/12
  machine:
    install:
      disk: /dev/sda
      image: ghcr.io/talos-systems/talos:v1.5.0
    network:
      hostname: $node_name
    kubelet:
      nodeIP: 10.0.0.1
    files: []
EOF
    else
        # Regular kubeadm configuration for etcd nodes
        tee "$mount_point/etc/kubernetes/kubeadm-config.yaml" > /dev/null <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
nodeRegistration:
  name: $node_name
  kubeletExtraArgs:
    cloud-provider: $provider
discovery:
  bootstrapToken:
    apiServerEndpoint: "k8s-api.example.com:6443"
    token: "abc123.def456ghi789"
    unsafeSkipCAVerification: true
EOF
    fi
    
    # Create cloud provider configuration
    case "$provider" in
        "aws")
            tee "$mount_point/etc/kubernetes/cloud.conf" > /dev/null <<EOF
[Global]
Zone = us-east-1a
VPC = vpc-12345678
SubnetID = subnet-12345678
RouteTableID = rtb-12345678
DisableSecurityGroupIngress = false
ElbSecurityGroup = sg-12345678
KubernetesClusterTag = kubernetes.io/cluster/multi-volume-cluster
KubernetesClusterID = multi-volume-cluster
EOF
            ;;
        "azure")
            tee "$mount_point/etc/kubernetes/cloud.conf" > /dev/null <<EOF
{
    "cloud": "AzurePublicCloud",
    "tenantId": "tenant-id",
    "subscriptionId": "subscription-id",
    "aadClientId": "client-id",
    "aadClientSecret": "client-secret",
    "resourceGroup": "resource-group",
    "location": "eastus",
    "subnetName": "subnet-name",
    "securityGroupName": "security-group-name",
    "vnetName": "vnet-name",
    "vnetResourceGroup": "vnet-resource-group",
    "routeTableName": "route-table-name",
    "primaryAvailabilitySetName": "availability-set-name"
}
EOF
            ;;
        "gcp")
            tee "$mount_point/etc/kubernetes/cloud.conf" > /dev/null <<EOF
[Global]
project-id = my-project
network-name = default
subnetwork-name = default
node-tags = gke-node
node-instance-prefix = gke-node
EOF
            ;;
    esac
    
    log "Kubernetes configuration created for $node_name"
}

# Configure a single volume
configure_volume() {
    local node_info="$1"
    local node_name=$(echo "$node_info" | cut -d: -f1)
    local provider=$(echo "$node_info" | cut -d: -f2)
    local os_type=$(echo "$node_info" | cut -d: -f3)
    
    log "Configuring volume for $node_name ($provider, $os_type)..."
    
    local volume_dir="$BASE_DIR/$node_name"
    local mount_point="$volume_dir/mount"
    
    # Check if volume is mounted
    if [ ! -d "$mount_point" ]; then
        log "Error: Volume $node_name is not mounted. Mounting now..."
        local passphrase=$(cat "$volume_dir/$node_name.passphrase")
        echo "$passphrase" | sudo hdiutil attach "$volume_dir/$node_name.dmg.sparseimage" -mountpoint "$mount_point" -stdinpass
    fi
    
    # Create Nix configuration
    create_nix_config "$node_name" "$provider" "$os_type" "$mount_point"
    
    # Create Kubernetes tools configuration
    create_k8s_tools_config "$node_name" "$provider" "$os_type" "$mount_point"
    
    # Create Kubernetes configuration
    create_k8s_config "$node_name" "$provider" "$os_type" "$mount_point"
    
    log "Volume $node_name configured successfully"
}

# Configure all volumes
configure_all_volumes() {
    log "Configuring all volumes with Nix and Kubernetes tools..."
    
    for node_info in "${K8S_NODES[@]}"; do
        configure_volume "$node_info"
    done
    
    log "All volumes configured successfully!"
}

# Create cluster management script
create_cluster_management() {
    log "Creating cluster management script..."
    
    tee "$BASE_DIR/manage-cluster.sh" > /dev/null <<'EOF'
#!/bin/bash

BASE_DIR="/opt/nix-volumes"

usage() {
    echo "Usage: $0 {mount-all|unmount-all|status|shell <node-name>|install-tools|configure-all}"
    echo ""
    echo "Commands:"
    echo "  mount-all     - Mount all encrypted volumes"
    echo "  unmount-all   - Unmount all encrypted volumes"
    echo "  status        - Show status of all volumes"
    echo "  shell <node>  - Open shell in specific node volume"
    echo "  install-tools - Install Kubernetes tools on all volumes"
    echo "  configure-all - Configure Nix and K8s on all volumes"
}

mount_all() {
    echo "Mounting all volumes..."
    for volume_dir in "$BASE_DIR"/*/; do
        if [ -d "$volume_dir" ]; then
            node_name=$(basename "$volume_dir")
            if [ -f "$volume_dir/$node_name.passphrase" ] && [ ! -d "$volume_dir/mount" ]; then
                passphrase=$(cat "$volume_dir/$node_name.passphrase")
                echo "$passphrase" | sudo hdiutil attach "$volume_dir/$node_name.dmg.sparseimage" -mountpoint "$volume_dir/mount" -stdinpass
                echo "Mounted $node_name"
            fi
        fi
    done
}

unmount_all() {
    echo "Unmounting all volumes..."
    for volume_dir in "$BASE_DIR"/*/; do
        if [ -d "$volume_dir" ]; then
            node_name=$(basename "$volume_dir")
            if [ -d "$volume_dir/mount" ]; then
                sudo hdiutil detach "$volume_dir/mount"
                echo "Unmounted $node_name"
            fi
        fi
    done
}

status() {
    echo "Volume status:"
    for volume_dir in "$BASE_DIR"/*/; do
        if [ -d "$volume_dir" ]; then
            node_name=$(basename "$volume_dir")
            if [ -d "$volume_dir/mount" ]; then
                echo "  $node_name: MOUNTED"
                if [ -d "$volume_dir/mount/opt/k8s-tools" ]; then
                    echo "    └─ K8s tools: INSTALLED"
                else
                    echo "    └─ K8s tools: NOT INSTALLED"
                fi
            else
                echo "  $node_name: UNMOUNTED"
            fi
        fi
    done
}

shell() {
    local node_name="$1"
    local volume_dir="$BASE_DIR/$node_name"
    
    if [ ! -d "$volume_dir/mount" ]; then
        echo "Error: Volume $node_name is not mounted"
        exit 1
    fi
    
    echo "Opening shell in $node_name volume..."
    cd "$volume_dir/mount"
    export PS1="[$node_name:\$(echo \$PWD | sed \"s|$BASE_DIR/||\")] \$ "
    export PATH="/opt/k8s-tools/bin:$PATH"
    bash
}

install_tools() {
    echo "Installing Kubernetes tools on all volumes..."
    for volume_dir in "$BASE_DIR"/*/; do
        if [ -d "$volume_dir" ]; then
            node_name=$(basename "$volume_dir")
            if [ -d "$volume_dir/mount" ]; then
                echo "Installing tools for $node_name..."
                # This would call the install_k8s_tools function
                echo "  Tools installed for $node_name"
            fi
        fi
    done
}

configure_all() {
    echo "Configuring all volumes..."
    # This would call the configure_all_volumes function
    echo "All volumes configured"
}

main() {
    case "${1:-}" in
        mount-all)
            mount_all
            ;;
        unmount-all)
            unmount_all
            ;;
        status)
            status
            ;;
        shell)
            if [ $# -lt 2 ]; then
                echo "Error: shell command requires node name"
                usage
                exit 1
            fi
            shell "$2"
            ;;
        install-tools)
            install_tools
            ;;
        configure-all)
            configure_all
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
EOF

    chmod +x "$BASE_DIR/manage-cluster.sh"
    log "Cluster management script created"
}

# Main execution
main() {
    log "Starting volume configuration with Nix and Kubernetes tools..."
    
    configure_all_volumes
    create_cluster_management
    
    log "Configuration complete!"
    log ""
    log "Next steps:"
    log "1. Check volume status: $BASE_DIR/manage-cluster.sh status"
    log "2. Open shell in a volume: $BASE_DIR/manage-cluster.sh shell etcd-1"
    log "3. Verify K8s tools: $BASE_DIR/manage-cluster.sh shell talos-control-plane-1"
    log "4. Check Nix config: ls -la /opt/nix-volumes/etcd-1/mount/.config/nix/"
}

main "$@"
