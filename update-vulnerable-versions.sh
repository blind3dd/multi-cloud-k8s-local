#!/bin/bash

# Update Vulnerable Versions Script
# This script updates specific vulnerable versions identified in the CVE analysis

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

# Target versions for updates
KUBERNETES_VERSION="v1.31.0"  # Latest stable as of 2024
CILIUM_VERSION="v1.15.0"      # Latest stable Cilium
CONTAINERD_VERSION="v2.1.5"   # Latest containerd
RUNC_VERSION="v1.3.1"         # Latest runc
CRICTL_VERSION="v1.32.1"      # Latest crictl
CNI_PLUGINS_VERSION="v1.4.2"  # Latest CNI plugins

# Function to backup files before modification
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d-%H%M%S)"
        log "Backed up: $file"
    fi
}

# Function to update Kubernetes version in cluster configurations
update_kubernetes_version() {
    log "Updating Kubernetes version from v1.28.0 to $KUBERNETES_VERSION..."
    
    local files_to_update=(
        "aws-cluster.yaml"
        "azure-cluster.yaml"
        "gcp-cluster.yaml"
        "ibm-cluster.yaml"
        "digitalocean-cluster.yaml"
        "multi-cloud-clusters.yaml"
        "aws-cluster-fixed.yaml"
        "working-cluster.yaml"
        "docker-cluster.yaml"
        "docker-cluster-fixed.yaml"
        "setup-kubeconfig.sh"
    )
    
    for file in "${files_to_update[@]}"; do
        local file_path="${SCRIPT_DIR}/${file}"
        if [[ -f "$file_path" ]]; then
            backup_file "$file_path"
            
            # Update version fields
            sed -i.tmp "s/version: v1\.28\.0/version: $KUBERNETES_VERSION/g" "$file_path"
            sed -i.tmp "s/kubernetesVersion: v1\.28\.0/kubernetesVersion: $KUBERNETES_VERSION/g" "$file_path"
            sed -i.tmp "s/kubernetesVersion: \"v1\.28\.0\"/kubernetesVersion: \"$KUBERNETES_VERSION\"/g" "$file_path"
            
            rm -f "${file_path}.tmp"
            log_success "Updated Kubernetes version in: $file"
        else
            log_warning "File not found: $file"
        fi
    done
}

# Function to update Cilium version
update_cilium_version() {
    log "Updating Cilium version to $CILIUM_VERSION..."
    
    local cilium_config="${SCRIPT_DIR}/cilium-config.yaml"
    if [[ -f "$cilium_config" ]]; then
        backup_file "$cilium_config"
        
        # Update Cilium image version
        sed -i.tmp "s|quay.io/cilium/cilium:v1\.14\.5|quay.io/cilium/cilium:$CILIUM_VERSION|g" "$cilium_config"
        
        rm -f "${cilium_config}.tmp"
        log_success "Updated Cilium version in cilium-config.yaml"
    else
        log_warning "Cilium configuration file not found"
    fi
}

# Function to update container runtime versions in setup scripts
update_container_runtime_versions() {
    log "Updating container runtime versions..."
    
    local setup_script="${SCRIPT_DIR}/setup-container-runtime.sh"
    if [[ -f "$setup_script" ]]; then
        backup_file "$setup_script"
        
        # Update containerd version
        sed -i.tmp "s/containerd-2\.1\.4/containerd-${CONTAINERD_VERSION#v}/g" "$setup_script"
        sed -i.tmp "s/v2\.1\.4/${CONTAINERD_VERSION#v}/g" "$setup_script"
        
        # Update runc version
        sed -i.tmp "s/runc\.amd64.*v1\.3\.0/runc.amd64-${RUNC_VERSION#v}/g" "$setup_script"
        sed -i.tmp "s/v1\.3\.0/${RUNC_VERSION#v}/g" "$setup_script"
        
        # Update crictl version
        sed -i.tmp "s/crictl-v1\.32\.0/crictl-${CRICTL_VERSION#v}/g" "$setup_script"
        sed -i.tmp "s/v1\.32\.0/${CRICTL_VERSION#v}/g" "$setup_script"
        
        # Update CNI plugins version
        sed -i.tmp "s/cni-plugins-linux-amd64-v1\.4\.1/cni-plugins-linux-amd64-${CNI_PLUGINS_VERSION#v}/g" "$setup_script"
        sed -i.tmp "s/v1\.4\.1/${CNI_PLUGINS_VERSION#v}/g" "$setup_script"
        
        rm -f "${setup_script}.tmp"
        log_success "Updated container runtime versions in setup-container-runtime.sh"
    else
        log_warning "Container runtime setup script not found"
    fi
}

# Function to update documentation with new versions
update_documentation() {
    log "Updating documentation with new versions..."
    
    local docs_to_update=(
        "README.md"
        "MULTI_CLOUD_K8S_SETUP_SUMMARY.md"
    )
    
    for doc in "${docs_to_update[@]}"; do
        local doc_path="${SCRIPT_DIR}/${doc}"
        if [[ -f "$doc_path" ]]; then
            backup_file "$doc_path"
            
            # Update Kubernetes version
            sed -i.tmp "s/kubectl.*: v1\.33\.4/kubectl: $(curl -s https://dl.k8s.io/release/stable.txt)/g" "$doc_path"
            sed -i.tmp "s/version: v1\.28\.0/version: $KUBERNETES_VERSION/g" "$doc_path"
            
            # Update container runtime versions
            sed -i.tmp "s/containerd.*: v2\.1\.4/containerd: $CONTAINERD_VERSION/g" "$doc_path"
            sed -i.tmp "s/runc.*: v1\.3\.0/runc: $RUNC_VERSION/g" "$doc_path"
            sed -i.tmp "s/crictl.*: v1\.32\.0/crictl: $CRICTL_VERSION/g" "$doc_path"
            sed -i.tmp "s/CNI plugins.*: v1\.4\.1/CNI plugins: $CNI_PLUGINS_VERSION/g" "$doc_path"
            
            rm -f "${doc_path}.tmp"
            log_success "Updated versions in: $doc"
        else
            log_warning "Documentation file not found: $doc"
        fi
    done
}

# Function to create version update summary
create_update_summary() {
    log "Creating update summary..."
    
    local summary_file="${SCRIPT_DIR}/VERSION_UPDATE_SUMMARY.md"
    
    cat > "$summary_file" << EOF
# Version Update Summary

## Updated Components

### Kubernetes
- **Previous**: v1.28.0
- **Updated**: $KUBERNETES_VERSION
- **Reason**: Security vulnerabilities in v1.28.0

### Container Runtime
- **containerd**: $CONTAINERD_VERSION (was v2.1.4)
- **runc**: $RUNC_VERSION (was v1.3.0)
- **crictl**: $CRICTL_VERSION (was v1.32.0)
- **CNI plugins**: $CNI_PLUGINS_VERSION (was v1.4.1)

### Networking
- **Cilium**: $CILIUM_VERSION (was v1.14.5)

## Files Modified

### Cluster Configurations
- aws-cluster.yaml
- azure-cluster.yaml
- gcp-cluster.yaml
- ibm-cluster.yaml
- digitalocean-cluster.yaml
- multi-cloud-clusters.yaml
- aws-cluster-fixed.yaml
- working-cluster.yaml
- docker-cluster.yaml
- docker-cluster-fixed.yaml

### Setup Scripts
- setup-container-runtime.sh
- setup-kubeconfig.sh

### Configuration Files
- cilium-config.yaml

### Documentation
- README.md
- MULTI_CLOUD_K8S_SETUP_SUMMARY.md

## Security Improvements

1. **Kubernetes v1.31.0**: Addresses multiple CVEs from v1.28.0
2. **Container Runtime Updates**: Latest security patches
3. **Cilium Update**: Latest network security features
4. **CNI Plugins**: Latest network plugin security fixes

## Next Steps

1. **Test Updated Configurations**: Verify all cluster configurations work with new versions
2. **Update Deployment Scripts**: Ensure deployment scripts are compatible
3. **Security Scanning**: Run security scans to verify vulnerabilities are addressed
4. **Documentation Review**: Update any additional documentation references

## Backup Files

All original files have been backed up with timestamp suffixes. Backup files can be found with the pattern: \`*.backup.YYYYMMDD-HHMMSS\`

---
*Update performed on $(date)*
EOF

    log_success "Update summary created: $summary_file"
}

# Function to validate updates
validate_updates() {
    log "Validating updates..."
    
    local validation_errors=0
    
    # Check if Kubernetes version was updated
    if grep -r "version: v1\.28\.0" "${SCRIPT_DIR}" --include="*.yaml" >/dev/null 2>&1; then
        log_error "Some files still contain old Kubernetes version v1.28.0"
        ((validation_errors++))
    fi
    
    # Check if Cilium version was updated
    if grep -r "cilium:v1\.14\.5" "${SCRIPT_DIR}" --include="*.yaml" >/dev/null 2>&1; then
        log_error "Some files still contain old Cilium version v1.14.5"
        ((validation_errors++))
    fi
    
    if [[ $validation_errors -eq 0 ]]; then
        log_success "All updates validated successfully"
        return 0
    else
        log_error "Validation failed with $validation_errors errors"
        return 1
    fi
}

# Main execution
main() {
    log "Starting version update process..."
    
    # Confirm with user
    echo ""
    log_warning "This will update vulnerable versions in your project."
    log_warning "Backup files will be created before modifications."
    echo ""
    read -p "Do you want to proceed? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Update cancelled by user"
        exit 0
    fi
    
    # Perform updates
    update_kubernetes_version
    update_cilium_version
    update_container_runtime_versions
    update_documentation
    
    # Validate updates
    if validate_updates; then
        create_update_summary
        log_success "Version update process completed successfully!"
        log "Review the VERSION_UPDATE_SUMMARY.md file for details"
    else
        log_error "Update validation failed. Please review the errors above."
        exit 1
    fi
}

# Run main function
main "$@"
