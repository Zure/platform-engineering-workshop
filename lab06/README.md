# LAB06: Deploying with Crossplane

This directory contains all the configuration files needed for LAB06.

## Directory Structure

```
lab06/
└── crossplane/
    ├── provider-family-azure.yaml      # Install Azure provider family
    ├── providerconfig-azure.yaml       # Azure ProviderConfig (credentials reference)
    │
    ├── managed-resources/              # Direct Managed Resource approach (Part 3)
    │   ├── resourcegroup.yaml          # Azure ResourceGroup MR
    │   └── storageaccount.yaml         # Azure StorageAccount MR
    │
    ├── composition/                    # Abstraction layer (Part 4)
    │   ├── xrd.yaml                    # CompositeResourceDefinition (XRD)
    │   └── composition.yaml            # Composition: XAppStorage → RG + SA
    │
    ├── claims/                         # Developer-facing API (Part 5)
    │   └── app-storage-claim.yaml      # Example AppStorageClaim
    │
    ├── argocd/                         # GitOps integration (Part 5)
    │   └── argocd-application.yaml     # ArgoCD Application for Claims
    │
    └── stretch/                        # Stretch goal (Part 6)
        └── provider-github.yaml        # GitHub provider + example Repository MR
```

## Quick Start

### Install Crossplane

```bash
# Add the Crossplane Helm repo
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

# Install Crossplane
helm install crossplane \
  --namespace crossplane-system \
  --create-namespace \
  crossplane-stable/crossplane

# Verify pods
kubectl get pods -n crossplane-system
```

### Install Azure Provider

```bash
kubectl apply -f lab06/crossplane/provider-family-azure.yaml

# Wait until providers are healthy
kubectl get providers -w
```

### Configure Azure Credentials

```bash
# Create the Service Principal credentials secret (reuse from LAB03)
kubectl create secret generic azure-sp-creds \
  --from-literal=credentials="$(cat azure-sp.json)" \
  --namespace crossplane-system

# Apply the ProviderConfig
kubectl apply -f lab06/crossplane/providerconfig-azure.yaml
```

### Deploy Managed Resources Directly (Part 3)

```bash
# Edit resourcegroup.yaml and storageaccount.yaml to set unique names first
kubectl apply -f lab06/crossplane/managed-resources/resourcegroup.yaml
kubectl get resourcegroup -w  # Wait for READY=True

kubectl apply -f lab06/crossplane/managed-resources/storageaccount.yaml
kubectl get accounts -w
```

### Deploy via Composition (Parts 4-5)

```bash
# Install the XRD and Composition
kubectl apply -f lab06/crossplane/composition/xrd.yaml
kubectl apply -f lab06/crossplane/composition/composition.yaml

# Edit app-storage-claim.yaml to set unique names, then:
kubectl apply -f lab06/crossplane/claims/app-storage-claim.yaml
kubectl get appstorageclaims -n team-alpha -w
```

### GitOps with ArgoCD (Part 5)

```bash
# Edit argocd-application.yaml to point at your Git repository, then:
kubectl apply -f lab06/crossplane/argocd/argocd-application.yaml -n argocd

# Check the application in ArgoCD
argocd app get crossplane-claims
```

## Prerequisites

- Completed LAB01 (Kind cluster + ArgoCD running)
- Completed LAB02 (GitOps repo + ArgoCD ApplicationSets)
- Completed LAB03 (Azure Service Principal + Azure CLI configured)

## What Gets Created

| Resource | Type | Description |
|----------|------|-------------|
| Azure Resource Group | Managed Resource | Logical container for Azure resources |
| Azure Storage Account | Managed Resource | Blob/file storage with LRS replication |
| XAppStorage / AppStorageClaim | Custom CRD | Platform abstraction over RG + SA |
| GitHub Repository (stretch) | Managed Resource | Private GitHub repo via provider-github |

## Cleanup

```bash
# Delete claims first — Crossplane cascades to Managed Resources and Azure
kubectl delete appstorageclaims --all -n team-alpha

# Delete direct Managed Resources (if created in Part 3)
kubectl delete accounts workshop-sa
kubectl delete resourcegroup workshop-rg

# Uninstall providers
kubectl delete provider upbound-provider-azure-storage
kubectl delete provider upbound-provider-family-azure

# Uninstall Crossplane
helm uninstall crossplane -n crossplane-system
```

## Documentation

See [LAB06.md](../LAB06.md) for the full lab instructions with detailed explanations and verification steps.
