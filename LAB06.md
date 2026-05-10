# LAB06: Deploying with Crossplane

Welcome to LAB06! In this lab, you'll learn how to provision cloud resources using Crossplane — the Kubernetes-native control plane framework. By the end of this lab, you'll have:

- Installed Crossplane in your Kind cluster
- Configured the Azure provider using your existing Service Principal
- Deployed Azure resources directly as Managed Resources
- Created an abstraction layer (Composition) so developers use a simple API
- Delivered self-service infrastructure via Claims and ArgoCD GitOps
- (Stretch) Provisioned a GitHub repository using the GitHub provider

## Prerequisites

Before starting, ensure you have completed:
- ✅ **LAB01**: Your local environment should have:
  - Kind cluster running with NGINX ingress
  - ArgoCD installed and accessible
  - `kubectl` configured and working
- ✅ **LAB02**: Multi-tenant ArgoCD setup with:
  - Self-service ArgoCD projects configured
  - Understanding of GitOps workflows
- ✅ **LAB03**: Azure integration with:
  - Azure CLI installed and configured
  - Azure Service Principal created (we'll reuse this)
  - Azure subscription access

**Additional Requirements for this lab:**
- ✅ **Helm**: Kubernetes package manager (used in LAB03 — already installed)
- ✅ **kubectl**: Already installed from LAB01

## Overview

In LAB03 we used Azure Service Operator (ASO) — Microsoft's operator that translates Kubernetes manifests into ARM API calls. In LAB05 we used Terranetes to bring Terraform/OpenTofu into Kubernetes. Now we'll explore a third approach: **Crossplane**.

### What is Crossplane?

Crossplane is a CNCF project (graduated 2024) that turns your Kubernetes cluster into a **universal control plane** for cloud infrastructure. It provides:

- **Managed Resources**: 1:1 mappings to cloud resources (like ASO, but provider-agnostic)
- **Compositions**: Platform engineering abstractions — combine multiple resources behind a single API
- **Claims**: The developer-facing API — simple, opinionated, self-service
- **Multi-Provider**: One cluster can manage Azure, AWS, GCP, GitHub, and 100+ providers simultaneously

### Crossplane vs ASO vs Terranetes

| Feature | ASO (LAB03) | Terranetes (LAB05) | Crossplane (LAB06) |
|---------|-------------|-------------------|-------------------|
| Approach | Kubernetes operator | IaC (Terraform) in K8s | Control plane framework |
| Abstraction | CRDs only | Revisions / Plans | XRD + Composition + Claims |
| Multi-provider | Azure only | Any Terraform provider | 100+ native providers |
| State management | Azure (ARM) | Terraform state in K8s | Kubernetes etcd |
| Best for | Azure-only shops | Existing Terraform users | Platform engineering teams |

### What We'll Build

```
Git Claim → ArgoCD → AppStorageClaim → Composition → ResourceGroup + StorageAccount (Azure)
```

## Part 1: Install Crossplane

### Install Crossplane via Helm

Crossplane is distributed as a Helm chart from its stable repository.

```bash
# Add the Crossplane Helm repository
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

# Install Crossplane in its own namespace
helm install crossplane \
  --namespace crossplane-system \
  --create-namespace \
  crossplane-stable/crossplane \
  --wait

# Verify Crossplane is running
kubectl get pods -n crossplane-system
```

**Expected Output:**
```
NAME                                        READY   STATUS    RESTARTS   AGE
crossplane-xxxxxxxxxx-xxxxx                 1/1     Running   0          60s
crossplane-rbac-manager-xxxxxxxxxx-xxxxx    1/1     Running   0          60s
```

### Install the Crossplane CLI (kubectl plugin)

The Crossplane CLI (`crossplane`) provides useful commands for managing packages and debugging.

#### macOS / Linux
```bash
# Download and install the Crossplane CLI
curl -sL "https://raw.githubusercontent.com/crossplane/crossplane/main/install.sh" | sh
sudo mv crossplane /usr/local/bin
```

#### Windows
```powershell
# Download from GitHub releases
# https://github.com/crossplane/crossplane/releases
```

#### Verify Installation
```bash
crossplane version
# Example output:
# Client Version: v2.2.1
# Server Version: v2.2.1
```

### Verification Steps - Part 1

```bash
# Check Crossplane pods are Running
kubectl get pods -n crossplane-system

# Check Crossplane CRDs are installed
kubectl get crds | grep crossplane.io

# Verify the CLI
crossplane version
```

**Expected Output:**
- Two pods in Running state (crossplane and crossplane-rbac-manager)
- Several CRDs including `providers.pkg.crossplane.io`, `configurations.pkg.crossplane.io`
- Crossplane CLI version number

### Reflection Questions - Part 1

1. **Package Manager**: Crossplane uses a built-in package manager for providers. How does this differ from installing operators with `kubectl apply`?

2. **RBAC Manager**: Why does Crossplane run a separate RBAC manager alongside the main controller?

3. **Control Plane Philosophy**: Crossplane describes itself as "the cloud native control plane framework." What does "control plane" mean in this context, and how does it differ from a typical Kubernetes operator?

## Part 2: Configure the Azure Provider

### Install the Azure Provider Family

Crossplane uses **providers** — packages that add support for a specific platform (Azure, AWS, GitHub, etc.). The Upbound Azure provider family is the official, best-maintained option.

```bash
# Install the Azure providers (family + storage sub-provider)
kubectl apply -f lab06/crossplane/provider-family-azure.yaml

# Watch the providers install (this pulls provider packages — takes ~2 minutes)
kubectl get providers -w
```

You should see the providers move from `Installing` to `Healthy`:
```
NAME                              INSTALLED   HEALTHY   PACKAGE                                                  AGE
upbound-provider-azure-storage    True        True      xpkg.upbound.io/upbound/provider-azure-storage:v1        2m
upbound-provider-family-azure     True        True      xpkg.upbound.io/upbound/provider-family-azure:v1.13.1    2m
```

> **Note**: The `provider-azure-storage:v1` sub-provider requires `provider-family-azure` at a specific version (v1.13.1). The support file pins `provider-family-azure` to `v1.13.1` to ensure compatibility. The family provider installs CRDs for all Azure services; using sub-providers reduces the CRD footprint and speeds up installation.

### Create Azure Credentials Secret

We'll reuse the Service Principal from LAB03. The SP credentials need to be in a JSON format that Crossplane understands.

```bash
# Retrieve your Service Principal details from LAB03
# If you saved them as environment variables:
SP_CLIENT_ID="your-sp-client-id"
SP_CLIENT_SECRET="your-sp-client-secret"
SP_TENANT_ID=$(az account show --query tenantId -o tsv)
SP_SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create the credentials JSON file
cat > /tmp/azure-sp.json << EOF
{
  "clientId": "${SP_CLIENT_ID}",
  "clientSecret": "${SP_CLIENT_SECRET}",
  "subscriptionId": "${SP_SUBSCRIPTION_ID}",
  "tenantId": "${SP_TENANT_ID}",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
EOF

# Verify the JSON is valid
cat /tmp/azure-sp.json | python3 -m json.tool > /dev/null && echo "JSON is valid"

# Create the Kubernetes secret in crossplane-system
kubectl create secret generic azure-sp-creds \
  --from-literal=credentials="$(cat /tmp/azure-sp.json)" \
  --namespace crossplane-system

# Clean up the temporary file
rm /tmp/azure-sp.json

# Verify the secret was created
kubectl get secret azure-sp-creds -n crossplane-system
```

> **Security Note**: Never commit the Service Principal credentials to Git. The secret lives only in your Kubernetes cluster.

### Apply the ProviderConfig

```bash
kubectl apply -f lab06/crossplane/providerconfig-azure.yaml

# Verify the ProviderConfig is ready
kubectl get providerconfigs
```

**Expected Output:**
```
NAME      AGE   SECRET-NAME
default   10s   azure-sp-creds
```

### Verification Steps - Part 2

```bash
# All providers should be Healthy
kubectl get providers

# ProviderConfig should be Synced
kubectl get providerconfigs

# Check for any issues
kubectl describe providerconfig default
```

**Check for Azure CRDs from the provider:**
```bash
kubectl get crds | grep azure.upbound.io | head -10
```

### Reflection Questions - Part 2

1. **ProviderConfig vs Provider**: What is the difference between a `Provider` resource and a `ProviderConfig` resource in Crossplane?

2. **Credential Security**: We stored the SP credentials in a Kubernetes Secret. What are the security implications? How would you improve this in production (hint: look up Crossplane's External Secrets integration)?

3. **Provider Versioning**: The manifest pins the provider to `v1`. In production, should you pin to a specific version like `v1.5.2`? Why or why not?

## Part 3: Deploy Managed Resources Directly

**Managed Resources (MRs)** are the lowest-level Crossplane abstraction. Each MR maps directly to one Azure resource. This is similar to how ASO CRDs work in LAB03, but provider-agnostic.

### Update the Resource Names

Before applying, edit the manifests to use unique names:

```bash
# Edit the ResourceGroup manifest
# Replace "yourname" in crossplane.io/external-name
nano lab06/crossplane/managed-resources/resourcegroup.yaml
```

Use something like `rg-alice-crossplane-workshop` (replace `alice` with your name).

For the StorageAccount:
```bash
nano lab06/crossplane/managed-resources/storageaccount.yaml
```

Use something like `stalicecpworkshop` (storage account names: 3-24 lowercase alphanumeric, globally unique).

### Deploy the ResourceGroup

```bash
kubectl apply -f lab06/crossplane/managed-resources/resourcegroup.yaml

# Watch the reconciliation
kubectl get resourcegroup -w
```

You will see the status progress:
```
NAME           READY   SYNCED   EXTERNAL-NAME                           AGE
workshop-rg    False   True     rg-yourname-crossplane-workshop         5s
workshop-rg    True    True     rg-yourname-crossplane-workshop         45s
```

**When READY=True**, Crossplane has successfully created the Resource Group in Azure.

```bash
# Verify in Azure
az group list --query "[?name=='rg-yourname-crossplane-workshop']" -o table
```

### Deploy the StorageAccount

```bash
kubectl apply -f lab06/crossplane/managed-resources/storageaccount.yaml

# Watch the reconciliation
kubectl get accounts -w
```

```bash
# Describe the resource to see detailed status and any errors
kubectl describe accounts workshop-sa

# Verify in Azure
az storage account list --query "[?name=='styournamecpworkshop']" -o table
```

### Understand the Reconciliation Loop

Crossplane continuously reconciles the desired state (your YAML) against the actual state (Azure). Test this:

```bash
# 1. Find your Resource Group in Azure Portal and add a tag manually
#    (or via az CLI):
az group update \
  --name rg-yourname-crossplane-workshop \
  --set tags.manual-tag=oops

# 2. Wait ~30 seconds, then check:
az group show --name rg-yourname-crossplane-workshop --query tags

# Crossplane will remove the manual tag because it's not in the YAML spec!
```

> **Key Insight**: This is the **control plane** model. The Kubernetes spec is the source of truth — any drift is automatically corrected.

### Verification Steps - Part 3

```bash
# All Managed Resources should show READY=True, SYNCED=True
kubectl get resourcegroup,accounts

# Inspect the MR to see Azure-side details
kubectl describe resourcegroup workshop-rg

# Check the Azure side independently
az group show --name rg-yourname-crossplane-workshop -o table
az storage account show --name styournamecpworkshop -o table
```

### Reflection Questions - Part 3

1. **ASO vs Crossplane MRs**: Compare the ResourceGroup YAML in this lab with the ASO ResourceGroup YAML from LAB03. What are the key structural differences?

2. **Drift Correction**: We demonstrated that Crossplane corrects drift automatically. When is this useful? When might it cause problems?

3. **Annotations vs Spec**: The Azure resource name is set via `crossplane.io/external-name` annotation rather than in `spec`. Why do you think Crossplane uses this pattern?

## Part 4: Create a Composition

This is **the Crossplane superpower**. Instead of requiring developers to know about Resource Groups and Storage Accounts, we create a higher-level `AppStorage` concept — a platform abstraction owned by the platform team.

### Understand the Pieces

Crossplane compositions involve three resources:

| Resource | Who creates it | Purpose |
|----------|---------------|---------|
| **XRD** (CompositeResourceDefinition) | Platform team | Defines the new API (AppStorage concept) |
| **Composition** | Platform team | Maps AppStorage → specific Azure resources |
| **XR / Claim** | Developer | Requests an AppStorage instance |

### Apply the XRD

> **Note**: In Crossplane v2, `apiextensions.crossplane.io/v1` XRDs are deprecated. You will see a deprecation warning when applying — this is expected and not a blocker. The v2 XRD API does not yet support Claims, so v1 is still required for this lab.

```bash
kubectl apply -f lab06/crossplane/composition/xrd.yaml

# Verify the new CRD was created
kubectl get xrds
kubectl get crds | grep platform.workshop.io
```

**Expected Output:**
```
NAME                                    ESTABLISHED   OFFERED   AGE
xappstorages.platform.workshop.io       True          True      10s
```

Two new CRDs are now available in your cluster:
- `xappstorages.platform.workshop.io` — the Composite Resource (cluster-scoped, for platform team)
- `appstorageclaims.platform.workshop.io` — the Claim (namespace-scoped, for application teams)

### Install the Patch-and-Transform Function

Crossplane v2 compositions use **Pipeline mode** with composition functions instead of inline `spec.resources`. The `function-patch-and-transform` function provides the same patch-based resource templating as the older inline style.

```bash
# Install the function
kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1beta1
kind: Function
metadata:
  name: function-patch-and-transform
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.8.1
EOF

# Wait for it to be Healthy
kubectl get functions -w
```

**Expected Output:**
```
NAME                           INSTALLED   HEALTHY   PACKAGE                                                                  AGE
function-patch-and-transform   True        True      xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.8.1   30s
```

### Apply the Composition

```bash
kubectl apply -f lab06/crossplane/composition/composition.yaml

# Verify the Composition is installed and references the correct XRD
kubectl get compositions
kubectl describe composition appstorage-composition
```

**Expected Output:**
```
NAME                    XR-KIND        XR-APIVERSION                       AGE
appstorage-composition  XAppStorage    platform.workshop.io/v1alpha1       5s
```

### Test the Composition with a Direct XR (Optional)

Before exposing Claims to developers, you can test the Composition directly using a Composite Resource (XR). XRs are cluster-scoped — useful for platform team testing.

```bash
# Create a test XR
cat <<EOF | kubectl apply -f -
apiVersion: platform.workshop.io/v1alpha1
kind: XAppStorage
metadata:
  name: test-xr
spec:
  parameters:
    resourceGroupName: rg-yourname-xr-test
    storageAccountName: styournamexrtest
    location: swedencentral
    environment: workshop
  compositionRef:
    name: appstorage-composition
EOF

# Watch all resources being created (use separate commands — -w doesn't support multiple resource types)
kubectl get xappstorages -w &
kubectl get resourcegroups,accounts
```

When the XR is ready, you will see:
- The `XAppStorage` showing `SYNCED=True` and `READY=True`
- A new `ResourceGroup` MR created automatically
- A new `Account` (StorageAccount) MR created automatically

```bash
# Clean up the test XR (cascades to all child MRs and Azure resources)
kubectl delete xappstorages test-xr

# Verify MRs are gone too
kubectl get resourcegroups,accounts
```

### Verification Steps - Part 4

```bash
# XRD is established
kubectl get xrds

# Composition exists
kubectl get compositions

# CRDs for Claim and XR are available
kubectl api-resources | grep platform.workshop.io
```

### Reflection Questions - Part 4

1. **Abstraction Value**: A developer using `AppStorageClaim` only needs to know three things: `resourceGroupName`, `storageAccountName`, and `location`. A platform engineer using raw MRs needs to understand Azure provider CRDs, `resourceGroupNameRef` cross-references, and annotation conventions. What does this abstraction enable in a large organization?

2. **Composition vs Helm**: Both Compositions and Helm charts can bundle multiple resources behind a simpler interface. What are the key differences? When would you choose Composition over Helm?

3. **Patch Flow**: Look at `composition.yaml`. The `FromCompositeFieldPath` patches copy values from the Claim into MR specs. What happens if a developer omits `location` from their Claim?

## Part 5: Self-Service with Claims and ArgoCD

Now let's connect the Crossplane Composition to ArgoCD, completing the self-service loop: **Git commit → ArgoCD sync → Crossplane reconciles → Azure resources appear**.

### Set Up a Claims Directory in Your Git Repository

We'll use the GitOps repository from LAB02 (or create a new folder):

```bash
# In your GitOps repository (from LAB02)
mkdir -p crossplane-claims

# Copy the example Claim — edit names to be unique for you
cp lab06/crossplane/claims/app-storage-claim.yaml crossplane-claims/

# Edit the file
nano crossplane-claims/app-storage-claim.yaml
```

Replace the placeholder names in `app-storage-claim.yaml`:
```yaml
spec:
  parameters:
    resourceGroupName: rg-yourname-crossplane-claim   # Unique RG name
    storageAccountName: styournamecpclaim              # Unique SA name (3-24 chars)
    location: swedencentral
    environment: workshop
```

```bash
# Commit and push the Claim to your GitOps repo
git add crossplane-claims/
git commit -m "feat: add AppStorageClaim for team-alpha"
git push origin main
```

### Create the ArgoCD Application

Edit `lab06/crossplane/argocd/argocd-application.yaml` to point to your repository:

```bash
nano lab06/crossplane/argocd/argocd-application.yaml
```

Update these fields:
```yaml
source:
  repoURL: https://github.com/YOUR_GITHUB_ORG/YOUR_REPO.git  # Your GitOps repo
  targetRevision: HEAD
  path: crossplane-claims                                       # Directory with Claims
```

Apply the ArgoCD Application:
```bash
kubectl apply -f lab06/crossplane/argocd/argocd-application.yaml -n argocd

# Check the ArgoCD application
argocd app get crossplane-claims
argocd app sync crossplane-claims
```

### Watch the End-to-End Flow

```bash
# Terminal 1: Watch ArgoCD application
watch argocd app get crossplane-claims

# Terminal 2: Watch Claims
kubectl get appstorageclaims -n team-alpha -w

# Terminal 3: Watch underlying Managed Resources
kubectl get resourcegroups,accounts -w
```

You should observe:
1. ArgoCD detects the new YAML in Git → Application becomes `OutOfSync`
2. ArgoCD syncs → `AppStorageClaim` appears in `team-alpha` namespace
3. Crossplane processes the Claim → creates a `XAppStorage` XR
4. The Composition runs → creates `ResourceGroup` and `Account` MRs
5. The MRs reconcile against Azure → `READY=True`

### Verify in Azure Portal

```bash
# List resource groups created by Crossplane
az group list --query "[?tags.\"managed-by\"=='crossplane']" -o table

# List storage accounts
az storage account list --query "[?tags.\"managed-by\"=='crossplane']" -o table
```

### The Self-Service Loop

Now test the full developer self-service flow:

```bash
# Add a second Claim (simulating a second team or application)
cat <<EOF > crossplane-claims/app2-storage-claim.yaml
apiVersion: platform.workshop.io/v1alpha1
kind: AppStorageClaim
metadata:
  name: app2-storage
  namespace: team-alpha
spec:
  parameters:
    resourceGroupName: rg-yourname-crossplane-app2
    storageAccountName: styournamecpapp2
    location: swedencentral
    environment: workshop
  compositionRef:
    name: appstorage-composition
EOF

git add crossplane-claims/app2-storage-claim.yaml
git commit -m "feat: add AppStorageClaim for app2"
git push origin main

# ArgoCD will automatically sync and Crossplane will provision the resources
argocd app sync crossplane-claims
kubectl get appstorageclaims -n team-alpha -w
```

### Verification Steps - Part 5

```bash
# Claims are bound and ready
kubectl get appstorageclaims -n team-alpha

# ArgoCD application is Synced and Healthy
argocd app get crossplane-claims

# All MRs are READY=True
kubectl get resourcegroups,accounts

# Azure resources exist
az group list --query "[?tags.\"managed-by\"=='crossplane']" -o table
```

### Reflection Questions - Part 5

1. **Developer Experience**: A developer now creates infrastructure by committing a 15-line YAML file with 3 parameters. Compare this to the traditional process (raise a ticket → ops team → Terraform PR → review → apply). What does this mean for developer velocity?

2. **Platform Boundaries**: The Claim API exposes `resourceGroupName`, `storageAccountName`, `location`, and `environment`. As a platform engineer, what parameters would you *not* expose to developers, and why (hint: think `accountTier`, `accountReplicationType`, security settings)?

3. **GitOps + Crossplane**: ArgoCD manages the *desired state* of Claims in the cluster. Crossplane manages the *desired state* of Azure resources. How do these two control loops complement each other?

## Part 6 (Stretch): Add the GitHub Provider

This stretch goal demonstrates Crossplane's multi-provider capability: one cluster managing both Azure **and** GitHub resources, potentially from a single Claim.

### Install the GitHub Provider

```bash
# Apply the GitHub provider manifest (includes provider + ProviderConfig + example repo)
# Note: Apply just the Provider first — you need to create credentials before ProviderConfig

# Apply only the Provider resource
kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: crossplane-contrib-provider-github
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-github:v0.1.0
  packagePullPolicy: IfNotPresent
  revisionActivationPolicy: Automatic
EOF

# Wait for it to be healthy
kubectl get providers -w
```

### Create GitHub PAT Secret

Reuse the Personal Access Token from LAB05, or create a new one:

1. Go to https://github.com/settings/tokens
2. Click **"Generate new token"** → **"Generate new token (classic)"**
3. Name: `crossplane-workshop`
4. Scopes: `repo`, `delete_repo`
5. Click **"Generate token"** and copy immediately

```bash
# Create the GitHub credentials secret
kubectl create secret generic github-pat \
  --from-literal=credentials='{"token":"ghp_YOUR_PAT_HERE"}' \
  --namespace crossplane-system

# Apply the full provider manifest (ProviderConfig + example Repository MR)
kubectl apply -f lab06/crossplane/stretch/provider-github.yaml
```

### Provision a GitHub Repository

```bash
# Watch the GitHub repository being created
kubectl get repositories -w

# Verify in GitHub
# Go to https://github.com/YOUR_USERNAME — you should see workshop-crossplane-demo
```

### Explore Multi-Provider Possibilities

This is where Crossplane becomes uniquely powerful. A single `Composition` can create resources across **both** providers:

```yaml
# Conceptual example — a Composition that creates:
# 1. Azure Resource Group
# 2. Azure Storage Account
# 3. GitHub Repository (to store Bicep/ARM templates for the resources)
# All from a single Claim!
resources:
  - name: resource-group       # Azure MR
  - name: storage-account      # Azure MR
  - name: config-repo          # GitHub MR
```

This is a key differentiator from ASO (Azure only) and Terranetes (single-provider per CloudResource): **Crossplane orchestrates your entire infrastructure ecosystem from one control plane**.

### Verification Steps - Part 6

```bash
# GitHub provider is Healthy
kubectl get providers crossplane-contrib-provider-github

# ProviderConfig for GitHub is Synced
kubectl get providerconfigs

# GitHub repository MR is Ready
kubectl get repositories

# Verify on GitHub.com — check your repositories
```

### Reflection Questions - Part 6

1. **Multi-Provider vs Single-Provider**: ASO manages only Azure. Terranetes can manage multiple providers but through separate CloudResources. Crossplane can create Azure + GitHub resources from a single Claim. In what platform engineering scenarios is this multi-provider composition most valuable?

2. **Provider Ecosystem**: Crossplane has providers for AWS, GCP, Azure, GitHub, Helm, Kubernetes, Vault, and more. How does the breadth of providers change what you can put in a Composition?

3. **Abstraction Depth**: Could you create a Composition that, when a developer requests a new "AppEnvironment", creates: an Azure Resource Group + Storage Account + GitHub Repository + Kubernetes Namespace? What would the Claim look like?

## Cleanup

Clean up all resources created in this lab. **Important**: always delete Claims before MRs — Crossplane cascades deletes from Claims to all child resources and the underlying Azure resources.

### Delete Claims (Part 5)

```bash
# Deleting a Claim cascades:
# Claim → XR → MRs → Azure resources
kubectl delete appstorageclaims --all -n team-alpha

# Watch the cascade (use separate commands — -w doesn't support multiple resource types)
kubectl get appstorageclaims -n team-alpha -w &
kubectl get xappstorages,resourcegroups,accounts

# Verify Azure resources are gone
az group list --query "[?tags.\"managed-by\"=='crossplane']" -o table
```

### Delete Direct Managed Resources (Part 3)

```bash
# Deleting an MR directly deletes the Azure resource
kubectl delete accounts workshop-sa
kubectl delete resourcegroup workshop-rg

# Confirm deletion in Azure
az group list --query "[?starts_with(name,'rg-yourname')]" -o table
```

### Delete GitHub Resources (Stretch)

```bash
kubectl delete repositories workshop-crossplane-demo
kubectl delete providerconfig default-github
kubectl delete provider crossplane-contrib-provider-github
```

### Remove ArgoCD Application

```bash
argocd app delete crossplane-claims --yes

# Remove the Claims directory from your Git repo
git rm -r crossplane-claims/
git commit -m "cleanup: remove crossplane claims"
git push origin main
```

### Uninstall Providers and Crossplane

```bash
# Delete the ProviderConfig and Azure providers
kubectl delete providerconfig default
kubectl delete provider upbound-provider-azure-storage
kubectl delete provider upbound-provider-family-azure

# Uninstall Crossplane itself
helm uninstall crossplane -n crossplane-system
kubectl delete namespace crossplane-system

# Verify cleanup
kubectl get pods -n crossplane-system 2>&1 || echo "Namespace deleted"
```

### Final Verification

```bash
# Confirm no Crossplane resources remain
kubectl get providers 2>&1
kubectl get crds | grep crossplane.io
kubectl get crds | grep platform.workshop.io

# Confirm Azure resources are cleaned up
az group list --query "[?tags.\"managed-by\"=='crossplane']" -o table
```

## Summary

In this lab, you explored Crossplane's layered architecture:

| Layer | Resource | Audience |
|-------|----------|----------|
| Infrastructure | Managed Resources (ResourceGroup, Account) | Crossplane / Azure |
| Abstraction | XRD + Composition | Platform engineers |
| Self-service | Claims (AppStorageClaim) | Application developers |
| GitOps | ArgoCD Application | Platform engineers |

### Key Takeaways

1. **Crossplane = control plane**: It continuously reconciles desired state, unlike one-shot IaC tools
2. **Compositions are platform APIs**: They hide complexity and enforce platform standards
3. **Claims = developer experience**: Developers never need to know about ResourceGroups or ProviderConfigs
4. **Multi-provider strength**: One cluster, one control plane, any cloud or SaaS provider
5. **GitOps integration**: Crossplane claims flow naturally through ArgoCD just like application manifests

### Next Steps

- Explore more Azure providers: `provider-azure-network`, `provider-azure-sql`
- Add policy enforcement with [Crossplane Composition Functions](https://docs.crossplane.io/latest/concepts/composition-functions/)
- Integrate with External Secrets Operator for credential management
- Look at [Upbound Spaces](https://docs.upbound.io/spaces/) for production-grade Crossplane hosting
- Compare with [Kratix](https://kratix.io/) — another platform engineering framework built on Crossplane

## Additional Resources

- [Crossplane Documentation](https://docs.crossplane.io/)
- [Upbound Marketplace (providers)](https://marketplace.upbound.io/)
- [Crossplane Slack](https://slack.crossplane.io/)
- [CNCF Crossplane Project](https://www.cncf.io/projects/crossplane/)
- [Azure Provider Reference](https://marketplace.upbound.io/providers/upbound/provider-family-azure)
- [GitHub Provider Reference](https://marketplace.upbound.io/providers/crossplane-contrib/provider-github)
