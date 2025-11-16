#!/bin/bash

# Kubernetes Deployment Script for FastAPI Application
# This script deploys the entire FastAPI application to a Kubernetes cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check prerequisites
print_header "Checking Prerequisites"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi
print_success "kubectl is installed"

# Check if connected to cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Not connected to a Kubernetes cluster. Please configure kubectl."
    exit 1
fi
print_success "Connected to Kubernetes cluster"

# Get cluster info
CLUSTER_NAME=$(kubectl config current-context)
print_success "Using cluster context: $CLUSTER_NAME"

# Check if NGINX Ingress Controller is installed
print_warning "Checking for NGINX Ingress Controller..."
if kubectl get namespace ingress-nginx &> /dev/null; then
    print_success "NGINX Ingress Controller is installed"
else
    print_warning "NGINX Ingress Controller not found. Installing..."
    # Check if helm is available
    if command -v helm &> /dev/null; then
        helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
        helm repo update
        helm install ingress-nginx ingress-nginx/ingress-nginx \
            --namespace ingress-nginx --create-namespace \
            --set controller.service.type=LoadBalancer
        print_success "NGINX Ingress Controller installed"
    else
        print_error "Helm is not installed. Please install NGINX Ingress Controller manually:"
        echo "  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx"
        echo "  helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace"
    fi
fi

# Check if Metrics Server is installed
print_warning "Checking for Metrics Server..."
if kubectl get deployment metrics-server -n kube-system &> /dev/null 2>&1; then
    print_success "Metrics Server is installed"
else
    print_warning "Metrics Server not found."
    print_warning "Note: GKE Autopilot manages system namespaces and includes Metrics Server by default."
    print_warning "If you need a custom metrics server, use a separate namespace."
fi

# Deployment
print_header "Deploying FastAPI Application"

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Apply manifests in order
echo ""
echo "Applying Kubernetes manifests..."
echo ""

FILES=(
    "01-namespace.yaml"
    "02-redis-configmap.yaml"
    "03-redis-deployment.yaml"
    "04-redis-service.yaml"
    "05-fastapi-configmap.yaml"
    "06-fastapi-deployment.yaml"
    "07-fastapi-service.yaml"
    "08-ingress.yaml"
    "09-hpa.yaml"
    "10-network-policy.yaml"
)

for file in "${FILES[@]}"; do
    FILE_PATH="$SCRIPT_DIR/$file"
    if [ -f "$FILE_PATH" ]; then
        echo -n "Applying $file... "
        if kubectl apply -f "$FILE_PATH" > /dev/null 2>&1; then
            print_success "$file"
        else
            print_error "$file"
            exit 1
        fi
    else
        print_error "File not found: $FILE_PATH"
        exit 1
    fi
done

print_header "Deployment Complete!"

# Wait for deployments
print_header "Waiting for Deployments to be Ready"

echo "Waiting for Redis to be ready..."
kubectl rollout status deployment/redis-db -n fastapi-app --timeout=5m

echo "Waiting for FastAPI to be ready..."
kubectl rollout status deployment/fastapi-app -n fastapi-app --timeout=5m

print_success "All deployments are ready!"

# Post-deployment information
print_header "Deployment Information"

echo ""
echo "Namespace: fastapi-app"
echo ""

echo "Deployments:"
kubectl get deployments -n fastapi-app

echo ""
echo "Services:"
kubectl get svc -n fastapi-app

echo ""
echo "Ingress:"
kubectl get ingress -n fastapi-app

echo ""
echo "Pods:"
kubectl get pods -n fastapi-app

echo ""
print_header "Next Steps"

echo "1. Port forward to access the application locally:"
echo "   kubectl port-forward -n fastapi-app svc/fastapi-app 8080:80"
echo ""

echo "2. Get the Ingress IP/Hostname:"
echo "   kubectl get ingress -n fastapi-app -o wide"
echo ""

echo "3. Add to your hosts file (on Linux/Mac):"
INGRESS_IP=$(kubectl get ingress -n fastapi-app -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "YOUR_INGRESS_IP")
echo "   $INGRESS_IP fastapi.local"
echo ""

echo "4. Access the application:"
echo "   http://fastapi.local (via ingress)"
echo "   http://localhost:8080 (via port-forward)"
echo ""

echo "5. View logs:"
echo "   kubectl logs -n fastapi-app -l app=fastapi-app -f"
echo ""

echo "6. Monitor HPA:"
echo "   kubectl get hpa -n fastapi-app -w"
echo ""

print_header "Documentation"
echo "For more information, see README.md in the k8s-specifications directory"
