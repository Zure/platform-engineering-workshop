#!/bin/bash
# deploy-opentofu.sh
# Helper script to deploy infrastructure using OpenTofu
#
# Usage: ./deploy-opentofu.sh
#
# Prerequisites:
# - OpenTofu installed (tofu version)
# - Azure CLI authenticated (az login)
# - GITHUB_TOKEN environment variable set

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

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Platform Engineering Workshop - LAB05${NC}"
echo -e "${BLUE}OpenTofu Deployment Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check OpenTofu
if ! command -v tofu &> /dev/null; then
    echo -e "${RED}ERROR: OpenTofu is not installed${NC}"
    echo "Install it with: brew install opentofu (macOS)"
    exit 1
fi
echo -e "${GREEN}✓ OpenTofu: $(tofu version | head -1)${NC}"

# Check Azure CLI
if ! command -v az &> /dev/null; then
    echo -e "${RED}ERROR: Azure CLI is not installed${NC}"
    echo "Install it with: brew install azure-cli (macOS)"
    exit 1
fi

# Check Azure login
if ! az account show &> /dev/null; then
    echo -e "${RED}ERROR: Not logged in to Azure${NC}"
    echo "Run: az login"
    exit 1
fi
AZURE_SUB=$(az account show --query name -o tsv)
echo -e "${GREEN}✓ Azure CLI: Logged in to '$AZURE_SUB'${NC}"

# Check GitHub token
if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${RED}ERROR: GITHUB_TOKEN environment variable is not set${NC}"
    echo "Set it with: export GITHUB_TOKEN='ghp_your_token'"
    exit 1
fi
echo -e "${GREEN}✓ GitHub token: Set (${GITHUB_TOKEN:0:10}...)${NC}"

# Check terraform.tfvars exists
if [ ! -f "$OPENTOFU_DIR/terraform.tfvars" ]; then
    echo -e "${YELLOW}WARNING: terraform.tfvars not found${NC}"
    echo "Creating from example file..."
    if [ -f "$OPENTOFU_DIR/terraform.tfvars.example" ]; then
        cp "$OPENTOFU_DIR/terraform.tfvars.example" "$OPENTOFU_DIR/terraform.tfvars"
        echo -e "${YELLOW}Please edit $OPENTOFU_DIR/terraform.tfvars with your values${NC}"
        echo "Then run this script again."
        exit 1
    else
        echo -e "${RED}ERROR: terraform.tfvars.example not found${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✓ Configuration: terraform.tfvars found${NC}"

echo
echo -e "${YELLOW}Changing to OpenTofu directory...${NC}"
cd "$OPENTOFU_DIR"

# Initialize OpenTofu
echo
echo -e "${YELLOW}Initializing OpenTofu...${NC}"
tofu init

# Validate configuration
echo
echo -e "${YELLOW}Validating configuration...${NC}"
tofu validate
echo -e "${GREEN}✓ Configuration is valid${NC}"

# Format check
echo
echo -e "${YELLOW}Checking formatting...${NC}"
if tofu fmt -check; then
    echo -e "${GREEN}✓ Formatting is correct${NC}"
else
    echo -e "${YELLOW}Formatting files...${NC}"
    tofu fmt
fi

# Plan
echo
echo -e "${YELLOW}Generating execution plan...${NC}"
tofu plan -out=tfplan

# Confirm before apply
echo
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Review the plan above before continuing${NC}"
echo -e "${YELLOW}========================================${NC}"
echo
read -p "Do you want to apply this plan? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    rm -f tfplan
    exit 0
fi

# Apply
echo
echo -e "${YELLOW}Applying configuration...${NC}"
tofu apply tfplan

# Clean up plan file
rm -f tfplan

# Show outputs
echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo -e "${BLUE}Outputs:${NC}"
tofu output

echo
echo -e "${GREEN}Resources have been created successfully!${NC}"
echo -e "View Azure resources: ${BLUE}$(tofu output -raw azure_portal_url 2>/dev/null || echo 'N/A')${NC}"
echo -e "View GitHub repo: ${BLUE}$(tofu output -raw github_repository_url 2>/dev/null || echo 'N/A')${NC}"
