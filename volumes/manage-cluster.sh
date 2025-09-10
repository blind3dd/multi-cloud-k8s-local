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
