# LAB05: Infrastructure as Code with OpenTofu and Terranetes

This directory contains all the configuration files and scripts needed for LAB05.

## Directory Structure

```
lab05/
├── opentofu/                    # OpenTofu/Terraform configuration files
│   ├── versions.tf              # Provider version requirements
│   ├── providers.tf             # Provider authentication configuration
│   ├── variables.tf             # Input variable definitions
│   ├── main.tf                  # Resource definitions (Azure RG + GitHub repo)
│   ├── outputs.tf               # Output value definitions
│   └── terraform.tfvars.example # Example variable values (copy to terraform.tfvars)
│
├── terranetes/                  # Kubernetes-native infrastructure configs
│   ├── namespace.yaml           # Namespace for deployments
│   ├── provider-azure.yaml      # Azure provider for Terranetes
│   ├── infrastructure-revision.yaml  # Reusable infrastructure template
│   ├── cloudresource-example.yaml    # Example developer request
│   └── github-policy.yaml       # Policy for credential injection
│
└── scripts/                     # Helper scripts
    ├── deploy-opentofu.sh       # Deploy with traditional OpenTofu
    ├── install-terranetes.sh    # Install Terranetes controller
    ├── setup-credentials.sh     # Set up Terranetes credentials
    └── cleanup.sh               # Clean up all resources
```

## Quick Start

### Option A: Traditional OpenTofu Deployment

```bash
# 1. Configure variables
cd lab05/opentofu
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 2. Deploy
../scripts/deploy-opentofu.sh
# Or manually:
# tofu init && tofu apply
```

### Option B: Terranetes (Kubernetes-Native)

```bash
# 1. Install Terranetes
./lab05/scripts/install-terranetes.sh

# 2. Set up credentials
./lab05/scripts/setup-credentials.sh

# 3. Deploy infrastructure template
kubectl apply -f lab05/terranetes/infrastructure-revision.yaml

# 4. Request infrastructure
kubectl apply -f lab05/terranetes/cloudresource-example.yaml
```

## Prerequisites

- Completed LAB01 (Kind cluster running)
- Completed LAB03 (Azure Service Principal credentials)
- GitHub Personal Access Token
- OpenTofu installed (`brew install opentofu`)

## What Gets Created

### Traditional OpenTofu (Part 3)
Both Azure and GitHub resources:
- **Azure Resource Group**: A logical container for Azure resources  
- **GitHub Repository**: A code repository with standard settings

### Terranetes (Parts 4-6)
Focuses on cloud provider pattern:
- **Azure Resource Group**: Managed through Terranetes cloud provider integration
- Demonstrates Kubernetes-native infrastructure management
- **Note**: GitHub resources use traditional OpenTofu patterns in Part 3, but Terranetes examples focus on Azure cloud provider integration

## Cleanup

To clean up all resources:

```bash
./lab05/scripts/cleanup.sh
```

## Documentation

See [LAB05.md](../LAB05.md) for the full lab instructions with detailed explanations and verification steps.
