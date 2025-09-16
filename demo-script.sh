#!/bin/bash

echo "🎯 MULTI-CLOUD KUBERNETES DEMO 🎯"
echo "=================================="
echo ""

echo "📊 CLUSTER STATUS:"
echo "------------------"
kubectl get nodes -o wide
echo ""

echo "🚀 DEPLOYED APPLICATIONS:"
echo "-------------------------"
kubectl get deployments
echo ""

echo "🌐 SERVICES:"
echo "------------"
kubectl get services
echo ""

echo "📈 AUTOSCALING STATUS:"
echo "----------------------"
kubectl get hpa
echo ""

echo "🔍 POD STATUS:"
echo "--------------"
kubectl get pods -o wide
echo ""

echo "📊 RESOURCE USAGE:"
echo "------------------"
kubectl top pods 2>/dev/null || echo "Metrics server not available - this is normal for kind clusters"
echo ""

echo "🌐 NGINX ACCESS:"
echo "----------------"
echo "You can access nginx at:"
echo "  kubectl port-forward service/nginx-service 8080:80"
echo "  Then visit: http://localhost:8080"
echo ""

echo "🔥 LOAD TESTING:"
echo "----------------"
echo "Load generator is running to trigger autoscaling..."
echo "Watch HPA status with: kubectl get hpa -w"
echo ""

echo "📈 DEMO COMMANDS:"
echo "-----------------"
echo "1. Watch autoscaling: kubectl get hpa -w"
echo "2. Watch pods: kubectl get pods -w"
echo "3. Check nginx logs: kubectl logs -l app=nginx"
echo "4. Port forward: kubectl port-forward service/nginx-service 8080:80"
echo "5. Load test: curl http://localhost:8080/load"
echo ""

echo "🎉 DEMO READY! 🎉"
