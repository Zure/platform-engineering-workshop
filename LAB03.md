# LAB03: Deploying Azure Resources with Azure Service Operator

Welcome to LAB03! In this lab, you'll extend your platform engineering skills by deploying Azure resources using Azure Service Operator (ASO) through GitOps. By the end of this lab, you'll have:

- Azure Service Operator (ASO) installed in your Kubernetes cluster
- Azure credentials configured for ASO authentication
- A GitHub repository for managing Azure resources
- ArgoCD applications deploying Azure resources via GitOps
- Understanding of how to manage cloud resources through Kubernetes manifests

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
- ✅ **GitHub Account**: For creating your Azure resources repository
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

### Lab Flow

In this lab, we'll take a simplified approach:
1. Set up Azure prerequisites (CLI, Service Principal)
2. Install Azure Service Operator in our Kind cluster
3. Create a GitHub repository for Azure resources
4. Deploy a simple Azure resource (Resource Group and Storage Account)
5. Connect ArgoCD to manage these resources through GitOps

This streamlined approach focuses on understanding the core concepts without overwhelming complexity.

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

### ✅ Verification Steps - Part 1

Let's verify your Azure setup is ready:

```bash
# Verify you're logged in to Azure
az account show --output table

# Verify you can see your subscription
az account list --output table

# Check that service principal was created (you should see it in the output above)
```

**Expected Output:**
- Azure CLI should show your logged-in account details
- You should see your subscription ID and name
- The service principal creation should have provided credentials in JSON format

### 🤔 Reflection Questions - Part 1

Take a moment to think about what you've set up:

1. **Service Principal Purpose**: Why do we need a Service Principal for ASO? Why can't ASO just use your personal Azure login credentials?

2. **Permissions Scope**: We gave the Service Principal "Contributor" role at the subscription level. What does this allow it to do? Is this appropriate for a production environment?

3. **Credential Security**: The Service Principal credentials are sensitive. How should these be managed in a production environment? What tools or practices would you use?

4. **Azure Regions**: When creating Azure resources, you'll need to specify a location (like "Sweden Central"). Why is region selection important for cloud resources?

5. **Cost Awareness**: Azure resources incur costs. How would you track and control costs for resources created through ASO in a multi-team environment?

## Part 2: Installing Azure Service Operator

### Install ASO using Helm

Azure Service Operator has a dependecy on Cert Manager. Install cert-manager first.

```bash
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.18.2/cert-manager.yaml
```

```bash
# Add the ASO Helm repository
helm repo add aso2 https://raw.githubusercontent.com/Azure/azure-service-operator/main/v2/charts

# Update helm repositories
helm repo update

# Install Azure Service Operator with Azure credentials
# Replace the placeholder values with your Service Principal credentials from Part 1
helm upgrade --install aso2 aso2/azure-service-operator \
    --create-namespace \
    --namespace=azureserviceoperator-system \
    --set crdPattern='resources.azure.com/*;storage.azure.com/*;keyvault.azure.com/*;managedidentity.azure.com/*' \
    --set azureSubscriptionID='YOUR_SUBSCRIPTION_ID' \
    --set azureTenantID='YOUR_TENANT_ID' \
    --set azureClientID='YOUR_CLIENT_ID' \
    --set azureClientSecret='YOUR_CLIENT_SECRET'
```

**Important**: Replace `YOUR_SUBSCRIPTION_ID`, `YOUR_TENANT_ID`, `YOUR_CLIENT_ID`, and `YOUR_CLIENT_SECRET` with the actual values from the Service Principal you created in Part 1.

**Alternative Method - Manual Secret Creation:**

If you prefer to create the secret separately or need to update credentials later:

```bash
# Create the aso-controller-settings secret with Azure credentials
kubectl create secret generic aso-controller-settings \
    --namespace azureserviceoperator-system \
    --from-literal=AZURE_SUBSCRIPTION_ID='YOUR_SUBSCRIPTION_ID' \
    --from-literal=AZURE_TENANT_ID='YOUR_TENANT_ID' \
    --from-literal=AZURE_CLIENT_ID='YOUR_CLIENT_ID' \
    --from-literal=AZURE_CLIENT_SECRET='YOUR_CLIENT_SECRET'

# Restart ASO pods to pick up the new credentials
kubectl rollout restart deployment azureserviceoperator-controller-manager -n azureserviceoperator-system
```

### Verify ASO Installation

```bash
# Check if ASO pods are running
kubectl get pods -n azureserviceoperator-system

# Verify the aso-controller-settings secret exists
kubectl get secret aso-controller-settings -n azureserviceoperator-system

# Check ASO Custom Resource Definitions
kubectl get crd | grep azure

# Check ASO operator logs for successful Azure authentication
kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager
```

You should see output similar to:
```
NAME                                                    READY   STATUS    RESTARTS   AGE
azureserviceoperator-controller-manager-xxxxxxxxx-xxx   2/2     Running   0          2m
```

The secret should exist:
```
NAME                       TYPE     DATA   AGE
aso-controller-settings    Opaque   4      2m
```

### ✅ Verification Steps - Part 2

Let's verify ASO is working correctly:

```bash
# Verify ASO pod is running and ready
kubectl get pods -n azureserviceoperator-system

# Verify the aso-controller-settings secret contains Azure credentials
kubectl get secret aso-controller-settings -n azureserviceoperator-system
kubectl describe secret aso-controller-settings -n azureserviceoperator-system

# Check that ASO CRDs are installed
kubectl get crd | grep azure | wc -l
# Should show many CRDs (100+)

# View some example CRDs
kubectl get crd | grep azure | head -5

# Check ASO is connected to Azure and authenticated successfully
kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager --tail=50 | grep -i "successfully"
```

**Expected Output:**
- ASO pod should show 2/2 containers READY and status Running
- The `aso-controller-settings` secret should exist with 4 data entries (AZURE_SUBSCRIPTION_ID, AZURE_TENANT_ID, AZURE_CLIENT_ID, AZURE_CLIENT_SECRET)
- Many Azure-related CRDs should be installed (100+)
- Logs should show successful startup and Azure authentication

### 🤔 Reflection Questions - Part 2

Consider what you've just installed:

1. **Kubernetes Operators**: ASO is a Kubernetes operator. What is an operator, and how does it differ from a regular Kubernetes controller?

2. **Custom Resource Definitions**: ASO installed many CRDs. What is a CRD, and why does ASO need so many of them?

3. **Secret Management**: The Service Principal credentials are stored in a Kubernetes secret. How does ASO access these credentials? What are the security implications?

4. **Namespace Isolation**: ASO runs in the `azureserviceoperator-system` namespace. Why do we install it in its own namespace rather than the default namespace?

5. **Resource Scope**: ASO can create Azure resources from any namespace in the cluster. How might you control which namespaces can create which types of Azure resources?

## Part 3: Creating a GitHub Repository for Azure Resources

### Set Up GitHub Repository

We'll use the same `platform-self-service` repository from LAB02 to manage Azure resources. This maintains continuity and allows all self-service requests (namespaces, Azure resources, etc.) to flow through the same Git repository.

```bash
# Navigate to your platform-self-service repository from LAB02
cd ~/platform-self-service

# Create directory structure for Azure resources
mkdir -p azure-resources/resource-groups azure-resources/storage-accounts

# Update README to include Azure resources
cat << 'EOF' >> README.md

## Azure Resources

This repository also contains Azure resource definitions managed through Azure Service Operator and ArgoCD.

### Structure

- `azure-resources/resource-groups/` - Azure Resource Group definitions
- `azure-resources/storage-accounts/` - Azure Storage Account definitions

### Workflow

1. Define Azure resources as Kubernetes manifests
2. Commit and push changes to GitHub
3. ArgoCD automatically syncs and applies changes
4. Azure Service Operator creates/updates Azure resources
EOF

# Initial commit for Azure resources structure
git add .
git commit -m "Add Azure resources directory structure"
git push origin main
```

**Note**: We're extending the `platform-self-service` repository from LAB02 rather than creating a new repository. This keeps all platform resources in one place and maintains a continuous story throughout the workshop.

### Create Azure Resource Definitions

Let's create simple Azure resource manifests:

```bash
# Create a Resource Group manifest
cat << 'EOF' > azure-resources/resource-groups/workshop-rg.yaml
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: workshop-rg
  namespace: default
spec:
  location: swedencentral
  tags:
    environment: workshop
    managed-by: azure-service-operator
    workshop: platform-engineering
EOF

# Create a Storage Account manifest
# Note: Storage account names must be globally unique, lowercase, 3-24 chars
# Replace 'uniqueid' with your initials and a random number
cat << 'EOF' > azure-resources/storage-accounts/workshop-storage.yaml
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: workshopstorageuniqueid
  namespace: default
spec:
  location: swedencentral
  kind: StorageV2
  sku:
    name: Standard_LRS
  owner:
    name: workshop-rg
  accessTier: Hot
  tags:
    environment: workshop
    managed-by: azure-service-operator
EOF

# Create additional examples for team-specific namespaces (created in LAB02)
# These show how teams can deploy Azure resources in their own namespaces
cat << 'EOF' > azure-resources/resource-groups/frontend-team-rg.yaml
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: frontend-team-rg
  namespace: devops-frontend-dev
spec:
  location: swedencentral
  tags:
    environment: dev
    team: frontend
    managed-by: azure-service-operator
    workshop: platform-engineering
EOF

cat << 'EOF' > azure-resources/storage-accounts/frontend-team-storage.yaml
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: frontendstorageuniqueid
  namespace: devops-frontend-dev
spec:
  location: swedencentral
  kind: StorageV2
  sku:
    name: Standard_LRS
  owner:
    name: frontend-team-rg
  accessTier: Hot
  tags:
    environment: dev
    team: frontend
    managed-by: azure-service-operator
EOF

# Commit and push to GitHub
git add .
git commit -m "Add Resource Group and Storage Account definitions

- Default namespace resources for shared infrastructure
- Team-specific resources in devops namespaces from LAB02
- Demonstrates multi-tenant Azure resource management"
git push origin main
```

**Important Notes:**
- Storage account names must be globally unique across all of Azure
- Use only lowercase letters and numbers, no hyphens or special characters
- Replace `uniqueid` in the storage account name with your initials + random numbers (e.g., `workshopstoragejd12345`, `frontendstorageab67890`)
- Team-specific resources are deployed in their dedicated namespaces (e.g., `devops-frontend-dev` from LAB02)
- This enables multi-tenant Azure resource management where teams can manage their own cloud resources

### ✅ Verification Steps - Part 3

Verify your GitHub repository is set up correctly:

```bash
# Verify your repository structure
ls -la ~/platform-self-service/
tree ~/platform-self-service/

# Check git status and remotes
cd ~/platform-self-service
git status
git remote -v

# Verify files are pushed to GitHub
# Visit: https://github.com/$GITHUB_USERNAME/platform-self-service
# You should see your azure-resources folder there
```

**Expected Output:**
- Directory structure with `azure-resources/resource-groups/` and `azure-resources/storage-accounts/` folders
- Git remote pointing to your GitHub platform-self-service repository
- Files visible on GitHub web interface

### 🤔 Reflection Questions - Part 3

Think about the GitOps workflow:

1. **Repository Structure**: Why did we organize resources into separate directories (`resource-groups/`, `storage-accounts/`)? What advantages does this provide?

2. **Resource Dependencies**: The Storage Account references the Resource Group via the `owner` field. What happens if you try to create the Storage Account before the Resource Group exists?

3. **Naming Constraints**: Azure Storage Accounts have strict naming requirements (globally unique, lowercase, no hyphens). How would you ensure unique names in a multi-team environment?

4. **Git as Source of Truth**: With GitOps, the Git repository is the "source of truth" for infrastructure. What happens if someone creates an Azure resource manually in the portal instead of through Git?

5. **Public vs Private Repository**: We created a public repository. In a real company setting, would you use public or private? What are the security implications?

6. **API Versions**: Notice the `apiVersion` fields (e.g., `v1api20200601`, `v1api20230101`). Why do these CRDs have dates in their API versions? What does this tell you about Azure's API evolution?

## Part 4: Connecting ArgoCD to Your GitHub Repository

### Add GitHub Repository to ArgoCD

First, configure ArgoCD to access your GitHub repository:

```bash
# Add your GitHub repository to ArgoCD
# For public repositories:
argocd repo add https://github.com/$GITHUB_USERNAME/platform-self-service.git

# For private repositories, you'll need a token:
# argocd repo add https://github.com/$GITHUB_USERNAME/platform-self-service.git \
#   --username $GITHUB_USERNAME \
#   --password $GITHUB_TOKEN

# Verify the repository was added
argocd repo list
```

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

  # Source repositories - update with your GitHub username
  sourceRepos:
  - 'https://github.com/*/platform-self-service.git'

  # Destination clusters and namespaces
  destinations:
  - namespace: default
    server: https://kubernetes.default.svc
  - namespace: azureserviceoperator-system
    server: https://kubernetes.default.svc
  - namespace: 'devops-*'
    server: https://kubernetes.default.svc

  # Allowed Kubernetes resources - supporting all ASO resource types
  clusterResourceWhitelist:
  - group: 'resources.azure.com'
    kind: '*'
  - group: 'storage.azure.com'
    kind: '*'
  - group: 'keyvault.azure.com'
    kind: '*'
  - group: 'managedidentity.azure.com'
    kind: '*'
  - group: 'compute.azure.com'
    kind: '*'
  - group: 'network.azure.com'
    kind: '*'
  - group: 'sql.azure.com'
    kind: '*'
  - group: 'web.azure.com'
    kind: '*'
  - group: 'cache.azure.com'
    kind: '*'
  - group: 'containerservice.azure.com'
    kind: '*'

  namespaceResourceWhitelist:
  - group: 'resources.azure.com'
    kind: '*'
  - group: 'storage.azure.com'
    kind: '*'
  - group: 'keyvault.azure.com'
    kind: '*'
  - group: 'managedidentity.azure.com'
    kind: '*'
  - group: 'compute.azure.com'
    kind: '*'
  - group: 'network.azure.com'
    kind: '*'
  - group: 'sql.azure.com'
    kind: '*'
  - group: 'web.azure.com'
    kind: '*'
  - group: 'cache.azure.com'
    kind: '*'
  - group: 'containerservice.azure.com'
    kind: '*'
EOF

# Apply the project
kubectl apply -f /tmp/azure-project.yaml

# Verify project was created
argocd proj get azure-resources
```

### Create ArgoCD ApplicationSet

Now create an ArgoCD ApplicationSet that monitors your GitHub repository for changes and automatically deploys Azure resources from multiple directories:

```bash
# Create the Azure resources ApplicationSet
# Replace $GITHUB_USERNAME with your GitHub username
cat << EOF > /tmp/azure-resources-applicationset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: azure-resources
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/$GITHUB_USERNAME/platform-self-service.git
        revision: HEAD
        directories:
          - path: azure-resources/*
  template:
    metadata:
      name: 'azure-{{path.basename}}'
    spec:
      project: azure-resources
      source:
        repoURL: https://github.com/$GITHUB_USERNAME/platform-self-service.git
        targetRevision: HEAD
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: default
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=false
EOF

# Apply the ApplicationSet
kubectl apply -f /tmp/azure-resources-applicationset.yaml

# Check the ApplicationSet was created
kubectl get applicationset -n argocd | grep azure-resources

# The ApplicationSet will automatically generate Applications for each subdirectory under azure-resources/
# Check which applications were generated
argocd app list | grep azure

# Watch the generated applications sync
# For example, if you have azure-resources/resource-groups/ and azure-resources/storage-accounts/
# You'll see applications like: azure-resource-groups, azure-storage-accounts
argocd app get azure-resource-groups
argocd app get azure-storage-accounts
```

**Why use an ApplicationSet instead of a single Application?**

The ApplicationSet approach provides several benefits:
1. **Automatic Discovery**: When you add a new subdirectory under `azure-resources/` (e.g., `azure-resources/key-vaults/`), ArgoCD automatically generates a new application for it
2. **Better Organization**: Each resource type (resource groups, storage accounts, etc.) is managed as a separate application, making it easier to track sync status and troubleshoot issues
3. **Scalability**: As your platform grows and you add more Azure resource types, you don't need to manually create new ArgoCD applications
4. **Consistency**: All generated applications follow the same pattern and configuration defined in the ApplicationSet template
5. **Similar to LAB02**: This follows the same pattern used for namespace management in LAB02, providing a consistent experience across different resource types

### Monitor Azure Resource Creation

```bash
# Watch the Resource Group being created
kubectl get resourcegroup workshop-rg --watch

# In another terminal, watch the Storage Account
kubectl get storageaccount --watch

# Check detailed status
kubectl describe resourcegroup workshop-rg
kubectl describe storageaccount workshopstorage<your-unique-id>
```

### Verify in Azure

```bash
# Verify resources exist in Azure
az group list --output table | grep workshop

# Check the storage account
az storage account list --resource-group workshop-rg --output table

# View resource details
az group show --name workshop-rg --output yaml
```

### ✅ Verification Steps - Part 4

Verify the complete GitOps workflow:

```bash
# Check ArgoCD ApplicationSet status
kubectl get applicationset azure-resources -n argocd

# Check the generated applications
argocd app list | grep azure

# Get status of individual generated applications
argocd app get azure-resource-groups
argocd app get azure-storage-accounts

# Verify resources in Kubernetes
kubectl get resourcegroup,storageaccount

# Check ArgoCD applications have synced successfully
# The applications should show "Healthy" and "Synced"
argocd app get azure-resource-groups | grep -E "(Health|Sync)"
argocd app get azure-storage-accounts | grep -E "(Health|Sync)"

# Verify in Azure
az group show --name workshop-rg --output table
az storage account show --name workshopstorage<your-id> --resource-group workshop-rg --output table
```

**Expected Output:**
- ArgoCD ApplicationSet `azure-resources` exists
- Multiple generated applications visible (e.g., `azure-resource-groups`, `azure-storage-accounts`)
- Each generated application shows status "Healthy" and "Synced"
- Resources visible in both Kubernetes (`kubectl get`) and Azure (`az` commands)
- ArgoCD UI shows your ApplicationSet and generated applications with all resources green/healthy

### 🤔 Reflection Questions - Part 4

Reflect on the GitOps workflow you've created:

1. **Automated Sync**: We enabled automated sync with `--auto-prune` and `--self-heal`. What do these options mean? What happens when you push changes to GitHub?

2. **Source of Truth**: Now that ArgoCD is managing your Azure resources, what happens if you:
   - Modify a resource directly in Azure Portal?
   - Delete a resource using `kubectl delete`?
   - Change a value in your GitHub repository?

3. **Sync Cycle**: How long does it take for a change in GitHub to appear in Azure? What are all the steps involved in this process?

4. **Project Isolation**: The `azure-resources` project can only create certain resource types. Why is this restriction important? What could happen without it?

5. **Failure Scenarios**: What happens if:
   - ASO fails to create a resource in Azure (e.g., invalid region)?
   - GitHub is temporarily unavailable?
   - The Service Principal credentials expire?

6. **Visibility and Debugging**: If an Azure resource fails to create, where would you look to diagnose the problem? What tools and commands would you use?

## Part 5: Testing the GitOps Workflow

### Make a Change Through Git

Let's test the complete GitOps workflow by making a change:

```bash
# Navigate to your repository
cd ~/platform-self-service

# Add a tag to the Resource Group
cat << 'EOF' > azure-resources/resource-groups/workshop-rg.yaml
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: workshop-rg
  namespace: default
spec:
  location: swedencentral
  tags:
    environment: workshop
    managed-by: azure-service-operator
    workshop: platform-engineering
    updated: "true"
    date: "2024-01"
EOF

# Commit and push the change
git add azure-resources/resource-groups/workshop-rg.yaml
git commit -m "Add additional tags to resource group"
git push origin main
```

### Watch ArgoCD Sync the Change

```bash
# ArgoCD will automatically detect and sync the change
# Watch the resource-groups application update (since we changed a resource group)
argocd app get azure-resource-groups --watch

# Check the resource in Kubernetes
kubectl describe resourcegroup workshop-rg | grep -A 10 "tags:"

# Verify in Azure
az group show --name workshop-rg --query tags
```

### ✅ Verification Steps - Part 5

Verify the GitOps workflow worked:

```bash
# Check ArgoCD synced the change (for the resource-groups application)
argocd app get azure-resource-groups

# Verify tags were updated in Kubernetes
kubectl get resourcegroup workshop-rg -o yaml | grep -A 10 "tags:"

# Verify tags in Azure
az group show --name workshop-rg --output table
az group show --name workshop-rg --query tags --output yaml
```

**Expected Output:**
- ArgoCD shows a recent sync timestamp for the azure-resource-groups application
- New tags visible in both Kubernetes and Azure
- The change propagated from Git → ArgoCD → Kubernetes → Azure

### 🤔 Reflection Questions - Part 5

Think about what you've accomplished:

1. **GitOps Workflow**: Trace the complete path of your change from Git commit to Azure resource update. How long did it take? What components were involved?

2. **Drift Detection**: What would happen if someone manually added a tag in Azure Portal that wasn't in the Git repository? How would ArgoCD handle this?

3. **Rollback Capability**: If you needed to rollback this change, how would you do it? What are the advantages of using Git for infrastructure changes?

4. **Change Approval**: In a production environment, how could you add approval gates before changes are deployed to Azure?

5. **Audit Trail**: Where can you see the history of all changes made to your Azure resources? How does GitOps help with compliance and auditing?

## Troubleshooting

### Common Issues and Solutions

#### Issue: Service Principal Authentication Fails

```bash
# Check if credentials are correctly configured
kubectl get secret aso-controller-settings -n azureserviceoperator-system

# Verify the secret has all required fields
kubectl describe secret aso-controller-settings -n azureserviceoperator-system

# Verify ASO can authenticate to Azure
kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager | grep -i "auth"

# Solution: Verify your Service Principal credentials are correct
# If the secret is missing or incorrect, recreate it:
kubectl delete secret aso-controller-settings -n azureserviceoperator-system

kubectl create secret generic aso-controller-settings \
    --namespace azureserviceoperator-system \
    --from-literal=AZURE_SUBSCRIPTION_ID='YOUR_SUBSCRIPTION_ID' \
    --from-literal=AZURE_TENANT_ID='YOUR_TENANT_ID' \
    --from-literal=AZURE_CLIENT_ID='YOUR_CLIENT_ID' \
    --from-literal=AZURE_CLIENT_SECRET='YOUR_CLIENT_SECRET'

# Restart ASO to pick up the updated credentials
kubectl rollout restart deployment azureserviceoperator-controller-manager -n azureserviceoperator-system
```

#### Issue: Resource Creation Stuck or Failing

```bash
# Check resource status and events
kubectl describe resourcegroup workshop-rg
kubectl describe storageaccount <your-storage-name>

# Check ASO operator logs for specific errors
kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager --tail=100

# Common causes:
# - Storage account name not globally unique
# - Invalid Azure region name (use 'swedencentral' not 'Sweden Central')
# - Service Principal lacks required permissions
# - Azure subscription quota limits reached
```

#### Issue: ArgoCD Won't Sync

```bash
# Check ApplicationSet status
kubectl get applicationset azure-resources -n argocd

# Check application health and sync status for generated applications
argocd app get azure-resource-groups --refresh
argocd app get azure-storage-accounts --refresh

# Check for sync errors on any generated application
argocd app get azure-resource-groups
argocd app get azure-storage-accounts

# Force a manual sync on specific applications
argocd app sync azure-resource-groups --prune
argocd app sync azure-storage-accounts --prune

# Verify ArgoCD can access your GitHub repository
argocd repo list
```

#### Issue: Storage Account Name Conflicts

```bash
# Check if storage account name is available
az storage account check-name --name your-storage-name

# Solution: Use a unique suffix
# Example: workshopstorage + your initials + random numbers
# e.g., workshopstoragejd98765
```

### ✅ Final Verification

Before finishing this lab, verify everything is working:

```bash
# Check ArgoCD ApplicationSet is healthy
kubectl get applicationset azure-resources -n argocd

# Check all generated applications are healthy
argocd app list | grep azure
argocd app get azure-resource-groups
argocd app get azure-storage-accounts

# Verify Azure resources exist in Kubernetes (all namespaces)
kubectl get resourcegroup,storageaccount --all-namespaces

# Verify resources exist in Azure
az group list --output table | grep workshop
az storage account list --output table | grep workshop

# Check ASO is running well
kubectl get pods -n azureserviceoperator-system

# Verify the expanded ArgoCD project permissions
argocd proj get azure-resources

# If you created the frontend team resources, verify them:
kubectl get resourcegroup,storageaccount -n devops-frontend-dev 2>/dev/null || echo "Frontend team resources not deployed"
```

**Expected State:**
- ✅ ArgoCD ApplicationSet `azure-resources` exists and is healthy
- ✅ Multiple generated applications visible (e.g., `azure-resource-groups`, `azure-storage-accounts`)
- ✅ Each generated application shows "Healthy" and "Synced"
- ✅ ArgoCD project supports all ASO resource types and devops-* namespaces
- ✅ Resource Groups visible in both Kubernetes and Azure (in default and/or devops namespaces)
- ✅ Storage Accounts visible in both Kubernetes and Azure
- ✅ ASO pod running without errors
- ✅ GitHub repository contains resource definitions organized in subdirectories under azure-resources/
- ✅ Resources can be deployed to namespaces created in LAB02 (devops-frontend-dev, devops-backend-dev, etc.)

### 🤔 Final Reflection Questions

Take a moment to reflect on the entire lab:

1. **Platform Engineering Value**: How does managing Azure resources through ASO and GitOps compare to creating them manually in Azure Portal or using ARM templates?

2. **Developer Experience**: If you were a developer on a team, would you prefer this approach or traditional cloud management? Why?

3. **Multi-Cloud Strategy**: ASO is specific to Azure. How would you handle a multi-cloud environment with AWS and GCP? What patterns could you apply from this lab?

4. **Self-Service Platform**: How could you extend this setup to allow development teams to request Azure resources without platform team involvement?

5. **Production Readiness**: What additional components would you need for a production-ready setup (monitoring, security, cost management, etc.)?

6. **Multi-Tenant Architecture**: With the updated ArgoCD project supporting devops-* namespaces, how does this enable teams from LAB02 to manage their own Azure resources? What isolation and governance benefits does this provide?

7. **Kubernetes as Control Plane**: We used Kubernetes as a control plane for Azure resources. What are the pros and cons of this approach?

## Cleanup (Optional)

If you want to clean up all resources created in this lab:

```bash
# Delete the ArgoCD ApplicationSet (this will remove all generated applications and Azure resources)
kubectl delete applicationset azure-resources -n argocd

# Alternatively, delete individual generated applications
# argocd app delete azure-resource-groups --cascade
# argocd app delete azure-storage-accounts --cascade

# Wait for Azure resources to be deleted (check all namespaces)
kubectl get resourcegroup,storageaccount --all-namespaces --watch

# Delete the ArgoCD project
kubectl delete appproject azure-resources -n argocd

# Optionally, uninstall ASO
helm uninstall aso2 -n azureserviceoperator-system
kubectl delete namespace azureserviceoperator-system
```

## Next Steps

Congratulations! You now have:
- ✅ Azure Service Operator installed and configured
- ✅ GitHub repository for Azure resource management
- ✅ GitOps workflow for Azure resources via ArgoCD
- ✅ Understanding of cloud resource management through Kubernetes
- ✅ Experience with infrastructure as code using ASO

You're ready for **LAB04** where we'll explore advanced concepts including:
- Custom abstractions that hide Azure resource complexity
- Developer-friendly interfaces for your platform
- Platform API design
- Higher-level platform concepts that make self-service even easier

### Key Takeaways

From this lab, you should understand:

1. **Operators Extend Kubernetes**: ASO demonstrates how Kubernetes operators can manage resources outside the cluster
2. **GitOps for Everything**: The GitOps pattern works for infrastructure, not just applications
3. **Declarative Infrastructure**: Describing desired state in Git is more maintainable than imperative scripts
4. **Single Control Plane**: Kubernetes can serve as a unified control plane for both applications and infrastructure
5. **Platform Thinking**: By abstracting cloud resources behind Kubernetes APIs, you enable consistent workflows

## Resources and Further Learning

- [Azure Service Operator Documentation](https://azure.github.io/azure-service-operator/)
- [Azure Service Operator GitHub Repository](https://github.com/Azure/azure-service-operator)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Principles](https://opengitops.dev/)
- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)

### Useful Commands Reference

```bash
# ASO Resource Management
kubectl get resourcegroup
kubectl get storageaccount
kubectl describe resourcegroup <name>
kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager

# ArgoCD Management
argocd app list
argocd app get azure-resources
argocd app sync azure-resources
argocd repo list

# Azure CLI Verification
az group list --output table
az storage account list --output table
az group show --name <resource-group-name>
```
