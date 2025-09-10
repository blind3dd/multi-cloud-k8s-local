# Simple Proxy-Based Networking Architecture

## Overview

This implementation uses a simple HTTP proxy server to enable communication between mounted volumes and localhost, providing a reliable networking solution for macOS.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Simple Proxy Network Stack                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                Simple Proxy Server                     │   │
│  │                   Port: 8000                           │   │
│  │                                                         │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │   │
│  │  │/status      │  │/health      │  │/volume/*    │    │   │
│  │  │             │  │             │  │             │    │   │
│  │  │Get proxy    │  │Health check │  │Access       │    │   │
│  │  │status and   │  │endpoint     │  │specific     │    │   │
│  │  │volume list  │  │             │  │volumes      │    │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                Volume Configurations                   │   │
│  │                                                         │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │   │
│  │  │   etcd-1    │  │   etcd-2    │  │   etcd-3    │    │   │
│  │  │             │  │             │  │             │    │   │
│  │  │/etc/proxy/  │  │/etc/proxy/  │  │/etc/proxy/  │    │   │
│  │  │proxy.conf   │  │proxy.conf   │  │proxy.conf   │    │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘    │   │
│  │                                                         │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │   │
│  │  │talos-cp-1   │  │talos-cp-2   │  │talos-cp-3   │    │   │
│  │  │             │  │             │  │             │    │   │
│  │  │/etc/proxy/  │  │/etc/proxy/  │  │/etc/proxy/  │    │   │
│  │  │proxy.conf   │  │proxy.conf   │  │proxy.conf   │    │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### Simple Proxy Server (Port 8000)
- **Purpose**: Central proxy server for all volume communication
- **Endpoints**:
  - `/status` - Get proxy status and volume list
  - `/health` - Health check endpoint
  - `/volume/{volume_name}` - Access specific volume
- **Function**: Routes requests to appropriate volumes

### Volume Proxy Configurations
- **Location**: `/etc/proxy/proxy.conf` in each volume
- **Settings**: Proxy endpoints, health checks, status endpoints
- **Management**: Volume-specific proxy management scripts

## Communication Flow

### Volume to Volume Communication
```
Volume A -> Simple Proxy (8000) -> Volume B
```

### Volume to Localhost Communication
```
Volume A -> Simple Proxy (8000) -> Localhost Services
```

### Cross-Provider Communication
```
Volume A (AWS) -> Simple Proxy (8000) -> Volume B (Azure)
```

## Management Commands

```bash
# Start proxy server
/opt/nix-volumes/networking/proxy/manage-simple-proxy.sh start

# Stop proxy server
/opt/nix-volumes/networking/proxy/manage-simple-proxy.sh stop

# Check proxy status
/opt/nix-volumes/networking/proxy/manage-simple-proxy.sh status

# Restart proxy server
/opt/nix-volumes/networking/proxy/manage-simple-proxy.sh restart

# Test proxy connectivity
/opt/nix-volumes/networking/proxy/manage-simple-proxy.sh test
```

## Volume-Specific Commands

```bash
# Test proxy connection for specific volume
/opt/proxy-manager.sh test

# Show proxy information for specific volume
/opt/proxy-manager.sh info
```

## Benefits

- **Simple**: Single proxy server for all communication
- **Reliable**: HTTP-based communication that works across platforms
- **Manageable**: Centralized proxy management
- **Cross-Platform**: Works on macOS, Linux, and other platforms
- **Debuggable**: HTTP endpoints for easy testing and debugging
- **Lightweight**: Minimal resource usage

## Security Features

- **Centralized Control**: Single point of access control
- **Logging**: All requests are logged for audit purposes
- **Health Checks**: Regular health monitoring
- **Access Control**: Can be extended with authentication
