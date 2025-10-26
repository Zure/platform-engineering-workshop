# LAB04B: Advanced Platform Concepts - Abstractions

Welcome to LAB04B! In this lab, you'll create higher-level abstractions for Azure resources using Kubernetes Resource Orchestrator (KRO). By the end of this lab, you'll have:

- Kubernetes Resource Orchestrator (KRO) installed in your cluster
- Understanding of how KRO creates custom abstractions
- App Concepts that simplify Azure resource provisioning
- Higher-level APIs that hide infrastructure complexity from developers
- Experience combining KRO with Azure Service Operator (ASO)

## Prerequisites

Before starting, ensure you have completed:
- ✅ **LAB01**: Your local environment should have:
  - Kind cluster running with NGINX ingress
  - ArgoCD installed and accessible
  - ArgoCD CLI configured and working
- ✅ **LAB02**: Multi-tenant ArgoCD setup with:
  - Self-service ArgoCD projects configured
  - Understanding of GitOps workflows
- ✅ **LAB03**: Azure Service Operator setup with:
  - ASO installed and configured
  - Azure credentials working
  - Resource Groups and Storage Accounts deployable
  - GitHub repository for Azure resources

## Overview

In LAB03, we deployed Azure resources directly using Azure Service Operator CRDs. While powerful, this approach requires developers to understand Azure-specific concepts like Storage Account SKUs, access tiers, and resource dependencies.

In this lab, we'll use **Kubernetes Resource Orchestrator (KRO)** to create higher-level abstractions that hide this complexity. Developers will request simple, application-focused resources like "Database" or "ObjectStorage", and KRO will automatically create the necessary Azure resources.

### What is Kubernetes Resource Orchestrator (KRO)?

KRO is a Kubernetes operator developed by the Azure team that allows platform engineers to:
- Define custom resource types (ResourceGroups) that represent app-level concepts
- Create templates that generate multiple Kubernetes resources from a single request
- Build abstractions that hide infrastructure complexity
- Compose complex resource topologies from simple user inputs

### The Abstraction Ladder

Think of resource management as a ladder:
1. **Bottom**: Azure Portal/CLI (manual, imperative)
2. **Middle**: ASO CRDs (declarative, but Azure-specific)
3. **Top**: KRO Abstractions (declarative, app-focused, cloud-agnostic)

### Lab Flow

1. Install KRO in your Kind cluster
2. Create a simple ResourceGroup to understand KRO concepts
3. Build an "AppDatabase" abstraction that creates Azure resources
4. Create an "AppStorage" abstraction for object storage
5. Deploy applications using your new abstractions
6. Connect everything to ArgoCD for GitOps

## Part 1: Updating Azure Service Operator for Additional Resources

Before installing KRO, we need to update Azure Service Operator (ASO) from LAB03 to include additional CRDs that LAB04B will use.

### Why Update ASO?

In LAB03, ASO was installed with a limited set of CRDs for resources and storage. LAB04B introduces abstractions that use **PostgreSQL Flexible Servers** (`dbforpostgresql.azure.com`), which require additional CRDs to be enabled in ASO.

### Update ASO Installation

```bash
# Update the ASO Helm installation to include PostgreSQL CRDs
# This adds dbforpostgresql.azure.com/* to the existing CRD pattern from LAB03
helm upgrade aso2 aso2/azure-service-operator \
    --namespace=azureserviceoperator-system \
    --reuse-values \
    --set crdPattern='resources.azure.com/*;storage.azure.com/*;keyvault.azure.com/*;managedidentity.azure.com/*;dbforpostgresql.azure.com/*'

# Wait for the upgrade to complete
kubectl rollout status deployment azureserviceoperator-controller-manager -n azureserviceoperator-system
```

### Verify New CRDs are Available

```bash
# Check that PostgreSQL CRDs are now installed
kubectl get crd | grep dbforpostgresql

# Expected output should show CRDs like:
# flexibleservers.dbforpostgresql.azure.com
# flexibleserversdatabases.dbforpostgresql.azure.com
# flexibleserversfirewallrules.dbforpostgresql.azure.com

# Verify ASO is still running correctly
kubectl get pods -n azureserviceoperator-system
```

**Expected Output:**
- New PostgreSQL-related CRDs should be visible
- ASO controller pod should be running and ready (2/2 containers)
- No errors in the ASO controller logs

### ✅ Verification Steps - ASO Update

```bash
# Verify the upgrade was successful
helm list -n azureserviceoperator-system

# Check ASO can now handle PostgreSQL resources
kubectl get crd | grep dbforpostgresql | wc -l
# Should show 10+ CRDs

# Verify no issues with existing resources from LAB03
kubectl get resourcegroup,storageaccount --all-namespaces
```

**Note**: Updating ASO with additional CRDs does not affect existing resources from LAB03. Your resource groups and storage accounts will continue to work normally.

## Part 2: Installing Kubernetes Resource Orchestrator

### Install KRO using Helm

KRO is installed using Helm charts from the Kubernetes registry:

```bash
# Fetch the latest release version from GitHub
export KRO_VERSION=$(curl -sL \
    https://api.github.com/repos/kubernetes-sigs/kro/releases/latest | \
    jq -r '.tag_name | ltrimstr("v")'
  )

# Validate KRO_VERSION populated with a version
echo $KRO_VERSION

# Install kro using Helm
helm install kro oci://registry.k8s.io/kro/charts/kro \
  --namespace kro \
  --create-namespace \
  --version=${KRO_VERSION}
```

**Note**: Authentication is not required for pulling charts from public OCI registries.

**Troubleshooting Helm Install**: Helm install download failures may occur due to expired local credentials. To resolve this issue, clear your local credentials cache by running `helm registry logout ghcr.io` in your terminal, then retry the installation.

### Verify KRO Installation

After running the installation command, verify that KRO has been installed correctly:

```bash
# Check the Helm release
helm -n kro list

# Expected result: You should see the "kro" release listed
# NAME	NAMESPACE	REVISION	STATUS  
# kro 	kro      	1       	deployed

# Check the kro pods
kubectl get pods -n kro

# Expected result: You should see kro-related pods running
# NAME                        READY   STATUS             RESTARTS   AGE
# kro-7d98bc6f46-jvjl5        1/1     Running            0           1s
```

### ✅ Verification Steps - Part 2

Let's verify KRO is installed correctly:

```bash
# Verify KRO pod is running and ready
kubectl get pods -n kro

# Check that KRO CRDs are installed
kubectl get crd | grep kro
# Should show: resourcegroups.kro.run

# Check the Helm release status
helm -n kro status kro

# Verify KRO is ready to create resource groups
kubectl api-resources | grep kro
```

**Expected Output:**
- Helm release "kro" should show status "deployed"
- KRO pod should show 1/1 containers READY and status Running
- The `resourcegroups.kro.run` CRD should be installed
- KRO should be running in the `kro` namespace (not `kro-system`)

### 🤔 Reflection Questions - Part 2

Take a moment to think about what KRO brings to the platform:

1. **Abstraction Layers**: We now have ASO (for Azure resources) and KRO (for abstractions). How do these work together? What is the role of each?

2. **Platform Engineering**: KRO lets platform engineers create custom resources. How is this different from developers creating custom CRDs directly?

3. **Namespace Isolation**: KRO runs in the `kro` namespace. What resources will it create, and where will those resources live?

4. **Comparison to Crossplane**: If you've heard of Crossplane, how might KRO be similar or different? What problems do both tools solve?

5. **Resource Types**: KRO creates ResourceGroups (capital G). How is this different from Azure Resource Groups? What does KRO's ResourceGroup represent?

## Part 3: Understanding KRO ResourceGroups

A KRO **ResourceGroup** (not to be confused with Azure Resource Groups) is a template that defines:
- What custom resource developers will create (the schema)
- What Kubernetes resources should be generated (the template)
- How user inputs map to generated resources (the logic)

### Create Your First ResourceGroup

Let's start with a simple example that creates an Azure Resource Group:

```bash
# Navigate to your platform-self-service repository from LAB02
cd ~/platform-self-service

# Create a directory for KRO definitions
mkdir -p kro-definitions

# Create a simple ResourceGroup that abstracts Azure Resource Groups
cat << 'EOF' > kro-definitions/app-namespace-rg.yaml
apiVersion: kro.run/v1alpha1
kind: ResourceGroup
metadata:
  name: appnamespace
  namespace: default
spec:
  # Define the schema - what developers will specify
  schema:
    apiVersion: v1alpha1
    kind: AppNamespace
    spec:
      # Developers only need to provide:
      appName:
        type: string
        description: "Name of the application"
      environment:
        type: string
        description: "Environment (dev, staging, prod)"
        default: "dev"
      location:
        type: string
        description: "Azure region"
        default: "swedencentral"

  # Define what resources to create
  resources:
  - id: resourcegroup
    template:
      apiVersion: resources.azure.com/v1api20200601
      kind: ResourceGroup
      metadata:
        name: ${schema.spec.appName}-${schema.spec.environment}-rg
        namespace: default
      spec:
        location: ${schema.spec.location}
        tags:
          app: ${schema.spec.appName}
          environment: ${schema.spec.environment}
          managed-by: kro
          created-by: platform-team
EOF

# Commit to Git
git add kro-definitions/
git commit -m "Add KRO ResourceGroup for App Namespace abstraction"
git push origin main
```

### Apply the ResourceGroup

```bash
# Apply the ResourceGroup definition
kubectl apply -f kro-definitions/app-namespace-rg.yaml

# Verify the ResourceGroup was created
kubectl get resourcegroup appnamespace -n default

# Check what CRD was created for developers
kubectl get crd | grep appnamespace
# Should show: appnamespaces.v1alpha1.example.com or similar
```

### Test the Abstraction

Now developers can use the simple `AppNamespace` resource:

```bash
# Create a test directory for developer resources
mkdir -p developer-resources

# Create an instance of AppNamespace
cat << 'EOF' > developer-resources/my-first-app.yaml
apiVersion: kro.run/v1alpha1
kind: AppNamespace
metadata:
  name: my-first-app
  namespace: default
spec:
  appName: myapp
  environment: dev
  location: swedencentral
EOF

# Apply it
kubectl apply -f developer-resources/my-first-app.yaml

# Watch the Azure Resource Group being created
kubectl get resourcegroup --watch
```

### Verify the Generated Resources

```bash
# Check that KRO created the Azure ResourceGroup
kubectl get resourcegroup -n default

# Verify in Azure
az group list --output table | grep myapp

# Check the AppNamespace status
kubectl describe appnamespace my-first-app

# Commit developer resource
git add developer-resources/
git commit -m "Add first app using KRO abstraction"
git push origin main
```

### ✅ Verification Steps - Part 3

Verify your first KRO abstraction works:

```bash
# Check the KRO ResourceGroup definition exists
kubectl get resourcegroup appnamespace -n default

# Verify the custom CRD was created
kubectl get crd | grep appnamespace

# Check the developer's AppNamespace instance
kubectl get appnamespace my-first-app -n default

# Verify the Azure Resource Group was created
kubectl get resourcegroup myapp-dev-rg -n default
az group show --name myapp-dev-rg --output table

# Check KRO controller logs for any issues
kubectl logs -n kro deployment/kro --tail=50
```

**Expected Output:**
- KRO ResourceGroup `appnamespace` should exist
- A new CRD for `AppNamespace` should be created
- The developer's `my-first-app` AppNamespace should exist
- An Azure Resource Group named `myapp-dev-rg` should be visible in both Kubernetes and Azure

### 🤔 Reflection Questions - Part 3

Think about what you've created:

1. **Schema vs Resources**: In the ResourceGroup, what's the difference between the `schema` section and the `resources` section? What purpose does each serve?

2. **Variable Substitution**: Notice the `${schema.spec.appName}` syntax. How does KRO use these variables? What happens when a developer creates an AppNamespace?

3. **Default Values**: The `environment` field has a default value of "dev". How does this simplify the developer experience?

4. **Developer Experience**: Compare creating an `AppNamespace` to creating Azure resources directly with ASO. What did we hide from developers? What did we simplify?

5. **Naming Conventions**: The generated Resource Group follows a pattern: `${appName}-${environment}-rg`. Why is consistent naming important in a platform?

6. **CRD Creation**: KRO automatically created a CRD for `AppNamespace`. Where did this CRD come from? Can you view it with `kubectl get crd`?

## Part 4: Creating an AppDatabase Abstraction

Now let's create a more complex abstraction that provisions a complete application database with all necessary Azure resources.

### Design the AppDatabase Abstraction

An application database in Azure might need:
- A Resource Group
- A PostgreSQL or MySQL server
- A database within that server
- Firewall rules
- Private endpoint (for production)

For this lab, we'll use Azure Database for PostgreSQL Flexible Server via ASO.

### Create the AppDatabase ResourceGroup

```bash
# Create the AppDatabase ResourceGroup definition
cat << 'EOF' > kro-definitions/app-database-rg.yaml
apiVersion: kro.run/v1alpha1
kind: ResourceGroup
metadata:
  name: appdatabase
  namespace: default
spec:
  # Define what developers specify
  schema:
    apiVersion: v1alpha1
    kind: AppDatabase
    spec:
      appName:
        type: string
        description: "Name of the application"
      environment:
        type: string
        description: "Environment (dev, staging, prod)"
        default: "dev"
      databaseType:
        type: string
        description: "Database type: postgresql or mysql"
        default: "postgresql"
        enum:
        - postgresql
        - mysql
      location:
        type: string
        description: "Azure region"
        default: "swedencentral"

  # Define what gets created
  resources:
  # 1. Resource Group for the database
  - id: database-rg
    template:
      apiVersion: resources.azure.com/v1api20200601
      kind: ResourceGroup
      metadata:
        name: ${schema.spec.appName}-${schema.spec.environment}-db-rg
        namespace: default
      spec:
        location: ${schema.spec.location}
        tags:
          app: ${schema.spec.appName}
          environment: ${schema.spec.environment}
          resource-type: database
          managed-by: kro

  # 2. PostgreSQL Flexible Server
  - id: postgresql-server
    template:
      apiVersion: dbforpostgresql.azure.com/v1api20230601preview
      kind: FlexibleServer
      metadata:
        name: ${schema.spec.appName}-${schema.spec.environment}-psql
        namespace: default
      spec:
        location: ${schema.spec.location}
        owner:
          name: ${resources.database-rg.metadata.name}
        sku:
          name: Standard_B1ms
          tier: Burstable
        administratorLogin: psqladmin
        administratorLoginPassword:
          name: ${schema.spec.appName}-db-password
          key: password
        storage:
          storageSizeGB: 32
        backup:
          backupRetentionDays: 7
          geoRedundantBackup: Disabled
        version: "15"
        tags:
          app: ${schema.spec.appName}
          environment: ${schema.spec.environment}
          managed-by: kro

  # 3. PostgreSQL Database
  - id: postgresql-database
    template:
      apiVersion: dbforpostgresql.azure.com/v1api20230601preview
      kind: FlexibleServersDatabase
      metadata:
        name: ${schema.spec.appName}-db
        namespace: default
      spec:
        owner:
          name: ${resources.postgresql-server.metadata.name}
        charset: UTF8
        collation: en_US.utf8

  # 4. Firewall rule to allow Azure services
  - id: firewall-rule
    template:
      apiVersion: dbforpostgresql.azure.com/v1api20230601preview
      kind: FlexibleServersFirewallRule
      metadata:
        name: ${schema.spec.appName}-allow-azure
        namespace: default
      spec:
        owner:
          name: ${resources.postgresql-server.metadata.name}
        startIpAddress: 0.0.0.0
        endIpAddress: 0.0.0.0  # Special Azure services rule
EOF

# Commit the ResourceGroup
git add kro-definitions/app-database-rg.yaml
git commit -m "Add AppDatabase abstraction for PostgreSQL"
git push origin main
```

### Apply the AppDatabase ResourceGroup

```bash
# Apply the AppDatabase ResourceGroup
kubectl apply -f kro-definitions/app-database-rg.yaml

# Verify it was created
kubectl get resourcegroup appdatabase -n default

# Check that the AppDatabase CRD was created
kubectl get crd | grep appdatabase
```

### Create Database Password Secret

Before creating a database, we need to create the password secret:

```bash
# Create a secret for the database password
kubectl create secret generic myapp-db-password \
  --from-literal=password='MySecureP@ssw0rd123!' \
  -n default

# Verify the secret
kubectl get secret myapp-db-password -n default
```

### Use the AppDatabase Abstraction

Now a developer can request a database with just a few lines:

```bash
# Create a database for an application
cat << 'EOF' > developer-resources/myapp-database.yaml
apiVersion: kro.run/v1alpha1
kind: AppDatabase
metadata:
  name: myapp-database
  namespace: default
spec:
  appName: myapp
  environment: dev
  databaseType: postgresql
  location: swedencentral
EOF

# Apply it
kubectl apply -f developer-resources/myapp-database.yaml

# Watch the resources being created
kubectl get resourcegroup,flexibleserver,flexibleserversdatabase --watch
```

### Monitor Resource Creation

```bash
# Check the AppDatabase status
kubectl describe appdatabase myapp-database

# Check generated resources
kubectl get resourcegroup | grep myapp
kubectl get flexibleserver | grep myapp

# This will take 5-10 minutes to provision in Azure
# Check the PostgreSQL server status
kubectl get flexibleserver ${schema.spec.appName}-${schema.spec.environment}-psql -o yaml | grep -A 10 "status:"

# Verify in Azure
az group show --name myapp-dev-db-rg --output table
az postgres flexible-server list --resource-group myapp-dev-db-rg --output table
```

### ✅ Verification Steps - Part 4

This step will take several minutes as Azure provisions the PostgreSQL server:

```bash
# Verify the AppDatabase ResourceGroup definition
kubectl get resourcegroup appdatabase -n default

# Check the developer's AppDatabase instance
kubectl get appdatabase myapp-database -n default
kubectl describe appdatabase myapp-database

# Verify all generated Azure resources in Kubernetes
kubectl get resourcegroup | grep myapp-dev-db-rg
kubectl get flexibleserver | grep myapp
kubectl get flexibleserversdatabase | grep myapp
kubectl get flexibleserversfirewallrule | grep myapp

# Verify in Azure (wait 5-10 minutes for provisioning)
az group show --name myapp-dev-db-rg --output table
az postgres flexible-server show --resource-group myapp-dev-db-rg --name myapp-dev-psql --output table

# Commit the developer resource
git add developer-resources/myapp-database.yaml
git commit -m "Request PostgreSQL database using AppDatabase abstraction"
git push origin main
```

**Expected Output:**
- AppDatabase ResourceGroup `appdatabase` exists
- Developer's `myapp-database` AppDatabase instance exists
- Multiple Azure resources created: Resource Group, PostgreSQL Server, Database, Firewall Rule
- Resources visible in both Kubernetes and Azure (after provisioning completes)

### 🤔 Reflection Questions - Part 4

Reflect on the AppDatabase abstraction:

1. **Resource Dependencies**: The PostgreSQL Database references the PostgreSQL Server via `owner.name`. How does KRO handle resource ordering and dependencies?

2. **Password Management**: We created a Kubernetes secret for the database password. How does this integrate with ASO? Is this secure for production?

3. **Developer Simplification**: Compare the AppDatabase manifest (8 lines) to the generated resources (100+ lines). What complexity did we hide?

4. **Environment-Specific Configuration**: How could you extend this abstraction to use different SKUs for dev vs production? Where would you add that logic?

5. **Resource IDs**: In the ResourceGroup, we defined IDs like `database-rg` and `postgresql-server`. How did we reference these IDs in the template? Why is this useful?

6. **Provisioning Time**: Azure database provisioning takes 5-10 minutes. How does this affect the developer experience? How could you communicate progress?

## Part 5: Creating an AppStorage Abstraction

Let's create another abstraction for object storage, which applications commonly need for storing files, images, or backups.

### Create the AppStorage ResourceGroup

```bash
# Create the AppStorage ResourceGroup definition
cat << 'EOF' > kro-definitions/app-storage-rg.yaml
apiVersion: kro.run/v1alpha1
kind: ResourceGroup
metadata:
  name: appstorage
  namespace: default
spec:
  # Define what developers specify
  schema:
    apiVersion: v1alpha1
    kind: AppStorage
    spec:
      appName:
        type: string
        description: "Name of the application"
      environment:
        type: string
        description: "Environment (dev, staging, prod)"
        default: "dev"
      location:
        type: string
        description: "Azure region"
        default: "swedencentral"
      publicAccess:
        type: boolean
        description: "Whether to allow public blob access"
        default: false
      redundancy:
        type: string
        description: "Storage redundancy level"
        default: "LRS"
        enum:
        - LRS   # Locally Redundant Storage
        - GRS   # Geo-Redundant Storage
        - ZRS   # Zone-Redundant Storage

  # Define what gets created
  resources:
  # 1. Resource Group for storage
  - id: storage-rg
    template:
      apiVersion: resources.azure.com/v1api20200601
      kind: ResourceGroup
      metadata:
        name: ${schema.spec.appName}-${schema.spec.environment}-storage-rg
        namespace: default
      spec:
        location: ${schema.spec.location}
        tags:
          app: ${schema.spec.appName}
          environment: ${schema.spec.environment}
          resource-type: storage
          managed-by: kro

  # 2. Storage Account
  - id: storage-account
    template:
      apiVersion: storage.azure.com/v1api20230101
      kind: StorageAccount
      metadata:
        # Storage account names must be globally unique, lowercase, no special chars
        # Using a hash or random suffix in production is recommended
        name: ${schema.spec.appName}${schema.spec.environment}stor
        namespace: default
      spec:
        location: ${schema.spec.location}
        kind: StorageV2
        sku:
          name: Standard_${schema.spec.redundancy}
        owner:
          name: ${resources.storage-rg.metadata.name}
        properties:
          accessTier: Hot
          allowBlobPublicAccess: ${schema.spec.publicAccess}
          minimumTlsVersion: TLS1_2
          supportsHttpsTrafficOnly: true
        tags:
          app: ${schema.spec.appName}
          environment: ${schema.spec.environment}
          managed-by: kro

  # 3. Blob Container for application data
  - id: blob-container
    template:
      apiVersion: storage.azure.com/v1api20230101
      kind: StorageAccountsBlobService
      metadata:
        name: ${schema.spec.appName}-${schema.spec.environment}-blob
        namespace: default
      spec:
        owner:
          name: ${resources.storage-account.metadata.name}
        properties:
          deleteRetentionPolicy:
            enabled: true
            days: 7

  # 4. Default container
  - id: default-container
    template:
      apiVersion: storage.azure.com/v1api20230101
      kind: StorageAccountsBlobServicesContainer
      metadata:
        name: ${schema.spec.appName}-data
        namespace: default
      spec:
        owner:
          name: ${resources.blob-container.metadata.name}
        properties:
          publicAccess: None
EOF

# Commit the ResourceGroup
git add kro-definitions/app-storage-rg.yaml
git commit -m "Add AppStorage abstraction for blob storage"
git push origin main
```

### Apply the AppStorage ResourceGroup

```bash
# Apply the AppStorage ResourceGroup
kubectl apply -f kro-definitions/app-storage-rg.yaml

# Verify it was created
kubectl get resourcegroup appstorage -n default

# Check that the AppStorage CRD was created
kubectl get crd | grep appstorage
```

### Use the AppStorage Abstraction

```bash
# Create storage for an application
cat << 'EOF' > developer-resources/myapp-storage.yaml
apiVersion: kro.run/v1alpha1
kind: AppStorage
metadata:
  name: myapp-storage
  namespace: default
spec:
  appName: myapp
  environment: dev
  location: swedencentral
  publicAccess: false
  redundancy: LRS
EOF

# Apply it
kubectl apply -f developer-resources/myapp-storage.yaml

# Watch the resources being created
kubectl get resourcegroup,storageaccount --watch

# Commit the developer resource
git add developer-resources/myapp-storage.yaml
git commit -m "Request blob storage using AppStorage abstraction"
git push origin main
```

### ✅ Verification Steps - Part 5

Verify the AppStorage abstraction works:

```bash
# Verify the AppStorage ResourceGroup definition
kubectl get resourcegroup appstorage -n default

# Check the developer's AppStorage instance
kubectl get appstorage myapp-storage -n default
kubectl describe appstorage myapp-storage

# Verify all generated resources
kubectl get resourcegroup | grep storage-rg
kubectl get storageaccount | grep stor

# Verify in Azure
az group show --name myapp-dev-storage-rg --output table
az storage account show --name myappdevstor --resource-group myapp-dev-storage-rg --output table
az storage account list --resource-group myapp-dev-storage-rg --output table

# Check blob containers
az storage container list --account-name myappdevstor --output table
```

**Expected Output:**
- AppStorage ResourceGroup `appstorage` exists
- Developer's `myapp-storage` AppStorage instance exists
- Azure Resource Group for storage created
- Storage Account with globally unique name created
- Blob service and container configured
- Resources visible in both Kubernetes and Azure

### 🤔 Reflection Questions - Part 5

Think about the AppStorage abstraction:

1. **Naming Challenge**: Storage account names must be globally unique across all of Azure. How did we handle this? Is the current approach production-ready?

2. **Redundancy Options**: We exposed `redundancy` as a choice (LRS, GRS, ZRS). Why give developers this option instead of choosing for them?

3. **Public Access**: The `publicAccess` field defaults to false. Why is this a secure default? When might developers need public access?

4. **Resource Hierarchy**: We created StorageAccount → BlobService → Container. Why this hierarchy? What does each level provide?

5. **Cost Implications**: Different redundancy levels have different costs. How could you add cost guardrails to this abstraction?

6. **Multi-Container Support**: Currently we create one default container. How would you extend this to allow developers to specify multiple containers?

## Part 6: Integrating KRO Abstractions with ArgoCD

Now let's connect our KRO abstractions to ArgoCD for full GitOps workflow.

### Create ArgoCD Project for KRO Resources

```bash
# Create an ArgoCD project for platform abstractions
cat << 'EOF' > /tmp/platform-abstractions-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: platform-abstractions
  namespace: argocd
spec:
  description: "Project for KRO abstractions and developer resources"

  sourceRepos:
  - 'https://github.com/*/platform-self-service.git'

  destinations:
  - namespace: default
    server: https://kubernetes.default.svc
  - namespace: 'kro'
    server: https://kubernetes.default.svc

  # Allow KRO ResourceGroups and generated resources
  clusterResourceWhitelist:
  - group: 'kro.run'
    kind: '*'
  - group: 'apiextensions.k8s.io'
    kind: 'CustomResourceDefinition'

  namespaceResourceWhitelist:
  - group: 'kro.run'
    kind: '*'
  - group: 'resources.azure.com'
    kind: '*'
  - group: 'storage.azure.com'
    kind: '*'
  - group: 'dbforpostgresql.azure.com'
    kind: '*'
  - group: ''
    kind: 'Secret'
EOF

# Apply the project
kubectl apply -f /tmp/platform-abstractions-project.yaml

# Verify project was created
argocd proj get platform-abstractions
```

### Create ArgoCD ApplicationSet

Now create an ArgoCD ApplicationSet that monitors your GitHub repository and automatically deploys KRO abstractions and developer resources. This follows the same pattern as LAB03's Azure resources management.

```bash
# Create the platform abstractions ApplicationSet
# Replace $GITHUB_USERNAME with your GitHub username
cat << EOF > /tmp/platform-abstractions-applicationset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: platform-abstractions
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/$GITHUB_USERNAME/platform-self-service.git
        revision: HEAD
        directories:
          - path: kro-definitions
          - path: developer-resources
  template:
    metadata:
      name: 'kro-{{path.basename}}'
    spec:
      project: platform-abstractions
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
kubectl apply -f /tmp/platform-abstractions-applicationset.yaml

# Check the ApplicationSet was created
kubectl get applicationset -n argocd | grep platform-abstractions

# The ApplicationSet will automatically generate Applications for kro-definitions and developer-resources
# Check which applications were generated
argocd app list | grep kro

# Watch the generated applications sync
# You'll see applications like: kro-kro-definitions, kro-developer-resources
argocd app get kro-kro-definitions
argocd app get kro-developer-resources
```

**Why use an ApplicationSet instead of individual Applications?**

The ApplicationSet approach provides several benefits:
1. **Automatic Discovery**: When you add new directories (e.g., `kro-advanced/`), ArgoCD automatically generates applications for them
2. **Better Organization**: Each directory is managed as a separate application, making it easier to track sync status
3. **Scalability**: As your platform grows, you don't need to manually create new ArgoCD applications
4. **Consistency**: All generated applications follow the same pattern defined in the ApplicationSet template
5. **Similar to LAB03**: This follows the same pattern used for Azure resources in LAB03, providing a consistent experience

### Verify GitOps Workflow

```bash
# Check that ArgoCD is managing the resources
argocd app list | grep kro

# View sync status of generated applications
argocd app get kro-kro-definitions
argocd app get kro-developer-resources

# Check in ArgoCD UI
# Navigate to http://argocd.YOUR_IP.nip.io
# You should see both applications with their resources
```

### ✅ Verification Steps - Part 6

Verify the complete GitOps integration:

```bash
# Verify ArgoCD project
argocd proj get platform-abstractions

# Verify the ApplicationSet exists
kubectl get applicationset platform-abstractions -n argocd

# Verify generated applications exist and are healthy
argocd app list | grep kro
argocd app get kro-kro-definitions
argocd app get kro-developer-resources

# Check that resources are synced
kubectl get resourcegroup -n default
kubectl get appdatabase,appstorage,appnamespace -n default

# Verify in ArgoCD UI (if accessible)
# http://argocd.YOUR_IP.nip.io
# Check both applications show green/healthy status
```

**Expected Output:**
- ArgoCD project `platform-abstractions` exists
- ApplicationSet `platform-abstractions` exists
- Two generated applications: `kro-kro-definitions` and `kro-developer-resources`
- Both applications show "Healthy" and "Synced" status
- All KRO ResourceGroups and developer resources visible in ArgoCD

### 🤔 Reflection Questions - Part 6

Consider the complete platform:

1. **Separation of Concerns**: The ApplicationSet generates separate applications for `kro-definitions` (platform) and `developer-resources` (developers). Why separate these?

2. **Self-Service Workflow**: How would a developer request a new database now? Walk through the complete workflow from request to provisioned resource.

3. **Change Management**: What happens if the platform team updates an abstraction (e.g., changes default PostgreSQL version)? How are existing resources affected?

4. **GitOps Benefits**: Now that everything is in Git and managed by ArgoCD, what capabilities do you have that weren't possible with manual resource creation?

5. **RBAC Integration**: How could you integrate ArgoCD RBAC so developers can request resources but not modify the abstractions themselves?

6. **Multi-Environment**: How would you extend this setup to support dev, staging, and prod environments with different configurations?

7. **ApplicationSet Pattern**: How does using ApplicationSet (like in LAB03) make the platform more maintainable compared to individual Applications?

## Part 7: Testing the Complete Platform

Let's test the complete self-service workflow.

### Simulate a Developer Request

Imagine a new team wants to deploy an application that needs both a database and storage:

```bash
# Navigate to your repository
cd ~/platform-self-service

# Create a new application request
cat << 'EOF' > developer-resources/newteam-app.yaml
# New team requests infrastructure for their app
---
apiVersion: kro.run/v1alpha1
kind: AppDatabase
metadata:
  name: newteam-database
  namespace: default
spec:
  appName: newteam
  environment: dev
  databaseType: postgresql
  location: swedencentral
---
apiVersion: kro.run/v1alpha1
kind: AppStorage
metadata:
  name: newteam-storage
  namespace: default
spec:
  appName: newteam
  environment: dev
  location: swedencentral
  publicAccess: false
  redundancy: LRS
EOF

# Create the database password secret
kubectl create secret generic newteam-db-password \
  --from-literal=password='NewTeamSecureP@ss!' \
  -n default

# Commit and push
git add developer-resources/newteam-app.yaml
git commit -m "Infrastructure request for newteam application

Requested by: newteam@company.com
Resources:
- PostgreSQL database
- Blob storage (LRS, private)

Environment: dev
Region: swedencentral"
git push origin main
```

### Watch ArgoCD Sync the Resources

```bash
# ArgoCD will detect the change and sync automatically
# Watch the sync happen (using the generated application name)
argocd app get kro-developer-resources --watch

# Check resources being created
kubectl get appdatabase,appstorage --watch

# This will take several minutes for the database
# Check generated Azure resources
kubectl get resourcegroup | grep newteam
kubectl get flexibleserver | grep newteam
kubectl get storageaccount | grep newteam
```

### Verify Complete Deployment

```bash
# Check all resources for newteam
kubectl get appdatabase newteam-database -n default
kubectl get appstorage newteam-storage -n default

# Verify in Azure
az group list --output table | grep newteam
az postgres flexible-server list --output table | grep newteam
az storage account list --output table | grep newteam

# Check ArgoCD application status
argocd app get kro-developer-resources
```

### ✅ Verification Steps - Part 7

Verify the complete self-service workflow:

```bash
# Verify the developer request was committed
cd ~/platform-self-service
git log --oneline -5

# Check ArgoCD synced the changes (using generated application name)
argocd app get kro-developer-resources | grep -A 5 "Sync Status"

# Verify both AppDatabase and AppStorage were created
kubectl get appdatabase newteam-database -o yaml
kubectl get appstorage newteam-storage -o yaml

# Check all generated Azure resources
kubectl get resourcegroup | grep newteam
kubectl get flexibleserver | grep newteam  
kubectl get storageaccount | grep newteam

# Verify in Azure (database may take 5-10 minutes)
az group list --output table | grep newteam
az postgres flexible-server list --output table | grep newteam
az storage account list --output table | grep newteam
```

**Expected Output:**
- Git commit visible in repository history
- ArgoCD application `kro-developer-resources` synced successfully
- Two resources: newteam-database and newteam-storage
- Multiple Azure resources created for each abstraction
- Resources visible in both Kubernetes and Azure Portal

### 🤔 Reflection Questions - Part 7

Reflect on the complete platform:

1. **Time to Provision**: How long did it take from Git commit to Azure resources being available? What steps were involved?

2. **Developer Experience**: Compare this workflow to traditional approaches (Azure Portal, ARM templates, Terraform). What improved? What trade-offs exist?

3. **Error Handling**: What happens if the storage account name conflicts with an existing one? How would the developer know? How could you improve error visibility?

4. **Resource Discovery**: How does the developer find out the connection details for the database or storage account? Where are credentials stored?

5. **Cost Visibility**: Multiple Azure resources were created. How would you show cost estimates to developers before they request resources?

6. **Approval Workflow**: In production, you might want approval before provisioning expensive resources. How could you add an approval gate to this GitOps workflow?

## Part 8: Advanced Patterns and Best Practices

### Adding Validation to Abstractions

You can add validation to ensure developers provide valid inputs:

```yaml
# Example: Add validation to AppDatabase
schema:
  apiVersion: v1alpha1
  kind: AppDatabase
  spec:
    appName:
      type: string
      description: "Application name (lowercase, alphanumeric, max 15 chars)"
      pattern: "^[a-z0-9]{1,15}$"
      minLength: 3
      maxLength: 15
    environment:
      type: string
      enum:
      - dev
      - staging
      - prod
```

### Creating Composite Abstractions

You can create higher-level abstractions that combine multiple abstractions:

```bash
# Example concept: FullStack app that includes database, storage, and namespace
cat << 'EOF' > kro-definitions/full-stack-app-rg.yaml
apiVersion: kro.run/v1alpha1
kind: ResourceGroup
metadata:
  name: fullstackapp
  namespace: default
spec:
  schema:
    apiVersion: v1alpha1
    kind: FullStackApp
    spec:
      appName:
        type: string
      environment:
        type: string
        default: "dev"
      location:
        type: string
        default: "swedencentral"

  resources:
  # 1. Create an AppNamespace
  - id: app-namespace
    template:
      apiVersion: kro.run/v1alpha1
      kind: AppNamespace
      metadata:
        name: ${schema.spec.appName}-namespace
        namespace: default
      spec:
        appName: ${schema.spec.appName}
        environment: ${schema.spec.environment}
        location: ${schema.spec.location}

  # 2. Create an AppDatabase
  - id: app-database
    template:
      apiVersion: kro.run/v1alpha1
      kind: AppDatabase
      metadata:
        name: ${schema.spec.appName}-db
        namespace: default
      spec:
        appName: ${schema.spec.appName}
        environment: ${schema.spec.environment}
        location: ${schema.spec.location}

  # 3. Create AppStorage
  - id: app-storage
    template:
      apiVersion: kro.run/v1alpha1
      kind: AppStorage
      metadata:
        name: ${schema.spec.appName}-storage
        namespace: default
      spec:
        appName: ${schema.spec.appName}
        environment: ${schema.spec.environment}
        location: ${schema.spec.location}
EOF

# This is just an example - don't apply it unless you want to test it
```

### Resource Output and Status

KRO can expose outputs from generated resources back to the parent resource:

```yaml
# Example: Expose database connection details
resources:
- id: postgresql-server
  template:
    # ... server definition ...
  # Expose these fields to status
  statusExport:
  - key: fullyQualifiedDomainName
    path: status.fullyQualifiedDomainName
```

### ✅ Best Practices Checklist

When creating KRO abstractions, follow these practices:

- [ ] **Clear Naming**: Use descriptive names for abstractions (AppDatabase, not DB)
- [ ] **Sensible Defaults**: Provide defaults for optional fields to simplify common cases
- [ ] **Validation**: Add schema validation to catch errors early
- [ ] **Documentation**: Document each field with description
- [ ] **Environment Awareness**: Support dev/staging/prod with appropriate configurations
- [ ] **Security First**: Default to secure settings (TLS, private access, etc.)
- [ ] **Cost Conscious**: Use cost-effective defaults (e.g., Burstable tier for dev)
- [ ] **Consistent Naming**: Follow naming conventions across all abstractions
- [ ] **Resource Dependencies**: Use `owner` references for proper dependency management
- [ ] **Idempotency**: Ensure resources can be safely reapplied
- [ ] **Status Reporting**: Export important information to status for visibility

## Troubleshooting

### Common Issues and Solutions

#### Issue: KRO ResourceGroup Not Creating CRD

```bash
# Check KRO controller logs
kubectl logs -n kro deployment/kro --tail=100

# Verify the ResourceGroup definition is valid
kubectl describe resourcegroup <name> -n default

# Check for syntax errors in your YAML
kubectl apply -f kro-definitions/<file>.yaml --dry-run=server

# Verify the CRD was created
kubectl get crd | grep <abstraction-name>
```

#### Issue: Resources Not Being Created

```bash
# Check the status of your custom resource
kubectl describe appdatabase <name>
kubectl describe appstorage <name>

# Look for error messages in the status
kubectl get appdatabase <name> -o yaml | grep -A 10 "status:"

# Check KRO controller logs for reconciliation errors
kubectl logs -n kro deployment/kro | grep -i error

# Verify template variable syntax
# Variables should be: ${schema.spec.fieldName}
# Resource references: ${resources.id.metadata.name}
```

#### Issue: Azure Resource Creation Fails

```bash
# Check ASO operator logs
kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager --tail=100

# Check the generated ASO resource status
kubectl describe resourcegroup <azure-rg-name>
kubectl describe storageaccount <storage-name>
kubectl describe flexibleserver <db-name>

# Common causes:
# - Storage account name not globally unique
# - Service Principal permissions insufficient
# - Azure region doesn't support the service
# - Resource quota limits in Azure subscription
```

#### Issue: ArgoCD Not Syncing

```bash
# Refresh the application (use generated application name)
argocd app get kro-developer-resources --refresh

# Check sync status and errors
argocd app get kro-developer-resources

# Force a sync
argocd app sync kro-developer-resources --prune

# Check if repository is accessible
argocd repo list
argocd repo get https://github.com/$GITHUB_USERNAME/platform-self-service.git
```

#### Issue: Variable Substitution Not Working

```bash
# Verify your variable syntax
# Correct: ${schema.spec.appName}
# Wrong: $schema.spec.appName or {schema.spec.appName}

# Check that field names match exactly (case-sensitive)
# Schema defines: appName
# Template uses: ${schema.spec.appName}  ✓
# Template uses: ${schema.spec.AppName}  ✗

# Verify the ResourceGroup has proper structure
kubectl get resourcegroup <name> -o yaml
```

### Cleanup (Optional)

If you need to clean up resources:

```bash
# Delete developer resources (this will delete Azure resources too)
kubectl delete appdatabase newteam-database
kubectl delete appstorage newteam-storage
kubectl delete appdatabase myapp-database
kubectl delete appstorage myapp-storage
kubectl delete appnamespace my-first-app

# Wait for Azure resources to be cleaned up
kubectl get resourcegroup --watch

# Delete KRO ResourceGroups
kubectl delete resourcegroup appnamespace appdatabase appstorage -n default

# Delete ArgoCD ApplicationSet (this will remove all generated applications)
kubectl delete applicationset platform-abstractions -n argocd

# Alternatively, delete individual generated applications
# argocd app delete kro-kro-definitions --cascade
# argocd app delete kro-developer-resources --cascade

# Delete ArgoCD project
kubectl delete appproject platform-abstractions -n argocd

# Optionally uninstall KRO
helm uninstall kro -n kro
kubectl delete namespace kro
```

## Final Verification - Complete Lab Check

Before finishing, verify your complete platform:

```bash
# Check KRO is running
kubectl get pods -n kro

# Verify all ResourceGroups
kubectl get resourcegroup -n default

# Check custom CRDs created by KRO
kubectl get crd | grep -E "(appnamespace|appdatabase|appstorage)"

# Verify developer resources
kubectl get appnamespace,appdatabase,appstorage -n default

# Check generated Azure resources
kubectl get resourcegroup,flexibleserver,storageaccount | grep -E "(myapp|newteam)"

# Verify in Azure
az group list --output table | grep -E "(myapp|newteam)"

# Check ArgoCD ApplicationSet and generated applications
kubectl get applicationset platform-abstractions -n argocd
argocd app list | grep kro

# Verify GitOps is working
cd ~/platform-self-service
git log --oneline --graph
```

### ✅ Final Checklist

Ensure you can answer "yes" to all of these:

- [ ] I understand what KRO is and how it differs from ASO
- [ ] I can create a KRO ResourceGroup with schema and resources
- [ ] I understand how variable substitution works in KRO templates
- [ ] I can create abstractions that hide Azure-specific complexity
- [ ] I understand resource dependencies and the `owner` field
- [ ] I can integrate KRO abstractions with ArgoCD for GitOps
- [ ] I know how to debug when KRO resources don't create properly
- [ ] I understand the developer self-service workflow end-to-end
- [ ] I can verify resources in both Kubernetes and Azure
- [ ] I understand the benefits and trade-offs of abstraction layers

### 🎯 Challenge Exercises (Optional)

If you have time, try these challenges:

1. **Custom Validation**: Add validation rules to prevent invalid app names or configurations
2. **Multi-Region**: Create an abstraction that deploys resources to multiple Azure regions
3. **Cost Tagging**: Add cost center and project tags to all generated resources
4. **Connection Secrets**: Create a Kubernetes secret with database connection details from the generated server
5. **Monitoring Integration**: Add Azure Monitor resources to your abstractions
6. **Composite App**: Create the FullStackApp abstraction that combines namespace, database, and storage
7. **Production Hardening**: Create separate abstractions for dev, staging, and prod with appropriate defaults
8. **Documentation**: Add a README to your repository explaining how developers use the abstractions

## Next Steps

Congratulations! You now have:
- ✅ KRO installed and configured in your cluster
- ✅ Multiple app-level abstractions (AppNamespace, AppDatabase, AppStorage)
- ✅ Complete GitOps workflow with ArgoCD
- ✅ Self-service platform where developers request infrastructure via Git
- ✅ Understanding of how to hide cloud complexity behind simple APIs

### Real-World Implementation

To implement this in a real environment, you would:

1. **Expand Abstractions**: Create abstractions for all common infrastructure patterns
2. **Add Environments**: Create environment-specific configurations and policies
3. **Implement RBAC**: Set up proper access controls for who can request what
4. **Add Validation**: Implement admission controllers to validate requests
5. **Cost Management**: Add cost estimation and tracking for resources
6. **Documentation**: Create comprehensive guides for developers
7. **Observability**: Add monitoring and alerting for platform health
8. **Support Process**: Define how developers get help and report issues

### Platform Maturity Model

Consider where your platform is on the maturity ladder:

1. **Level 1 - Manual**: Resources created manually through Portal/CLI
2. **Level 2 - Infrastructure as Code**: Resources defined in IaC templates
3. **Level 3 - Kubernetes-Native**: Resources managed through Kubernetes operators (ASO)
4. **Level 4 - Abstracted**: Application-level concepts hide infrastructure details (KRO) ← You are here!
5. **Level 5 - Automated**: AI/ML assists in resource provisioning and optimization

### Comparison with Other Tools

How does KRO + ASO compare to alternatives?

| Approach | Pros | Cons |
|----------|------|------|
| **Azure Portal** | Easy to start, visual | Manual, no history, not reproducible |
| **ARM Templates** | Azure-native, complete | Complex, not K8s-native, hard to test |
| **Terraform** | Multi-cloud, mature | Separate workflow, state management |
| **Crossplane** | Multi-cloud, mature | Complex setup, larger community |
| **ASO Directly** | K8s-native, GitOps | Developers need Azure knowledge |
| **KRO + ASO** | Simple for devs, flexible, GitOps | Requires maintenance, learning curve |

## Key Takeaways

From this lab, you should understand:

1. **Abstraction is Key**: Platform engineering is about creating the right abstractions for your organization
2. **KRO Extends Kubernetes**: KRO lets you create custom resource types without writing code
3. **Composition Pattern**: Complex infrastructure can be composed from simple abstractions
4. **GitOps Everything**: Infrastructure, abstractions, and requests all flow through Git
5. **Developer Experience**: Good abstractions make developers productive and safe
6. **Platform Evolution**: Platforms should evolve based on developer feedback and usage patterns

## Resources and Further Learning

- [Kubernetes Resource Orchestrator (KRO) Documentation](https://github.com/Azure/kro)
- [Azure Service Operator Documentation](https://azure.github.io/azure-service-operator/)
- [Platform Engineering Principles](https://platformengineering.org/)
- [Internal Developer Platforms](https://internaldeveloperplatform.org/)
- [Team Topologies](https://teamtopologies.com/) - Understanding platform teams
- [The Platform Engineering Guide](https://www.cncf.io/blog/2023/02/21/platform-engineering/)

### Useful Commands Reference

```bash
# KRO Management
kubectl get resourcegroup -n default
kubectl describe resourcegroup <name>
kubectl get crd | grep kro
kubectl logs -n kro deployment/kro

# Custom Resources
kubectl get appdatabase,appstorage,appnamespace
kubectl describe appdatabase <name>
kubectl get appdatabase <name> -o yaml

# Generated Azure Resources
kubectl get resourcegroup,flexibleserver,storageaccount
kubectl describe flexibleserver <name>
kubectl describe storageaccount <name>

# ArgoCD Management
argocd app list
argocd app get <app-name>
argocd app sync <app-name>
argocd proj list

# Azure Verification
az group list --output table
az postgres flexible-server list --output table
az storage account list --output table
```

## Congratulations!

You've completed LAB04B! You now understand how to create powerful abstractions that make your platform easy to use while hiding infrastructure complexity. This is the essence of platform engineering - building tools that make developers productive while maintaining control and consistency.

In a production environment, you would continue to evolve these abstractions based on developer feedback, adding new resource types, improving validation, and optimizing for your specific organizational needs.

The skills you've learned here - combining operators like ASO and KRO with GitOps tools like ArgoCD - form the foundation of modern platform engineering practices.
