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
