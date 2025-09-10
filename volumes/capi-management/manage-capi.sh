#!/bin/bash

# CAPI Management Script
set -euo pipefail

CAPI_DIR="/opt/nix-volumes/capi-management"

usage() {
    echo "Usage: $0 {init|deploy|status|delete|help}"
    echo ""
    echo "Commands:"
    echo "  init    - Initialize CAPI with all providers"
    echo "  deploy  - Deploy clusters for all providers"
    echo "  status  - Show cluster status"
    echo "  delete  - Delete all clusters"
    echo "  help    - Show this help message"
}

init_capi() {
    echo "Initializing CAPI..."
    "$CAPI_DIR/init-capi.sh"
}

deploy_clusters() {
    echo "Deploying multi-cloud clusters..."
    
    echo "Deploying AWS cluster..."
    kubectl apply -f "$CAPI_DIR/aws-cluster.yaml"
    
    echo "Deploying Azure cluster..."
    kubectl apply -f "$CAPI_DIR/azure-cluster.yaml"
    
    echo "Deploying GCP cluster..."
    kubectl apply -f "$CAPI_DIR/gcp-cluster.yaml"
    
    echo "Deploying Talos cluster..."
    kubectl apply -f "$CAPI_DIR/talos-cluster.yaml"
    
    echo "All clusters deployed"
}

status_clusters() {
    echo "Multi-Cloud Cluster Status:"
    echo "=========================="
    
    echo -e "\nCAPI Resources:"
    kubectl get clusters
    kubectl get machines
    kubectl get machinedeployments
    
    echo -e "\nProvider Resources:"
    kubectl get awsclusters
    kubectl get azureclusters
    kubectl get gcpclusters
    kubectl get talosclusters
    
    echo -e "\nControl Planes:"
    kubectl get kubeadmcontrolplanes
    kubectl get taloscontrolplanes
}

delete_clusters() {
    echo "Deleting all clusters..."
    
    kubectl delete -f "$CAPI_DIR/talos-cluster.yaml" || true
    kubectl delete -f "$CAPI_DIR/gcp-cluster.yaml" || true
    kubectl delete -f "$CAPI_DIR/azure-cluster.yaml" || true
    kubectl delete -f "$CAPI_DIR/aws-cluster.yaml" || true
    
    echo "All clusters deleted"
}

main() {
    case "${1:-}" in
        init)
            init_capi
            ;;
        deploy)
            deploy_clusters
            ;;
        status)
            status_clusters
            ;;
        delete)
            delete_clusters
            ;;
        help|*)
            usage
            exit 1
            ;;
    esac
}

main "$@"
