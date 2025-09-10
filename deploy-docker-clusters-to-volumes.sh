#!/bin/bash

# Deploy Docker-based Kubernetes Clusters to Encrypted Volumes
# This script creates Docker containers on each volume to simulate multi-cloud clusters

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
echo "║                    🚀 DOCKER CLUSTERS ON VOLUMES 🚀                      ║"
echo "║                        Multi-Cloud Simulation on Volumes                  ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if Docker is available
echo -e "${CYAN}🔍 Checking Docker availability...${NC}"
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓ Docker is available${NC}"
    docker version
else
    echo -e "${RED}✗ Docker not found${NC}"
    echo -e "${YELLOW}Please install Docker or start Docker Desktop${NC}"
    exit 1
fi
echo ""

# Function to create a cluster on a volume
create_cluster_on_volume() {
    local volume_name=$1
    local cluster_name=$2
    local node_type=$3
    local volume_path="/opt/nix-volumes/$volume_name"
    
    # Generate IP based on cluster name
    local ip_suffix
    case $cluster_name in
        "aws-cluster") ip_suffix="10" ;;
        "azure-cluster") ip_suffix="20" ;;
        "gcp-cluster") ip_suffix="30" ;;
        "ibm-cluster") ip_suffix="40" ;;
        "do-cluster") ip_suffix="50" ;;
        *) ip_suffix="99" ;;
    esac
    
    echo -e "${CYAN}📦 Creating $cluster_name cluster on $volume_name volume...${NC}"
    
    # Create a Docker network for this cluster with proper subnet
    docker network create --subnet=10.0.0.0/16 ${cluster_name}-network 2>/dev/null || true
    
    # Create control plane node
    if [[ "$node_type" == "control-plane" ]]; then
        echo -e "${YELLOW}  Creating control plane node...${NC}"
        docker run -d \
            --name ${cluster_name}-control-plane \
            --network ${cluster_name}-network \
            --ip 10.0.1.${ip_suffix} \
            -v ${volume_path}:/data \
            -v /var/run/docker.sock:/var/run/docker.sock \
            --privileged \
            kindest/node:v1.33.1 \
            tail -f /dev/null
        
        # Wait for container to be ready
        sleep 5
        
        # Initialize Kubernetes on the control plane
        docker exec ${cluster_name}-control-plane kubeadm init \
            --pod-network-cidr=10.244.0.0/16 \
            --apiserver-advertise-address=10.0.1.${ip_suffix} \
            --control-plane-endpoint=10.0.1.${ip_suffix}:6443 \
            --ignore-preflight-errors=SystemVerification
        
        echo -e "${GREEN}  ✓ Control plane node created${NC}"
        
    elif [[ "$node_type" == "worker" ]]; then
        echo -e "${YELLOW}  Creating worker node...${NC}"
        docker run -d \
            --name ${cluster_name}-worker \
            --network ${cluster_name}-network \
            --ip 10.0.2.${ip_suffix} \
            -v ${volume_path}:/data \
            -v /var/run/docker.sock:/var/run/docker.sock \
            --privileged \
            kindest/node:v1.33.1 \
            tail -f /dev/null
        
        echo -e "${GREEN}  ✓ Worker node created${NC}"
        
    elif [[ "$node_type" == "etcd" ]]; then
        echo -e "${YELLOW}  Creating etcd node...${NC}"
        docker run -d \
            --name ${cluster_name}-etcd \
            --network ${cluster_name}-network \
            --ip 10.0.3.${ip_suffix} \
            -v ${volume_path}:/data \
            -v /var/run/docker.sock:/var/run/docker.sock \
            --privileged \
            quay.io/coreos/etcd:v3.5.9 \
            etcd \
            --name=${cluster_name}-etcd \
            --data-dir=/data \
            --listen-client-urls=http://0.0.0.0:2379 \
            --advertise-client-urls=http://10.0.3.$(echo $cluster_name | tr -d 'a-z-' | cut -c1-3):2379 \
            --listen-peer-urls=http://0.0.0.0:2380 \
            --initial-advertise-peer-urls=http://10.0.3.$(echo $cluster_name | tr -d 'a-z-' | cut -c1-3):2380 \
            --initial-cluster=${cluster_name}-etcd=http://10.0.3.$(echo $cluster_name | tr -d 'a-z-' | cut -c1-3):2380 \
            --initial-cluster-token=etcd-cluster-1 \
            --initial-cluster-state=new
        
        echo -e "${GREEN}  ✓ Etcd node created${NC}"
    fi
    
    echo -e "${GREEN}✓ $cluster_name cluster created on $volume_name volume${NC}"
    echo ""
}

# Create AWS cluster on volumes
echo -e "${CYAN}☁️  Creating AWS cluster on volumes...${NC}"
create_cluster_on_volume "talos-control-plane-1" "aws-cluster" "control-plane"
create_cluster_on_volume "talos-control-plane-2" "aws-cluster" "control-plane"
create_cluster_on_volume "talos-control-plane-3" "aws-cluster" "control-plane"
create_cluster_on_volume "karpenter-worker-1" "aws-cluster" "worker"
create_cluster_on_volume "karpenter-worker-2" "aws-cluster" "worker"

# Create Azure cluster on volumes
echo -e "${CYAN}☁️  Creating Azure cluster on volumes...${NC}"
create_cluster_on_volume "talos-control-plane-4" "azure-cluster" "control-plane"
create_cluster_on_volume "talos-control-plane-5" "azure-cluster" "control-plane"
create_cluster_on_volume "karpenter-worker-3" "azure-cluster" "worker"
create_cluster_on_volume "karpenter-worker-4" "azure-cluster" "worker"

# Create GCP cluster on volumes
echo -e "${CYAN}☁️  Creating GCP cluster on volumes...${NC}"
create_cluster_on_volume "karpenter-worker-5" "gcp-cluster" "control-plane"
create_cluster_on_volume "etcd-1" "gcp-cluster" "etcd"
create_cluster_on_volume "etcd-2" "gcp-cluster" "etcd"
create_cluster_on_volume "etcd-3" "gcp-cluster" "etcd"

# Create IBM cluster on volumes
echo -e "${CYAN}☁️  Creating IBM cluster on volumes...${NC}"
create_cluster_on_volume "etcd-1" "ibm-cluster" "control-plane"
create_cluster_on_volume "etcd-2" "ibm-cluster" "worker"
create_cluster_on_volume "etcd-3" "ibm-cluster" "worker"

# Show cluster status
echo -e "${CYAN}📊 Multi-Cloud Cluster Status:${NC}"
echo ""
echo -e "${YELLOW}Docker Containers:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo -e "${YELLOW}Docker Networks:${NC}"
docker network ls | grep -E "(aws-cluster|azure-cluster|gcp-cluster|ibm-cluster)"

echo ""
echo -e "${YELLOW}Volume Mounts:${NC}"
ls -la /opt/nix-volumes/ | grep -E "(talos-control-plane|karpenter-worker|etcd)"

echo ""
echo -e "${GREEN}🎉 Multi-Cloud Clusters Created on Volumes! 🎉${NC}"
echo ""
echo -e "${CYAN}Cluster Information:${NC}"
echo "• AWS Cluster: 3 control planes + 2 workers on talos-control-plane-1,2,3 and karpenter-worker-1,2"
echo "• Azure Cluster: 2 control planes + 2 workers on talos-control-plane-4,5 and karpenter-worker-3,4"
echo "• GCP Cluster: 1 control plane + 3 etcd on karpenter-worker-5 and etcd-1,2,3"
echo "• IBM Cluster: 1 control plane + 2 workers on etcd-1,2,3"
echo ""
echo -e "${CYAN}Access Commands:${NC}"
echo "• AWS Control Plane: docker exec -it aws-cluster-control-plane bash"
echo "• Azure Control Plane: docker exec -it azure-cluster-control-plane bash"
echo "• GCP Control Plane: docker exec -it gcp-cluster-control-plane bash"
echo "• IBM Control Plane: docker exec -it ibm-cluster-control-plane bash"
echo ""
echo -e "${PURPLE}🚀 Multi-cloud clusters running on encrypted volumes! 🚀${NC}"
