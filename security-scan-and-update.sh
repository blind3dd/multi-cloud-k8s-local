#!/bin/bash

# Security Scan and Update Script for Multi-Cloud Kubernetes
# This script performs CVE scanning and updates vulnerable components

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_DIR="${SCRIPT_DIR}/security"
LOG_FILE="${SECURITY_DIR}/security-scan-$(date +%Y%m%d-%H%M%S).log"

# Create security directory
mkdir -p "${SECURITY_DIR}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Trivy scanner
install_trivy() {
    if command_exists trivy; then
        log "Trivy is already installed: $(trivy --version)"
        return 0
    fi
    
    log "Installing Trivy vulnerability scanner..."
    
    # Install Trivy on macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command_exists brew; then
            brew install trivy
        else
            # Download and install Trivy manually
            curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
        fi
    else
        # Install on Linux
        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
    fi
    
    log_success "Trivy installed successfully"
}

# Function to scan container images for vulnerabilities
scan_container_images() {
    log "Scanning container images for vulnerabilities..."
    
    local images=(
        "quay.io/cilium/cilium:v1.14.5"
        "gcr.io/istio-release/pilot:latest"
        "gcr.io/istio-release/proxyv2:latest"
    )
    
    for image in "${images[@]}"; do
        log "Scanning image: $image"
        trivy image --format table --output "${SECURITY_DIR}/trivy-$(basename "$image" | tr '/' '_' | tr ':' '_').txt" "$image" || log_warning "Failed to scan $image"
    done
    
    log_success "Container image scanning completed"
}

# Function to scan Kubernetes manifests for security issues
scan_kubernetes_manifests() {
    log "Scanning Kubernetes manifests for security issues..."
    
    # Install kube-score if not present
    if ! command_exists kube-score; then
        log "Installing kube-score..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install kube-score
        else
            curl -L https://github.com/zegl/kube-score/releases/latest/download/kube-score_linux_amd64.tar.gz | tar xvz -C /usr/local/bin
        fi
    fi
    
    # Scan all YAML files
    find "${SCRIPT_DIR}" -name "*.yaml" -type f | while read -r file; do
        log "Scanning manifest: $file"
        kube-score score "$file" --output-format json > "${SECURITY_DIR}/kube-score-$(basename "$file" .yaml).json" 2>/dev/null || log_warning "Failed to scan $file"
    done
    
    log_success "Kubernetes manifest scanning completed"
}

# Function to check for outdated packages
check_outdated_packages() {
    log "Checking for outdated packages..."
    
    local outdated_report="${SECURITY_DIR}/outdated-packages.txt"
    
    echo "# Outdated Packages Report - $(date)" > "$outdated_report"
    echo "" >> "$outdated_report"
    
    # Check kubectl version
    if command_exists kubectl; then
        local kubectl_version=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3)
        echo "kubectl: $kubectl_version" >> "$outdated_report"
    fi
    
    # Check helm version
    if command_exists helm; then
        local helm_version=$(helm version --short 2>/dev/null | cut -d'+' -f1)
        echo "helm: $helm_version" >> "$outdated_report"
    fi
    
    # Check containerd version
    if command_exists containerd; then
        local containerd_version=$(containerd --version 2>/dev/null | cut -d' ' -f3)
        echo "containerd: $containerd_version" >> "$outdated_report"
    fi
    
    # Check runc version
    if command_exists runc; then
        local runc_version=$(runc --version 2>/dev/null | head -1 | cut -d' ' -f3)
        echo "runc: $runc_version" >> "$outdated_report"
    fi
    
    log_success "Package version check completed"
}

# Function to update Kubernetes components
update_kubernetes_components() {
    log "Updating Kubernetes components..."
    
    # Update kubectl to latest version
    if command_exists kubectl; then
        log "Updating kubectl..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
            chmod +x kubectl
            sudo mv kubectl /usr/local/bin/
        else
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            chmod +x kubectl
            sudo mv kubectl /usr/local/bin/
        fi
        log_success "kubectl updated to: $(kubectl version --client --short 2>/dev/null | cut -d' ' -f3)"
    fi
    
    # Update helm
    if command_exists helm; then
        log "Updating helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        log_success "helm updated to: $(helm version --short 2>/dev/null | cut -d'+' -f1)"
    fi
}

# Function to update cluster configurations
update_cluster_configurations() {
    log "Updating cluster configurations to latest Kubernetes version..."
    
    local latest_k8s_version=$(curl -s https://dl.k8s.io/release/stable.txt | sed 's/v//')
    log "Latest Kubernetes version: $latest_k8s_version"
    
    # Update all cluster YAML files
    find "${SCRIPT_DIR}" -name "*-cluster.yaml" -type f | while read -r file; do
        log "Updating Kubernetes version in: $file"
        sed -i.bak "s/version: v1\.28\.0/version: v$latest_k8s_version/g" "$file"
        sed -i.bak "s/kubernetesVersion: v1\.28\.0/kubernetesVersion: v$latest_k8s_version/g" "$file"
    done
    
    # Update Cilium configuration
    if [[ -f "${SCRIPT_DIR}/cilium-config.yaml" ]]; then
        log "Updating Cilium configuration..."
        # Get latest Cilium version
        local latest_cilium=$(curl -s https://api.github.com/repos/cilium/cilium/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
        sed -i.bak "s|quay.io/cilium/cilium:v1\.14\.5|quay.io/cilium/cilium:$latest_cilium|g" "${SCRIPT_DIR}/cilium-config.yaml"
        log_success "Cilium updated to: $latest_cilium"
    fi
    
    log_success "Cluster configurations updated"
}

# Function to generate security report
generate_security_report() {
    log "Generating comprehensive security report..."
    
    local report_file="${SECURITY_DIR}/security-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# Security Scan Report - $(date)

## Executive Summary
This report contains the results of automated security scanning and vulnerability assessment for the Multi-Cloud Kubernetes project.

## Scan Results

### Container Image Vulnerabilities
EOF

    # Add Trivy scan results
    if [[ -d "${SECURITY_DIR}" ]]; then
        find "${SECURITY_DIR}" -name "trivy-*.txt" -type f | while read -r file; do
            echo "### $(basename "$file" .txt)" >> "$report_file"
            echo '```' >> "$report_file"
            cat "$file" >> "$report_file"
            echo '```' >> "$report_file"
            echo "" >> "$report_file"
        done
    fi

    cat >> "$report_file" << EOF

### Kubernetes Manifest Security Issues
EOF

    # Add kube-score results
    if [[ -d "${SECURITY_DIR}" ]]; then
        find "${SECURITY_DIR}" -name "kube-score-*.json" -type f | while read -r file; do
            echo "### $(basename "$file" .json)" >> "$report_file"
            echo '```json' >> "$report_file"
            cat "$file" >> "$report_file"
            echo '```' >> "$report_file"
            echo "" >> "$report_file"
        done
    fi

    cat >> "$report_file" << EOF

### Package Versions
EOF

    if [[ -f "${SECURITY_DIR}/outdated-packages.txt" ]]; then
        echo '```' >> "$report_file"
        cat "${SECURITY_DIR}/outdated-packages.txt" >> "$report_file"
        echo '```' >> "$report_file"
    fi

    cat >> "$report_file" << EOF

## Recommendations

1. **Immediate Actions Required:**
   - Review and address all HIGH and CRITICAL vulnerabilities
   - Update Kubernetes to latest stable version
   - Update container runtime components

2. **Medium Priority:**
   - Update Cilium CNI to latest version
   - Review and update network policies
   - Implement runtime security monitoring

3. **Long-term:**
   - Establish regular security scanning procedures
   - Implement automated vulnerability management
   - Create security update policies

## Next Steps

1. Review this report with the security team
2. Prioritize vulnerabilities based on risk assessment
3. Create remediation timeline
4. Implement monitoring and alerting

---
*Report generated by security-scan-and-update.sh on $(date)*
EOF

    log_success "Security report generated: $report_file"
}

# Main execution
main() {
    log "Starting security scan and update process..."
    
    # Install required tools
    install_trivy
    
    # Perform security scans
    scan_container_images
    scan_kubernetes_manifests
    check_outdated_packages
    
    # Ask user if they want to proceed with updates
    echo ""
    log_warning "Security scan completed. Review the results before proceeding with updates."
    read -p "Do you want to proceed with updating components? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        update_kubernetes_components
        update_cluster_configurations
        log_success "Updates completed successfully"
    else
        log "Updates skipped. You can run this script again to perform updates."
    fi
    
    # Generate final report
    generate_security_report
    
    log_success "Security scan and update process completed!"
    log "Results saved in: ${SECURITY_DIR}"
}

# Run main function
main "$@"
