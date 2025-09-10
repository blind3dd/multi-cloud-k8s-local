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
