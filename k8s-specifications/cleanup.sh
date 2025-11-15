#!/bin/bash

# Kubernetes Cleanup Script for FastAPI Application
# This script removes all deployed resources for the FastAPI application

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

# Check if connected to cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Not connected to a Kubernetes cluster"
    exit 1
fi

print_header "Kubernetes Cleanup Script"

# Get cluster info
CLUSTER_NAME=$(kubectl config current-context)
print_warning "Using cluster context: $CLUSTER_NAME"

# Confirmation
echo ""
print_warning "This will DELETE the entire fastapi-app namespace and all resources within it!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_warning "Cleanup cancelled"
    exit 0
fi

print_header "Deleting Resources"

# Delete namespace (this will cascade delete all resources)
echo "Deleting namespace 'fastapi-app'..."
if kubectl delete namespace fastapi-app --ignore-not-found=true; then
    print_success "Namespace deleted successfully"
else
    print_error "Failed to delete namespace"
    exit 1
fi

# Wait for namespace deletion
echo ""
echo "Waiting for namespace to be completely deleted..."
while kubectl get namespace fastapi-app &> /dev/null; do
    echo -n "."
    sleep 2
done
echo ""

print_success "Cleanup complete!"

echo ""
print_header "Summary"
echo "All FastAPI application resources have been removed from the cluster."
echo ""
echo "Remaining resources:"
kubectl get namespace | grep -E "fastapi|default|kube-system|kube-public" || echo "No related namespaces found"
