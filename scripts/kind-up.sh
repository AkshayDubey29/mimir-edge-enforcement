#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up Mimir Edge Enforcement development environment...${NC}"

# Check if kind is installed
if ! command -v kind &> /dev/null; then
    echo -e "${RED}kind is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${RED}helm is not installed. Please install it first.${NC}"
    exit 1
fi

# Create kind cluster
echo -e "${YELLOW}Creating kind cluster...${NC}"
kind create cluster --name mimir-edge --config scripts/kind-config.yaml

# Wait for cluster to be ready
echo -e "${YELLOW}Waiting for cluster to be ready...${NC}"
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Install NGINX Ingress Controller
echo -e "${YELLOW}Installing NGINX Ingress Controller...${NC}"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s

# Install Prometheus Operator (optional)
echo -e "${YELLOW}Installing Prometheus Operator...${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace \
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
    --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false

# Create namespace for Mimir Edge Enforcement
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl create namespace mimir-edge-enforcement --dry-run=client -o yaml | kubectl apply -f -

# Deploy mock Mimir distributor for testing
echo -e "${YELLOW}Deploying mock Mimir distributor...${NC}"
kubectl apply -f examples/mock-mimir.yaml

# Build and deploy components
echo -e "${YELLOW}Building components...${NC}"
make build-images

# Load images into kind cluster
echo -e "${YELLOW}Loading images into kind cluster...${NC}"
kind load docker-image ghcr.io/AkshayDubey29/mimir-rls:latest --name mimir-edge
kind load docker-image ghcr.io/AkshayDubey29/overrides-sync:latest --name mimir-edge
kind load docker-image ghcr.io/AkshayDubey29/mimir-envoy:latest --name mimir-edge
kind load docker-image ghcr.io/AkshayDubey29/mimir-edge-admin:latest --name mimir-edge

# Deploy using Helm
echo -e "${YELLOW}Deploying with Helm...${NC}"
helm install mimir-rls charts/mimir-rls/ -f examples/values/dev.yaml -n mimir-edge-enforcement
helm install mimir-envoy charts/envoy/ -f examples/values/dev.yaml -n mimir-edge-enforcement
helm install overrides-sync charts/overrides-sync/ -f examples/values/dev.yaml -n mimir-edge-enforcement

# Wait for deployments to be ready
echo -e "${YELLOW}Waiting for deployments to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/mimir-rls -n mimir-edge-enforcement
kubectl wait --for=condition=available --timeout=300s deployment/mimir-envoy -n mimir-edge-enforcement
kubectl wait --for=condition=available --timeout=300s deployment/overrides-sync -n mimir-edge-enforcement

# Port forward for easy access
echo -e "${GREEN}Setup complete!${NC}"
echo -e "${YELLOW}To access the Admin UI:${NC}"
echo "kubectl port-forward svc/mimir-rls 8080:8082 -n mimir-edge-enforcement"
echo "Then open http://localhost:8080 in your browser"
echo ""
echo -e "${YELLOW}To access the mock Mimir distributor:${NC}"
echo "kubectl port-forward svc/mock-mimir-distributor 8081:8080 -n mimir"
echo ""
echo -e "${YELLOW}To run load tests:${NC}"
echo "make load-test"
echo ""
echo -e "${YELLOW}To clean up:${NC}"
echo "kind delete cluster --name mimir-edge" 