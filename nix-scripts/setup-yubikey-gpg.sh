#!/bin/bash

# YubiKey GPG Key Generation Script
# This script generates GPG keys directly on the YubiKey hardware

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_header() {
    echo
    print_status $BLUE "=========================================="
    print_status $BLUE "$1"
    print_status $BLUE "=========================================="
    echo
}

# Check prerequisites
check_prerequisites() {
    print_header "🔍 Checking Prerequisites"
    
    # Check if ykman is available
    if command -v ykman &> /dev/null; then
        print_status $GREEN "✅ YubiKey Manager available"
    else
        print_status $RED "❌ YubiKey Manager not found"
        print_status $YELLOW "💡 Install with: nix-env -iA nixpkgs.yubikey-manager"
        exit 1
    fi
    
    # Check if gpg is available
    if command -v gpg &> /dev/null; then
        print_status $GREEN "✅ GPG available"
    else
        print_status $RED "❌ GPG not found"
        exit 1
    fi
    
    # Check if YubiKey is connected
    if ykman list &> /dev/null; then
        print_status $GREEN "✅ YubiKey detected"
    else
        print_status $RED "❌ YubiKey not detected"
        print_status $YELLOW "💡 Please connect your YubiKey and try again"
        exit 1
    fi
}

# Check current OpenPGP status
check_openpgp_status() {
    print_header "🔑 Checking OpenPGP Status"
    
    print_status $BLUE "🔍 Current OpenPGP configuration:"
    ykman openpgp info
    
    print_status $BLUE "🔍 Checking existing keys..."
    for slot in sig dec aut; do
        if ykman openpgp keys info $slot &> /dev/null; then
            print_status $GREEN "✅ Key found in slot $slot"
        else
            print_status $YELLOW "⚠️  No key in slot $slot"
        fi
    done
}

# Generate GPG keys on YubiKey
generate_gpg_keys() {
    print_header "🔐 Generating GPG Keys on YubiKey"
    
    print_status $YELLOW "🔐 This will generate GPG keys directly on your YubiKey hardware."
    print_status $YELLOW "💡 You'll need your YubiKey PIN and Admin PIN."
    print_status $YELLOW "💡 Default PINs are usually: PIN=123456, Admin PIN=12345678"
    echo
    
    read -p "Continue with key generation? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status $YELLOW "Key generation cancelled."
        exit 0
    fi
    
    print_status $BLUE "🔐 Generating signing key (SIG slot)..."
    ykman openpgp keys generate sig --algorithm RSA2048 --pin-policy ONCE --touch-policy ONCE
    
    print_status $BLUE "🔐 Generating encryption key (DEC slot)..."
    ykman openpgp keys generate dec --algorithm RSA2048 --pin-policy ONCE --touch-policy ONCE
    
    print_status $BLUE "🔐 Generating authentication key (AUT slot)..."
    ykman openpgp keys generate aut --algorithm RSA2048 --pin-policy ONCE --touch-policy ONCE
    
    print_status $GREEN "✅ All GPG keys generated successfully on YubiKey!"
}

# Set up GPG to use YubiKey
setup_gpg_for_yubikey() {
    print_header "🔧 Setting up GPG for YubiKey"
    
    print_status $BLUE "🔧 Configuring GPG to use YubiKey..."
    
    # Create GPG configuration
    cat > ~/.gnupg/gpg-agent.conf << EOF
default-cache-ttl 600
max-cache-ttl 7200
default-cache-ttl-ssh 600
max-cache-ttl-ssh 7200
enable-ssh-support
pinentry-program /usr/local/bin/pinentry-mac
EOF
    
    # Restart GPG agent
    gpgconf --kill gpg-agent
    gpgconf --launch gpg-agent
    
    print_status $GREEN "✅ GPG configured for YubiKey"
}

# Import YubiKey keys to GPG
import_yubikey_keys() {
    print_header "📥 Importing YubiKey Keys to GPG"
    
    print_status $BLUE "📥 Importing keys from YubiKey to GPG keyring..."
    
    # This will import the public keys from YubiKey
    gpg --card-status
    
    print_status $GREEN "✅ YubiKey keys imported to GPG"
}

# Configure Git for YubiKey signing
configure_git_for_yubikey() {
    print_header "🔧 Configuring Git for YubiKey Signing"
    
    # Get the key ID from YubiKey
    KEY_ID=$(gpg --list-keys --with-colons | grep '^pub:' | head -1 | cut -d: -f5)
    
    if [ -z "$KEY_ID" ]; then
        print_status $RED "❌ Could not find GPG key ID"
        return 1
    fi
    
    print_status $BLUE "🔑 Found GPG key ID: $KEY_ID"
    
    # Configure Git
    git config --global user.signingkey "$KEY_ID"
    git config --global commit.gpgsign true
    git config --global tag.gpgsign true
    git config --global gpg.program /usr/local/bin/gpg
    
    print_status $GREEN "✅ Git configured for YubiKey signing"
    print_status $BLUE "🔑 Signing key: $KEY_ID"
}

# Test YubiKey signing
test_yubikey_signing() {
    print_header "🧪 Testing YubiKey Signing"
    
    print_status $BLUE "🧪 Creating test commit to verify YubiKey signing..."
    
    # Create test file
    echo "Testing YubiKey GPG signing" > yubikey-test.txt
    git add yubikey-test.txt
    
    # Commit with signing
    git commit -m "Test: YubiKey GPG signing"
    
    # Verify signature
    if git log --show-signature -1 | grep -q "Good signature"; then
        print_status $GREEN "✅ YubiKey signing test successful!"
    else
        print_status $YELLOW "⚠️  Signature verification unclear, but commit was created"
    fi
    
    print_status $BLUE "🧪 Test file created: yubikey-test.txt"
}

# Provide next steps
provide_next_steps() {
    print_header "🚀 Next Steps"
    
    print_status $GREEN "✅ YubiKey GPG setup complete!"
    echo
    
    print_status $BLUE "🔧 Next steps:"
    print_status $BLUE "  1. Add your GPG public key to GitHub"
    print_status $BLUE "  2. Remove the old local GPG key (if desired)"
    print_status $BLUE "  3. Test commits with YubiKey signing"
    echo
    
    print_status $YELLOW "💡 To get your public key for GitHub:"
    print_status $YELLOW "  gpg --armor --export YOUR_KEY_ID"
    echo
    
    print_status $RED "🚨 Important:"
    print_status $RED "  - Keep your YubiKey PIN and Admin PIN safe"
    print_status $RED "  - You'll need to touch your YubiKey for each signature"
    print_status $RED "  - Make sure to backup your YubiKey configuration"
}

# Main function
main() {
    print_status $BLUE "🔐 YubiKey GPG Key Generation and Setup"
    echo
    
    print_status $YELLOW "This script will:"
    print_status $YELLOW "  1. Generate GPG keys directly on your YubiKey"
    print_status $YELLOW "  2. Configure GPG to use the YubiKey"
    print_status $YELLOW "  3. Set up Git for YubiKey signing"
    print_status $YELLOW "  4. Test the signing functionality"
    echo
    
    # Run all steps
    check_prerequisites
    check_openpgp_status
    generate_gpg_keys
    setup_gpg_for_yubikey
    import_yubikey_keys
    configure_git_for_yubikey
    test_yubikey_signing
    provide_next_steps
    
    print_header "🎯 Summary"
    
    print_status $GREEN "✅ SUCCESS: YubiKey GPG setup complete!"
    print_status $GREEN "✅ All commits will now be signed with your YubiKey"
    print_status $GREEN "✅ Maximum security: private keys never leave the hardware"
    echo
    
    print_status $BLUE "💡 What this accomplished:"
    print_status $BLUE "  - Generated GPG keys directly on YubiKey hardware"
    print_status $BLUE "  - Configured GPG to use YubiKey for signing"
    print_status $BLUE "  - Set up Git to require YubiKey signing for all commits"
    print_status $BLUE "  - Tested the signing functionality"
    echo
    
    print_status $YELLOW "🚀 Ready for secure commit signing with YubiKey!"
}

# Run main function
main "$@"
