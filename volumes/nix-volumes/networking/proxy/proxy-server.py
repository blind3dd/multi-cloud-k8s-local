#!/usr/bin/env python3

import socket
import threading
import json
import os
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.parse

class ProxyHandler(BaseHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        self.volume_mappings = self.load_volume_mappings()
        super().__init__(*args, **kwargs)
    
    def load_volume_mappings(self):
        """Load volume mappings from configuration files"""
        mappings = {}
        proxy_dir = "/opt/nix-volumes/networking/proxy"
        
        for provider in ["aws", "azure", "gcp", "ibm", "digitalocean"]:
            config_file = f"{proxy_dir}/{provider}-proxy.conf"
            if os.path.exists(config_file):
                with open(config_file, 'r') as f:
                    for line in f:
                        if line.startswith('VOLUME_') and '_PORT=' in line:
                            parts = line.strip().split('=')
                            if len(parts) == 2:
                                volume_key = parts[0].replace('VOLUME_', '').replace('_PORT', '').lower()
                                port = int(parts[1])
                                mappings[port] = {
                                    'volume': volume_key,
                                    'provider': provider
                                }
        return mappings
    
    def do_GET(self):
        """Handle GET requests"""
        self.handle_request()
    
    def do_POST(self):
        """Handle POST requests"""
        self.handle_request()
    
    def do_PUT(self):
        """Handle PUT requests"""
        self.handle_request()
    
    def do_DELETE(self):
        """Handle DELETE requests"""
        self.handle_request()
    
    def handle_request(self):
        """Handle all HTTP requests"""
        try:
            # Parse the request
            parsed_url = urllib.parse.urlparse(self.path)
            path = parsed_url.path
            
            # Check if this is a volume-specific request
            if path.startswith('/volume/'):
                volume_name = path.split('/')[2]
                self.handle_volume_request(volume_name)
            elif path.startswith('/status'):
                self.handle_status_request()
            elif path.startswith('/health'):
                self.handle_health_request()
            else:
                self.handle_general_request()
                
        except Exception as e:
            self.send_error(500, f"Internal Server Error: {str(e)}")
    
    def handle_volume_request(self, volume_name):
        """Handle requests to specific volumes"""
        # Find the volume in mappings
        volume_info = None
        for port, info in self.volume_mappings.items():
            if info['volume'] == volume_name:
                volume_info = info
                break
        
        if not volume_info:
            self.send_error(404, f"Volume {volume_name} not found")
            return
        
        # Forward request to volume (simulate)
        response_data = {
            "volume": volume_name,
            "provider": volume_info['provider'],
            "status": "active",
            "message": f"Request forwarded to {volume_name} in {volume_info['provider']} provider"
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(response_data).encode())
    
    def handle_status_request(self):
        """Handle status requests"""
        status_data = {
            "proxy_server": "active",
            "volumes": len(self.volume_mappings),
            "providers": list(set(info['provider'] for info in self.volume_mappings.values())),
            "mappings": self.volume_mappings
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(status_data, indent=2).encode())
    
    def handle_health_request(self):
        """Handle health check requests"""
        health_data = {
            "status": "healthy",
            "timestamp": str(datetime.now())
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(health_data).encode())
    
    def handle_general_request(self):
        """Handle general requests"""
        response_data = {
            "message": "Multi-Cloud Kubernetes Proxy Server",
            "endpoints": [
                "/status - Get proxy status",
                "/health - Health check",
                "/volume/{volume_name} - Access specific volume"
            ]
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(response_data, indent=2).encode())
    
    def log_message(self, format, *args):
        """Override to reduce log noise"""
        pass

def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    
    server = HTTPServer(('0.0.0.0', port), ProxyHandler)
    print(f"Proxy server starting on port {port}")
    print(f"Volume mappings: {len(ProxyHandler(None, None, None).volume_mappings)}")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down proxy server...")
        server.shutdown()

if __name__ == "__main__":
    from datetime import datetime
    main()
