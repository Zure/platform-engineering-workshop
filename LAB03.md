# LAB03: Deploying Azure Resources with Azure Service Operator

Welcome to LAB03! In this lab, you'll extend your platform engineering skills by deploying Azure resources outside of Kubernetes using Azure Service Operator (ASO). By the end of this lab, you'll have:

- Azure Service Operator (ASO) installed in your Kubernetes cluster
- Azure credentials configured for ASO authentication
- ArgoCD applications that deploy Azure resources via GitOps
- Experience creating Azure Resource Groups and Storage Accounts
- Understanding of how to manage Azure resources through Kubernetes manifests

## Prerequisites

Before starting, ensure you have completed:
- ✅ **LAB01**: Your local environment should have:
  - Kind cluster running with NGINX ingress
  - ArgoCD installed and accessible
  - ArgoCD CLI configured and working
- ✅ **LAB02**: Multi-tenant ArgoCD setup with:
  - Self-service ArgoCD projects configured
  - Understanding of GitOps workflows
  - Basic ArgoCD application management

**Additional Requirements for this lab:**
- ✅ **Azure Account**: Access to an Azure subscription with permissions to create resources
- ✅ **Azure CLI**: Installed and configured on your local machine
- ✅ **Service Principal**: Azure Service Principal with appropriate permissions (we'll create this together)

## Overview

In this lab, we'll explore **Azure Service Operator (ASO)**, a Kubernetes operator that allows you to create and manage Azure resources using Kubernetes Custom Resource Definitions (CRDs). This approach enables:

- **GitOps for Cloud Resources**: Manage Azure resources through Git workflows
- **Kubernetes-Native Experience**: Use `kubectl` and familiar K8s patterns for Azure
- **Self-Service Cloud Resources**: Teams can request Azure resources through the same platform
- **Unified Management**: Combine application and infrastructure deployment

### What is Azure Service Operator?

Azure Service Operator is a Kubernetes operator developed by Microsoft that:
- Translates Kubernetes manifests into Azure ARM API calls
- Manages the lifecycle of Azure resources through Kubernetes
- Provides strongly-typed Kubernetes CRDs for Azure resources
- Integrates seamlessly with GitOps workflows and ArgoCD

## Part 1: Setting Up Azure Prerequisites

### Install Azure CLI (if not already installed)

#### Windows
```powershell
# Using Chocolatey
choco install azure-cli

# Or using MSI installer
# Download from: https://aka.ms/installazurecliwindows
```

#### macOS
```bash
# Using Homebrew
brew update && brew install azure-cli
```

#### Linux
```bash
# Ubuntu/Debian
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# RHEL/CentOS/Fedora
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo dnf install -y https://packages.microsoft.com/config/rhel/9/packages-microsoft-prod.rpm
sudo dnf install azure-cli
```

### Login to Azure
```bash
# Login to Azure
az login

# List available subscriptions
az account list --output table

# Set the subscription you want to use
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify current subscription
az account show --output table
```

### Create Azure Service Principal

Azure Service Operator needs credentials to manage Azure resources. We'll create a Service Principal with appropriate permissions.

```bash
# Create a Service Principal
# Replace YOUR_SUBSCRIPTION_ID with your actual subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SP_NAME="aso-workshop-sp"

# Create service principal with Contributor role at subscription level
az ad sp create-for-rbac \
  --name $SP_NAME \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --sdk-auth

# The output will look like this - SAVE THESE VALUES:
# {
#   "clientId": "your-client-id",
#   "clientSecret": "your-client-secret",
#   "subscriptionId": "your-subscription-id",
#   "tenantId": "your-tenant-id",
#   "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
#   "resourceManagerEndpointUrl": "https://management.azure.com/",
#   "activeDirectoryGraphResourceId": "https://graph.windows.net/",
#   "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
#   "galleryEndpointUrl": "https://gallery.azure.com/",
#   "managementEndpointUrl": "https://management.core.windows.net/"
# }
```

**Important**: Save the Service Principal credentials securely. You'll need them in the next steps.

## Part 2: Installing Azure Service Operator

### Install ASO using Helm

```bash
# Add the ASO Helm repository
helm repo add aso2 https://raw.githubusercontent.com/Azure/azure-service-operator/main/v2/charts

# Update helm repositories
helm repo update

# Install Azure Service Operator
helm install aso2 aso2/azure-service-operator \
  --create-namespace \
  --namespace azureserviceoperator-system \
  --set azureSubscriptionID=$SUBSCRIPTION_ID \
  --set azureTenantID="YOUR_TENANT_ID" \
  --set azureClientID="YOUR_CLIENT_ID" \
  --set azureClientSecret="YOUR_CLIENT_SECRET"

# Replace YOUR_TENANT_ID, YOUR_CLIENT_ID, and YOUR_CLIENT_SECRET 
# with the values from the service principal creation step
```

### Verify ASO Installation

```bash
# Check if ASO pods are running
kubectl get pods -n azureserviceoperator-system

# Check ASO Custom Resource Definitions
kubectl get crd | grep azure

# Check ASO operator logs
kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager
```

You should see output similar to:
```
NAME                                                    READY   STATUS    RESTARTS   AGE
azureserviceoperator-controller-manager-xxxxxxxxx-xxx   2/2     Running   0          2m
```

## Part 3: Creating Azure Resources with GitOps

### Set Up Resource Directory Structure

Let's create a directory structure for our Azure resources that follows GitOps principles:

```bash
# Create directory for Azure resources
mkdir -p /tmp/azure-resources
cd /tmp/azure-resources

# Initialize git repository
git init

# Create directory structure
mkdir -p {resource-groups,storage-accounts,applications}

# Create README
cat << 'EOF' > README.md
# Azure Resources via GitOps

This repository contains Azure resource definitions managed through Azure Service Operator and ArgoCD.

## Structure

- `resource-groups/` - Azure Resource Group definitions
- `storage-accounts/` - Azure Storage Account definitions  
- `applications/` - ArgoCD Application manifests

## Workflow

1. Define Azure resources as Kubernetes manifests
2. Commit changes to Git repository
3. ArgoCD automatically syncs and applies changes
4. Azure Service Operator creates/updates Azure resources
EOF
```

### Create Azure Resource Group

```bash
# Create a Resource Group manifest
cat << 'EOF' > resource-groups/workshop-rg.yaml
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: workshop-rg
  namespace: default
spec:
  location: East US
  # You can add tags for better organization
  tags:
    environment: workshop
    managed-by: azure-service-operator
    team: platform-engineering
EOF
```

### Create Azure Storage Account

```bash
# Create a Storage Account manifest
cat << 'EOF' > storage-accounts/workshop-storage.yaml
apiVersion: storage.azure.com/v1api20210401
kind: StorageAccount
metadata:
  name: workshopstorage001
  namespace: default
spec:
  location: East US
  # Reference the Resource Group we created above
  resourceGroupRef:
    name: workshop-rg
  sku:
    name: Standard_LRS
  kind: StorageV2
  properties:
    accessTier: Hot
    allowBlobPublicAccess: false
    minimumTlsVersion: TLS1_2
  tags:
    environment: workshop
    managed-by: azure-service-operator
    team: platform-engineering
EOF
```

### Test Direct Application

Before setting up ArgoCD, let's test that our manifests work:

```bash
# Apply the Resource Group
kubectl apply -f resource-groups/workshop-rg.yaml

# Wait for Resource Group to be created (this may take 1-2 minutes)
kubectl get resourcegroup workshop-rg -w

# Apply the Storage Account
kubectl apply -f storage-accounts/workshop-storage.yaml

# Monitor Storage Account creation
kubectl get storageaccount workshopstorage001 -w

# Check the status and events
kubectl describe resourcegroup workshop-rg
kubectl describe storageaccount workshopstorage001
```

### Verify in Azure Portal

```bash
# Check resources in Azure CLI
az group show --name workshop-rg --output table
az storage account show --name workshopstorage001 --resource-group workshop-rg --output table
```

## Part 4: Setting Up ArgoCD for Azure Resources

### Create ArgoCD Project for Azure Resources

```bash
# Create an ArgoCD project for Azure resources
cat << 'EOF' > /tmp/azure-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: azure-resources
  namespace: argocd
spec:
  description: "Project for managing Azure resources via ASO"
  
  # Source repositories
  sourceRepos:
  - '*'
  
  # Destination clusters and namespaces
  destinations:
  - namespace: default
    server: https://kubernetes.default.svc
  - namespace: azureserviceoperator-system
    server: https://kubernetes.default.svc
  
  # Allowed Kubernetes resources
  clusterResourceWhitelist:
  - group: 'resources.azure.com'
    kind: '*'
  - group: 'storage.azure.com'
    kind: '*'
  - group: 'keyvault.azure.com'
    kind: '*'
  - group: 'network.azure.com'
    kind: '*'
    
  namespaceResourceWhitelist:
  - group: 'resources.azure.com'
    kind: '*'
  - group: 'storage.azure.com'
    kind: '*'
    
  # RBAC Policies
  roles:
  - name: azure-admin
    description: "Full access to Azure resources"
    policies:
    - p, proj:azure-resources:azure-admin, applications, *, azure-resources/*, allow
    groups:
    - argocd:admin
    
  - name: azure-developer
    description: "Read access to Azure resources"
    policies:
    - p, proj:azure-resources:azure-developer, applications, get, azure-resources/*, allow
    - p, proj:azure-resources:azure-developer, applications, sync, azure-resources/*, allow
    groups:
    - argocd:developer
EOF

# Apply the project
kubectl apply -f /tmp/azure-project.yaml
```

### Create ArgoCD Application for Azure Resources

```bash
# Create an ArgoCD application manifest
cat << 'EOF' > applications/azure-resources-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: azure-resources
  namespace: argocd
spec:
  project: azure-resources
  
  source:
    repoURL: 'file:///tmp/azure-resources'  # In production, use your Git repository
    targetRevision: HEAD
    path: .
    
  destination:
    server: https://kubernetes.default.svc
    namespace: default
    
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=false
    
  # Ignore differences in status fields
  ignoreDifferences:
  - group: resources.azure.com
    kind: ResourceGroup
    jsonPointers:
    - /status
  - group: storage.azure.com
    kind: StorageAccount  
    jsonPointers:
    - /status
EOF

# Commit our changes
git add .
git commit -m "Initial Azure resources configuration

- Add Resource Group for workshop
- Add Storage Account with proper configuration
- Add ArgoCD application for GitOps workflow"
```

### Apply ArgoCD Application

```bash
# Apply the ArgoCD application
kubectl apply -f applications/azure-resources-app.yaml

# Check application status
argocd app get azure-resources

# Sync the application
argocd app sync azure-resources

# Monitor the application
argocd app get azure-resources -w
```

## Part 5: Advanced Azure Resource Management

### Creating a More Complex Setup

Let's create a more realistic scenario with multiple environments:

```bash
# Create environment-specific directories
mkdir -p environments/{dev,staging,prod}

# Create development environment resources
cat << 'EOF' > environments/dev/resource-group.yaml
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: workshop-dev-rg
  namespace: default
spec:
  location: East US
  tags:
    environment: dev
    managed-by: azure-service-operator
    cost-center: platform-team
EOF

cat << 'EOF' > environments/dev/storage-account.yaml
apiVersion: storage.azure.com/v1api20210401
kind: StorageAccount
metadata:
  name: workshopdevstorage001
  namespace: default
spec:
  location: East US
  resourceGroupRef:
    name: workshop-dev-rg
  sku:
    name: Standard_LRS
  kind: StorageV2
  properties:
    accessTier: Hot
    allowBlobPublicAccess: false
    minimumTlsVersion: TLS1_2
  tags:
    environment: dev
    managed-by: azure-service-operator
EOF

# Create production environment resources
cat << 'EOF' > environments/prod/resource-group.yaml
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: workshop-prod-rg
  namespace: default
spec:
  location: West US2
  tags:
    environment: prod
    managed-by: azure-service-operator
    cost-center: platform-team
EOF

cat << 'EOF' > environments/prod/storage-account.yaml
apiVersion: storage.azure.com/v1api20210401
kind: StorageAccount
metadata:
  name: workshopprodstorage001
  namespace: default
spec:
  location: West US2
  resourceGroupRef:
    name: workshop-prod-rg
  sku:
    name: Standard_ZRS  # Zone-redundant storage for production
  kind: StorageV2
  properties:
    accessTier: Hot
    allowBlobPublicAccess: false
    minimumTlsVersion: TLS1_2
  tags:
    environment: prod
    managed-by: azure-service-operator
EOF
```

### Create Environment-Specific ArgoCD Applications

```bash
# Create dev environment application
cat << 'EOF' > applications/azure-resources-dev.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: azure-resources-dev
  namespace: argocd
spec:
  project: azure-resources
  
  source:
    repoURL: 'file:///tmp/azure-resources'
    targetRevision: HEAD
    path: environments/dev
    
  destination:
    server: https://kubernetes.default.svc
    namespace: default
    
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# Create prod environment application  
cat << 'EOF' > applications/azure-resources-prod.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: azure-resources-prod
  namespace: argocd
spec:
  project: azure-resources
  
  source:
    repoURL: 'file:///tmp/azure-resources'
    targetRevision: HEAD
    path: environments/prod
    
  destination:
    server: https://kubernetes.default.svc
    namespace: default
    
  syncPolicy:
    # Manual sync for production
    syncOptions:
    - CreateNamespace=false
EOF

# Commit the new structure
git add environments/ applications/
git commit -m "Add multi-environment Azure resource structure

- Separate dev and prod environments
- Different configurations per environment
- Production uses ZRS storage for better resilience"
```

## Part 6: Monitoring and Management

### Check Resource Status

```bash
# List all Azure resources managed by ASO
kubectl get resourcegroup,storageaccount

# Get detailed status of resources
kubectl describe resourcegroup workshop-dev-rg
kubectl describe storageaccount workshopdevstorage001

# Check ASO operator logs for any issues
kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager -f
```

### ArgoCD Integration

```bash
# Apply the new applications
kubectl apply -f applications/azure-resources-dev.yaml
kubectl apply -f applications/azure-resources-prod.yaml

# Check application status
argocd app list | grep azure

# Sync development environment
argocd app sync azure-resources-dev

# For production, sync manually when ready
argocd app get azure-resources-prod
```

### Cleanup Test Resources

```bash
# Clean up the initial test resources to avoid conflicts
kubectl delete storageaccount workshopstorage001
kubectl delete resourcegroup workshop-rg

# Wait for resources to be deleted from Azure
kubectl get resourcegroup,storageaccount -w
```

## Troubleshooting

### Common Issues

#### Service Principal Authentication Issues

```bash
# Check if credentials are correctly configured
kubectl get secret -n azureserviceoperator-system

# Verify ASO can authenticate to Azure
kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager | grep -i auth
```

#### Resource Creation Failures

```bash
# Check resource status and events
kubectl describe <resource-type> <resource-name>

# Check ASO operator logs for specific errors
kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager | grep ERROR

# Common issues:
# - Invalid location names
# - Resource naming conflicts
# - Insufficient permissions
# - Resource dependencies not met
```

#### ArgoCD Sync Issues

```bash
# Check application health
argocd app get azure-resources --refresh

# Force sync with prune
argocd app sync azure-resources --prune

# Check for resource differences
argocd app diff azure-resources
```

#### Naming Conflicts

Azure resources have global naming requirements (especially Storage Accounts):

```bash
# Check if storage account name is available
az storage account check-name --name your-storage-name

# Use unique naming patterns like:
# workshopstorage$(date +%s)
# or include random suffixes
```

### Cleanup Commands

```bash
# Delete ArgoCD applications
argocd app delete azure-resources-dev --cascade
argocd app delete azure-resources-prod --cascade

# Delete remaining Azure resources (if needed)
kubectl delete -f environments/dev/
kubectl delete -f environments/prod/

# Uninstall Azure Service Operator
helm uninstall aso2 -n azureserviceoperator-system
kubectl delete namespace azureserviceoperator-system
```

## Next Steps

Congratulations! You now have:
- ✅ Azure Service Operator installed and configured
- ✅ Service Principal authentication set up
- ✅ Azure resources managed through Kubernetes manifests
- ✅ GitOps workflow for Azure resource deployment
- ✅ Multi-environment resource management
- ✅ ArgoCD integration for automated Azure resource deployment

You're ready for LAB04 where we'll explore advanced concepts including full application stacks and AI-driven platform experiences.

### Real-World Implementation

To implement this in a production environment, you would:

1. **Secure Credential Management**: Use Azure Key Vault or Kubernetes secrets with proper RBAC
2. **Git Repository**: Store manifests in a proper Git repository with branch protection
3. **CI/CD Pipeline**: Add validation and approval workflows for production resources
4. **Resource Organization**: Use proper Azure resource naming conventions and tagging strategies
5. **Cost Management**: Implement cost tracking and budgets for cloud resources
6. **Monitoring**: Set up monitoring and alerting for Azure resource health and costs
7. **Backup and Recovery**: Implement backup strategies for stateful resources

### Advanced Features to Explore

- **Azure Key Vault Integration**: Store secrets securely in Azure Key Vault
- **Virtual Networks**: Create and manage Azure networking resources
- **Application Gateway**: Set up load balancing and ingress for Azure applications
- **Azure Database**: Deploy and manage Azure database services
- **Policy as Code**: Use Azure Policy for governance and compliance
- **Cost Optimization**: Implement resource scheduling and auto-scaling

## Resources

- [Azure Service Operator Documentation](https://azure.github.io/azure-service-operator/)
- [Azure Service Operator GitHub Repository](https://github.com/Azure/azure-service-operator)
- [Azure Resource Manager Templates](https://docs.microsoft.com/en-us/azure/azure-resource-manager/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)