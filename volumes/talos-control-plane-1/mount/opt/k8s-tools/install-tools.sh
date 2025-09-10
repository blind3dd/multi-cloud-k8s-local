#!/bin/bash

# Install Kubernetes tools for talos-control-plane-1 (aws, talos)
set -euo pipefail

echo "Installing Kubernetes tools for talos-control-plane-1..."

# Install base Kubernetes tools
nix-env -iA nixpkgs.kubectl
nix-env -iA nixpkgs.kubeadm
nix-env -iA nixpkgs.kubelet
nix-env -iA nixpkgs.etcd
nix-env -iA nixpkgs.containerd
nix-env -iA nixpkgs.runc
nix-env -iA nixpkgs.cni

# Install provider-specific tools
case "aws" in
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
if [[ "talos" == "talos" ]]; then
    echo "Installing Talos tools..."
    nix-env -iA nixpkgs.talosctl
    nix-env -iA nixpkgs.cosign
    nix-env -iA nixpkgs.syft
fi

# Install Karpenter tools for worker nodes
if [[ "talos-control-plane-1" == karpenter-worker-* ]]; then
    echo "Installing Karpenter tools..."
    nix-env -iA nixpkgs.karpenter
fi

echo "Kubernetes tools installed for talos-control-plane-1"
