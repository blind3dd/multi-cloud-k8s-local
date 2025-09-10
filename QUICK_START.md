# Quick Start Guide

## One-Command Setup

To set up the entire multi-cloud Kubernetes infrastructure:

```bash
./setup-main.sh
```

This single command will:

1. **Check Prerequisites** - Verify macOS and required tools
2. **Setup Nix** - Install and configure Nix package manager
3. **Create Volumes** - Create 13 encrypted volumes for Kubernetes nodes
4. **Configure Volumes** - Install Nix users and Kubernetes tools in each volume
5. **Setup Container Runtime** - Configure containerd and crictl
6. **Setup macOS Networking** - Configure network interfaces and routing
7. **Setup Proxy Networking** - Create proxy server for cross-cloud simulation
8. **Setup Cross-Cloud Networking** - Configure Cilium, Istio, and WireGuard
9. **Deploy CAPI** - Set up Cluster API for orchestration
10. **Verify Setup** - Check all components are ready
11. **Display Next Steps** - Show you how to deploy clusters

## What You Get

- **3 etcd nodes** (Flatcar base OS)
- **5 Talos control plane nodes** (immutable OS)  
- **5 Karpenter worker nodes** (auto-scaling)
- **Cross-cloud networking** (proxy + Cilium CNI)
- **CAPI orchestration** (Cluster API)
- **Security stack** (External Secrets, Istio, WireGuard)

## After Setup

1. **Start the proxy server:**
   ```bash
   sudo volumes/networking/proxy/manage-simple-proxy.sh start
   ```

2. **Initialize CAPI:**
   ```bash
   volumes/capi-management/init-capi.sh
   ```

3. **Deploy your first cluster:**
   ```bash
   volumes/capi-management/manage-capi.sh deploy aws
   ```

## Management Scripts

- `volumes/manage-volumes.sh` - Volume management
- `volumes/manage-container-runtime.sh` - Container runtime
- `volumes/networking/manage-networking.sh` - Networking
- `volumes/capi-management/manage-capi.sh` - CAPI management

## Documentation

- `README.md` - Project overview
- `volumes/networking/architecture.md` - Networking architecture
- `volumes/capi-management/capi-architecture.md` - CAPI architecture

## Troubleshooting

Check the log file: `setup-main.log`

For individual component issues, run the specific setup scripts:
- `./setup-nix-complete.sh`
- `./create-volumes-simple.sh`
- `./configure-volumes.sh`
- `./setup-container-runtime.sh`
- `./setup-macos-networking.sh`
- `./setup-simple-proxy.sh`
- `./setup-cross-cloud-networking.sh`
- `./deploy-capi-simple.sh`
