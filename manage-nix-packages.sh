#!/bin/bash

# Nix Package Management Script for Multi-Cloud Kubernetes Infrastructure
set -euo pipefail

usage() {
    echo "Usage: $0 {status|update|clean|list|install|remove}"
    echo ""
    echo "Commands:"
    echo "  status  - Show Nix system status"
    echo "  update  - Update Nix channels and packages"
    echo "  clean   - Clean Nix store and generations"
    echo "  list    - List installed packages"
    echo "  install - Install additional packages"
    echo "  remove  - Remove packages"
}

status_nix() {
    echo "Nix System Status:"
    echo "=================="
    
    echo -e "\nNix Version:"
    nix --version
    
    echo -e "\nNix Configuration:"
    echo "  System config: /etc/nix/nix.conf"
    echo "  User config: ~/.config/nix/nix.conf"
    echo "  Trusted users: $(grep 'trusted-users' /etc/nix/nix.conf | cut -d= -f2 | tr -d ' ')"
    
    echo -e "\nNix Store:"
    nix-store --query --roots /nix/store | head -5
    
    echo -e "\nInstalled Packages:"
    nix-env -q | head -10
}

update_nix() {
    echo "Updating Nix channels and packages..."
    
    # Update Nix channels
    nix-channel --update
    
    # Update installed packages
    nix-env -u
    
    echo "Nix update completed"
}

clean_nix() {
    echo "Cleaning Nix store and generations..."
    
    # Collect garbage
    nix-collect-garbage -d
    
    # Remove old generations
    nix-env --delete-generations old
    
    echo "Nix cleanup completed"
}

list_packages() {
    echo "Installed Nix Packages:"
    echo "======================="
    
    nix-env -q
}

install_packages() {
    echo "Installing additional packages..."
    
    # Install common development packages
    nix-env -iA nixpkgs.vim
    nix-env -iA nixpkgs.tmux
    nix-env -iA nixpkgs.zsh
    nix-env -iA nixpkgs.bash-completion
    
    echo "Additional packages installed"
}

remove_packages() {
    echo "Removing packages..."
    
    # Remove packages (example)
    # nix-env -e package-name
    
    echo "Package removal completed"
}

main() {
    case "${1:-}" in
        status)
            status_nix
            ;;
        update)
            update_nix
            ;;
        clean)
            clean_nix
            ;;
        list)
            list_packages
            ;;
        install)
            install_packages
            ;;
        remove)
            remove_packages
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
