#!/bin/bash
# setup-credentials.sh
# Helper script to set up credentials for Terranetes
#
# Usage: ./setup-credentials.sh
#
# This script creates:
# - terraform-deployments namespace
# - Azure credentials secret
# - GitHub credentials secret
# - Provider configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRANETES_DIR="$SCRIPT_DIR/../terranetes"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Platform Engineering Workshop - LAB05${NC}"
echo -e "${BLUE}Terranetes Credentials Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check kubectl
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}ERROR: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Kubernetes cluster accessible${NC}"

# Check Azure CLI
if ! az account show &> /dev/null; then
    echo -e "${RED}ERROR: Not logged in to Azure${NC}"
    echo "Run: az login"
    exit 1
fi
echo -e "${GREEN}✓ Azure CLI authenticated${NC}"

# Check GitHub token
if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${YELLOW}WARNING: GITHUB_TOKEN not set${NC}"
    read -p "Enter your GitHub token: " GITHUB_TOKEN
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${RED}ERROR: GitHub token is required${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✓ GitHub token available${NC}"

echo
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl apply -f "$TERRANETES_DIR/namespace.yaml"
echo -e "${GREEN}✓ Namespace terraform-deployments created${NC}"

echo
echo -e "${YELLOW}Getting Azure credentials...${NC}"
ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
ARM_TENANT_ID=$(az account show --query tenantId -o tsv)

echo "Subscription ID: $ARM_SUBSCRIPTION_ID"
echo "Tenant ID: $ARM_TENANT_ID"

echo
echo -e "${YELLOW}Enter your Service Principal credentials from LAB03:${NC}"
read -p "Client ID (appId): " ARM_CLIENT_ID
read -sp "Client Secret (password): " ARM_CLIENT_SECRET
echo

if [ -z "$ARM_CLIENT_ID" ] || [ -z "$ARM_CLIENT_SECRET" ]; then
    echo -e "${RED}ERROR: Client ID and Secret are required${NC}"
    exit 1
fi

echo
echo -e "${YELLOW}Creating Azure credentials secret...${NC}"
kubectl delete secret azure-credentials -n terraform-deployments 2>/dev/null || true
kubectl create secret generic azure-credentials \
    --namespace terraform-deployments \
    --from-literal=ARM_SUBSCRIPTION_ID="$ARM_SUBSCRIPTION_ID" \
    --from-literal=ARM_TENANT_ID="$ARM_TENANT_ID" \
    --from-literal=ARM_CLIENT_ID="$ARM_CLIENT_ID" \
    --from-literal=ARM_CLIENT_SECRET="$ARM_CLIENT_SECRET"
echo -e "${GREEN}✓ Azure credentials secret created${NC}"

echo
echo -e "${YELLOW}Creating GitHub credentials secret...${NC}"
kubectl delete secret github-credentials -n terraform-deployments 2>/dev/null || true
kubectl create secret generic github-credentials \
    --namespace terraform-deployments \
    --from-literal=GITHUB_TOKEN="$GITHUB_TOKEN"
echo -e "${GREEN}✓ GitHub credentials secret created${NC}"

echo
echo -e "${YELLOW}Applying provider configurations...${NC}"
kubectl apply -f "$TERRANETES_DIR/provider-azure.yaml"
kubectl apply -f "$TERRANETES_DIR/provider-github.yaml"
echo -e "${GREEN}✓ Provider configurations applied${NC}"

echo
echo -e "${YELLOW}Applying GitHub policy...${NC}"
kubectl apply -f "$TERRANETES_DIR/github-policy.yaml"
echo -e "${GREEN}✓ GitHub policy applied${NC}"

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Credentials Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo

echo -e "${BLUE}Verifying setup:${NC}"
echo
echo -e "${YELLOW}Secrets:${NC}"
kubectl get secrets -n terraform-deployments

echo
echo -e "${YELLOW}Providers:${NC}"
kubectl get providers.terraform.appvia.io

echo
echo -e "${YELLOW}Policies:${NC}"
kubectl get policies.terraform.appvia.io

echo
echo -e "${GREEN}Next steps:${NC}"
echo "1. Apply the infrastructure revision:"
echo "   kubectl apply -f ../terranetes/infrastructure-revision.yaml"
echo
echo "2. Customize and apply a CloudResource:"
echo "   # Edit cloudresource-example.yaml with your values"
echo "   kubectl apply -f ../terranetes/cloudresource-example.yaml"
echo
echo "3. Monitor the deployment:"
echo "   kubectl get cloudresource -n terraform-deployments --watch"
