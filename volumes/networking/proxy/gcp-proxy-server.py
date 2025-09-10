#!/usr/bin/env python3

import socket
import threading
import json
import os
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.parse

class UgcpProxyHandler(BaseHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        self.provider = "gcp"
        self.base_port = 8082
        super().__init__(*args, **kwargs)
    
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
            else:
                self.handle_general_request()
                
        except Exception as e:
            self.send_error(500, f"Internal Server Error: {str(e)}")
    
    def handle_volume_request(self, volume_name):
        response_data = {
            "volume": volume_name,
            "provider": self.provider,
            "port": self.base_port,
            "status": "active",
            "message": f"Request to {volume_name} in {self.provider} provider"
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(response_data).encode())
    
    def handle_status_request(self):
        status_data = {
            "provider": self.provider,
            "base_port": self.base_port,
            "status": "active"
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(status_data).encode())
    
    def handle_general_request(self):
        response_data = {
            "provider": self.provider,
            "base_port": self.base_port,
            "message": f"{self.provider} provider proxy server"
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(response_data).encode())
    
    def log_message(self, format, *args):
        pass

def main():
    port = 8082
    
    server = HTTPServer(('0.0.0.0', port), UgcpProxyHandler)
    print(f"gcp proxy server starting on port {port}")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print(f"\nShutting down gcp proxy server...")
        server.shutdown()

if __name__ == "__main__":
    main()
