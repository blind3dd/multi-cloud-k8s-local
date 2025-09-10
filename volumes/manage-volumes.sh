#!/bin/bash

BASE_DIR="/opt/nix-volumes"

usage() {
    echo "Usage: $0 {mount-all|unmount-all|status|shell <node-name>}"
    echo ""
    echo "Commands:"
    echo "  mount-all    - Mount all encrypted volumes"
    echo "  unmount-all  - Unmount all encrypted volumes"
    echo "  status       - Show status of all volumes"
    echo "  shell <node> - Open shell in specific node volume"
}

mount_all() {
    echo "Mounting all volumes..."
    for volume_dir in "$BASE_DIR"/*/; do
        if [ -d "$volume_dir" ]; then
            node_name=$(basename "$volume_dir")
            if [ -f "$volume_dir/$node_name.passphrase" ]; then
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
    bash
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
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
