#!/bin/bash
# install-terranetes.sh
# Helper script to install Terranetes controller in Kubernetes
#
# Usage: ./install-terranetes.sh
#
# Prerequisites:
# - kubectl configured with cluster access
# - Helm 3 installed

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Platform Engineering Workshop - LAB05${NC}"
echo -e "${BLUE}Terranetes Installation Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}ERROR: kubectl is not installed${NC}"
    exit 1
fi

# Check cluster access
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}ERROR: Cannot connect to Kubernetes cluster${NC}"
    echo "Make sure your kubeconfig is set up correctly"
    exit 1
fi
CLUSTER=$(kubectl config current-context)
echo -e "${GREEN}✓ kubectl: Connected to '$CLUSTER'${NC}"

# Check Helm
if ! command -v helm &> /dev/null; then
    echo -e "${RED}ERROR: Helm is not installed${NC}"
    echo "Install it with: brew install helm (macOS)"
    exit 1
fi
echo -e "${GREEN}✓ Helm: $(helm version --short)${NC}"

echo
echo -e "${YELLOW}Adding Terranetes Helm repository...${NC}"
helm repo add appvia https://terranetes-controller.appvia.io 2>/dev/null || true
helm repo update

echo
echo -e "${YELLOW}Installing Terranetes controller...${NC}"

# Check if already installed
if helm status terranetes-controller -n terraform-system &> /dev/null; then
    echo -e "${YELLOW}Terranetes controller is already installed${NC}"
    read -p "Do you want to upgrade it? (yes/no): " UPGRADE
    if [ "$UPGRADE" == "yes" ]; then
        helm upgrade terranetes-controller appvia/terranetes-controller \
            --namespace terraform-system
    fi
else
    helm install -n terraform-system terranetes-controller appvia/terranetes-controller \
        --create-namespace
fi

echo
echo -e "${YELLOW}Waiting for controller to be ready...${NC}"
kubectl rollout status deployment/terranetes-controller -n terraform-system --timeout=120s

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Terranetes Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo

# Verify installation
echo -e "${BLUE}Verifying installation:${NC}"
echo

echo -e "${YELLOW}Controller pods:${NC}"
kubectl get pods -n terraform-system

echo
echo -e "${YELLOW}Terranetes CRDs:${NC}"
kubectl get crd | grep terraform.appvia.io

echo
echo -e "${GREEN}Next steps:${NC}"
echo "1. Create the terraform-deployments namespace:"
echo "   kubectl apply -f ../terranetes/namespace.yaml"
echo
echo "2. Create Azure credentials secret:"
echo "   kubectl create secret generic azure-credentials \\"
echo "     --namespace terraform-deployments \\"
echo "     --from-literal=ARM_SUBSCRIPTION_ID=\"...\" \\"
echo "     --from-literal=ARM_TENANT_ID=\"...\" \\"
echo "     --from-literal=ARM_CLIENT_ID=\"...\" \\"
echo "     --from-literal=ARM_CLIENT_SECRET=\"...\""
echo
echo "3. Create GitHub credentials secret:"
echo "   kubectl create secret generic github-credentials \\"
echo "     --namespace terraform-deployments \\"
echo "     --from-literal=GITHUB_TOKEN=\"...\""
echo
echo "4. Apply provider configurations:"
echo "   kubectl apply -f ../terranetes/provider-azure.yaml"
echo "   kubectl apply -f ../terranetes/provider-github.yaml"
