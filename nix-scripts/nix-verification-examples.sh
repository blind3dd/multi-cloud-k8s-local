#!/bin/bash

# Nix Package Install and Verify Examples
# This script shows how to use the generic install and verify script for different packages

echo "🔍 Nix Package Install and Verify Examples"
echo "=========================================="
echo

echo "📦 Security-related packages:"
echo "  ./nix-install-and-verify.sh pinentry-mac pinentry_mac"
echo "  ./nix-install-and-verify.sh yubikey-manager yubikey-manager"
echo "  ./nix-install-and-verify.sh gnupg gnupg"
echo "  ./nix-install-and-verify.sh openssl openssl"
echo

echo "🛠️  Development tools:"
echo "  ./nix-install-and-verify.sh git git"
echo "  ./nix-install-and-verify.sh curl curl"
echo "  ./nix-install-and-verify.sh jq jq"
echo "  ./nix-install-and-verify.sh nodejs nodejs"
echo

echo "🔧 System utilities:"
echo "  ./nix-install-and-verify.sh rsync rsync"
echo "  ./nix-install-and-verify.sh wget wget"
echo "  ./nix-install-and-verify.sh tree tree"
echo "  ./nix-install-and-verify.sh htop htop"
echo

echo "📚 Usage:"
echo "  ./nix-install-and-verify.sh <package-name> [package-attribute]"
echo
echo "  Where:"
echo "    package-name: The name you want to use for the package"
echo "    package-attribute: The Nix attribute name (usually same as package-name)"
echo
echo "  Examples:"
echo "    ./nix-package-verification.sh pinentry-mac pinentry_mac"
echo "    ./nix-package-verification.sh yubikey-manager yubikey-manager"
echo "    ./nix-package-verification.sh git git"
echo

echo "🔍 To find available packages:"
echo "  nix-env -qaP | grep <search-term>"
echo "  nix search nixpkgs <package-name>"
echo

echo "📋 The script will:"
echo "  1. Check Nix availability"
echo "  2. Start Nix daemon if needed"
echo "  3. Install the package"
echo "  4. Verify package integrity"
echo "  5. Show derivation details"
echo "  6. Display dependency tree"
echo "  7. Calculate checksums"
echo "  8. Verify binary properties"
echo "  9. Provide security assessment"
echo "  10. ROLLBACK if any verification fails"
echo "  11. Clean up resources"
echo

echo "✅ All packages verified through this script are cryptographically"
echo "   verified and safe to use."
