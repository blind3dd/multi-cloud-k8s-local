#!/usr/bin/env python3

import json
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.parse

class SimpleProxyHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.handle_request()
    
    def do_POST(self):
        self.handle_request()
    
    def handle_request(self):
        try:
            parsed_url = urllib.parse.urlparse(self.path)
            path = parsed_url.path
            
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
        response_data = {
            "volume": volume_name,
            "status": "active",
            "message": f"Request to {volume_name} processed"
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(response_data).encode())
    
    def handle_status_request(self):
        status_data = {
            "proxy_server": "active",
            "volumes": ["etcd-1", "etcd-2", "etcd-3", "talos-control-plane-1", "talos-control-plane-2", "talos-control-plane-3", "talos-control-plane-4", "talos-control-plane-5", "karpenter-worker-1", "karpenter-worker-2", "karpenter-worker-3", "karpenter-worker-4", "karpenter-worker-5"],
            "providers": ["aws", "azure", "gcp", "ibm", "digitalocean"]
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(status_data, indent=2).encode())
    
    def handle_health_request(self):
        health_data = {
            "status": "healthy",
            "timestamp": "2025-09-10T04:40:00Z"
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(health_data).encode())
    
    def handle_general_request(self):
        response_data = {
            "message": "Multi-Cloud Kubernetes Simple Proxy Server",
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
        pass

def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    
    server = HTTPServer(('0.0.0.0', port), SimpleProxyHandler)
    print(f"Simple proxy server starting on port {port}")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down simple proxy server...")
        server.shutdown()

if __name__ == "__main__":
    main()
