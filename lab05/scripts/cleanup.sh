#!/bin/bash
# cleanup.sh
# Helper script to clean up all resources created in LAB05
#
# Usage: ./cleanup.sh
#
# This script removes:
# - Terranetes CloudResources (and associated cloud resources)
# - Terranetes Revisions, Providers, Policies
# - Terranetes controller
# - OpenTofu state and resources

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENTOFU_DIR="$SCRIPT_DIR/../opentofu"

echo -e "${RED}========================================${NC}"
echo -e "${RED}Platform Engineering Workshop - LAB05${NC}"
echo -e "${RED}CLEANUP SCRIPT${NC}"
echo -e "${RED}========================================${NC}"
echo
echo -e "${YELLOW}WARNING: This will delete all resources created in LAB05${NC}"
echo -e "${YELLOW}including Azure resources and GitHub repositories!${NC}"
echo
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 1: Cleaning up Terranetes resources${NC}"
echo -e "${BLUE}========================================${NC}"

# Delete CloudResources (this will destroy cloud infrastructure)
echo
echo -e "${YELLOW}Deleting CloudResources...${NC}"
if kubectl get cloudresources.terraform.appvia.io -n terranetes-deployments &> /dev/null; then
    kubectl delete cloudresources.terraform.appvia.io --all -n terranetes-deployments --timeout=300s || true
    echo "Waiting for cloud resources to be destroyed..."
    sleep 30
fi
echo -e "${GREEN}✓ CloudResources deleted${NC}"

# Delete Revisions
echo
echo -e "${YELLOW}Deleting Revisions...${NC}"
kubectl delete revisions.terraform.appvia.io --all --timeout=60s 2>/dev/null || true
echo -e "${GREEN}✓ Revisions deleted${NC}"

# Delete Providers
echo
echo -e "${YELLOW}Deleting Providers...${NC}"
kubectl delete providers.terraform.appvia.io --all --timeout=60s 2>/dev/null || true
echo -e "${GREEN}✓ Providers deleted${NC}"

# Delete Policies
echo
echo -e "${YELLOW}Deleting Policies...${NC}"
kubectl delete policies.terraform.appvia.io --all --timeout=60s 2>/dev/null || true
echo -e "${GREEN}✓ Policies deleted${NC}"

# Uninstall Terranetes controller
echo
echo -e "${YELLOW}Uninstalling Terranetes controller...${NC}"
if helm status terranetes-controller -n terranetes-system &> /dev/null; then
    helm uninstall terranetes-controller -n terranetes-system
fi
echo -e "${GREEN}✓ Terranetes controller uninstalled${NC}"

# Delete namespaces
echo
echo -e "${YELLOW}Deleting namespaces...${NC}"
kubectl delete namespace terranetes-system --timeout=60s 2>/dev/null || true
kubectl delete namespace terranetes-deployments --timeout=60s 2>/dev/null || true
echo -e "${GREEN}✓ Namespaces deleted${NC}"

echo
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 2: Cleaning up OpenTofu resources${NC}"
echo -e "${BLUE}========================================${NC}"

if [ -d "$OPENTOFU_DIR" ]; then
    cd "$OPENTOFU_DIR"
    
    # Check if state exists
    if [ -f "terraform.tfstate" ]; then
        echo
        echo -e "${YELLOW}Found OpenTofu state file${NC}"
        echo "Resources in state:"
        tofu state list 2>/dev/null || true
        echo
        read -p "Do you want to destroy these resources? (yes/no): " DESTROY_TF
        
        if [ "$DESTROY_TF" == "yes" ]; then
            echo -e "${YELLOW}Destroying OpenTofu resources...${NC}"
            tofu destroy -auto-approve || true
            echo -e "${GREEN}✓ OpenTofu resources destroyed${NC}"
        fi
    fi
    
    # Clean up local files
    echo
    echo -e "${YELLOW}Cleaning up local files...${NC}"
    rm -rf .terraform .terraform.lock.hcl
    rm -f terraform.tfstate terraform.tfstate.backup
    rm -f tfplan
    rm -f terraform.tfvars  # Keep the example
    echo -e "${GREEN}✓ Local files cleaned up${NC}"
fi

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Cleanup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo "All LAB05 resources have been cleaned up."
echo
echo "You may also want to verify in:"
echo "- Azure Portal: Check for any remaining resource groups"
echo "- GitHub: Check for any remaining repositories"
