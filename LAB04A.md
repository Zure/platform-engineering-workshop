# LAB04A: Self-Service Platform UI with Backstage

Welcome to LAB04A! In this lab, you'll add a developer portal using Backstage to provide a user-friendly interface for your platform. By the end of this lab, you'll have:

- Backstage deployed on your Kind cluster
- Software templates for requesting namespaces and Azure resources
- Integration with your platform-self-service repository from LAB02
- A complete self-service workflow where ArgoCD syncs requested resources

## Prerequisites

Before starting, ensure you have completed:
- ✅ **LAB01**: Kind cluster with NGINX ingress and ArgoCD installed
- ✅ **LAB02**: Platform-self-service repository and ArgoCD ApplicationSets
- ✅ **LAB03**: Azure Service Operator installed (for Azure resource templates)

**Additional Requirements:**
- ✅ **Helm 3**: For deploying Backstage
- ✅ **GitHub Account**: Your platform-self-service repository from LAB02
- ✅ **Node.js 18+** (optional): For local Backstage development

## Overview

In previous labs, you created a GitOps-based self-service platform where teams request resources through Git Pull Requests. While powerful, this approach requires developers to:
- Understand Git workflows
- Write YAML manifests correctly
- Wait for PR reviews and merges

In this lab, we'll add **Backstage** as a user-friendly interface that:
- Provides forms instead of YAML editing
- Automatically creates Pull Requests in your platform-self-service repo
- Shows the status of requested resources
- Makes self-service accessible to all developers

### What is Backstage?

Backstage is an open-source developer portal created by Spotify. For our platform, it provides:
- **Software Templates**: Forms that generate resource requests (namespaces, Azure resources)
- **Service Catalog**: View all registered services and resources
- **Kubernetes Plugin**: See cluster resources and their status
- **GitHub Integration**: Create PRs automatically from templates

### Lab Architecture

```
Developer → Backstage UI → GitHub PR → ArgoCD → Kubernetes/Azure
             (Forms)      (platform-self-service repo)  (Sync)
```

### Lab Flow

1. Deploy Backstage on Kind with minimal configuration
2. Configure GitHub integration for your platform-self-service repo
3. Create a software template for namespace requests
4. Create a software template for Azure resource requests
5. Test the complete workflow: Request → PR → Sync → Deployed

## Part 1: Preparing GitHub Integration

Backstage's power comes from integrating with your Git repository to automate resource creation. Let's set up GitHub integration first.

### Create a GitHub Personal Access Token

Backstage needs a GitHub token to create Pull Requests in your platform-self-service repository:

1. Go to GitHub: https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Token settings:
   - **Note**: `Backstage Platform Workshop`
   - **Expiration**: 7 days (or as needed for workshop)
   - **Scopes**: Select these permissions:
     - `repo` (all sub-scopes) - for creating PRs and accessing repositories
     - `workflow` - for GitHub Actions
     - `user:email` - for user information
4. Click "Generate token"
5. **Copy the token immediately** - you won't see it again!

```bash
# Save your token as an environment variable (replace with your actual token)
export GITHUB_TOKEN="ghp_your_token_here"
export GITHUB_USERNAME="your-github-username"

# Verify the token works
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user | jq '.login'
# Should output your GitHub username
```

### Verify Your Platform-Self-Service Repository

From LAB02, you should have a `platform-self-service` repository. Let's verify it exists and has the correct structure:

```bash
# Check if you can access your repository
curl -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$GITHUB_USERNAME/platform-self-service" | jq '.name'

# Expected output: "platform-self-service"
```

If you don't have this repository, revisit LAB02 to create it first.

### ✅ Verification Steps - Part 1

```bash
# Verify prerequisites
helm version  # Should show v3.x
kubectl cluster-info  # Should show cluster is running
kubectl get pods -n argocd  # Should show ArgoCD pods running

# Verify GitHub token
echo $GITHUB_TOKEN | head -c 10  # Should show ghp_xxxxx
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user | jq '.login'

# Verify platform-self-service repo exists
curl -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$GITHUB_USERNAME/platform-self-service" | jq '.name'
```

**Expected Output:**
- Helm 3.x installed
- Kind cluster running
- ArgoCD operational
- GitHub token valid and working
- platform-self-service repository accessible

## Part 2: Installing Backstage

We'll deploy Backstage using a simplified approach suitable for the workshop environment.

### Create Namespace

```bash
# Create dedicated namespace for Backstage
kubectl create namespace backstage

# Verify namespace
kubectl get namespace backstage
```

### Get Your IP Address for Ingress

Backstage needs to be accessible via ingress. First, determine your IP address:

```bash
# On Linux/macOS
export YOUR_IP=$(hostname -I | awk '{print $1}')

# On macOS (alternative)
export YOUR_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)

# Verify
echo "Your IP: $YOUR_IP"
echo "Backstage will be available at: http://backstage.$YOUR_IP.nip.io"
```

### Create Backstage Configuration

Create a minimal Backstage configuration focused on our workshop needs:

```bash
# Create Backstage app-config (replace variables with your values)
cat << EOF > /tmp/backstage-app-config.yaml
app:
  title: Platform Engineering Workshop
  baseUrl: http://backstage.${YOUR_IP}.nip.io

organization:
  name: Workshop

backend:
  baseUrl: http://backstage.${YOUR_IP}.nip.io
  listen:
    port: 7007
  csp:
      connect-src: ["'self'", "http:", "https:"]
  cors:
    origin: http://backstage.${YOUR_IP}.nip.io
    methods: [GET, HEAD, PATCH, POST, PUT, DELETE]
    credentials: true
  database:
    client: better-sqlite3
    connection: ':memory:'

integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}

catalog:
  import:
    entityFilename: catalog-info.yaml
    pullRequestBranchName: backstage-integration
  rules:
    - allow: [Component, System, API, Resource, Location, Template]
  locations:
    - type: file
      target: /app/examples/entities.yaml

scaffolder:
  defaultAuthor:
    name: Platform Team
    email: platform@workshop.local
  defaultCommitMessage: 'Requested via Backstage'

auth:
  providers:
    guest: {}

EOF

# Create a Kubernetes Secret with this configuration
kubectl create secret generic backstage-secrets \
  --from-literal=GITHUB_TOKEN="$GITHUB_TOKEN" \
  -n backstage

# Create ConfigMap for app-config
kubectl create configmap backstage-app-config \
  --from-file=app-config.yaml=/tmp/backstage-app-config.yaml \
  -n backstage
```

### Deploy Backstage

We'll deploy Backstage using a direct Kubernetes deployment for better control:

```bash
# Create Backstage deployment
cat << EOF > /tmp/backstage-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backstage
  namespace: backstage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backstage
  template:
    metadata:
      labels:
        app: backstage
    spec:
      serviceAccountName: backstage
      containers:
      - name: backstage
        image: ghcr.io/backstage/backstage:latest
        imagePullPolicy: Always
        ports:
        - name: http
          containerPort: 7007
        envFrom:
        - secretRef:
            name: backstage-secrets
        volumeMounts:
        - name: app-config
          mountPath: /app/app-config.yaml
          subPath: app-config.yaml
          readOnly: true
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /healthcheck
            port: 7007
          initialDelaySeconds: 60
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /healthcheck
            port: 7007
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: app-config
        configMap:
          name: backstage-app-config
---
apiVersion: v1
kind: Service
metadata:
  name: backstage
  namespace: backstage
spec:
  selector:
    app: backstage
  ports:
  - name: http
    port: 7007
    targetPort: 7007
  type: ClusterIP
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backstage
  namespace: backstage
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backstage
  namespace: backstage
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
  - host: backstage.${YOUR_IP}.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: backstage
            port:
              number: 7007
EOF

# Apply the deployment
kubectl apply -f /tmp/backstage-deployment.yaml

# Wait for Backstage to be ready (this may take 3-5 minutes)
echo "Waiting for Backstage to be ready..."
kubectl wait --for=condition=ready pod -l app=backstage -n backstage --timeout=600s
```

### ✅ Verification Steps - Part 2

```bash
# Check Backstage pod is running
kubectl get pods -n backstage
kubectl logs -n backstage -l app=backstage --tail=50

# Verify service and ingress
kubectl get svc -n backstage
kubectl get ingress -n backstage

# Test Backstage is responding
curl -I http://backstage.${YOUR_IP}.nip.io/healthcheck

# Open Backstage in browser
echo "Open Backstage at: http://backstage.${YOUR_IP}.nip.io"
```

**Expected Output:**
- Backstage pod showing 1/1 READY
- Ingress configured with your IP address
- Healthcheck returns 200 OK
- Backstage UI loads in browser

## Part 3: Creating Software Templates for Self-Service

Now we'll create software templates that generate Pull Requests in your platform-self-service repository. These templates will allow developers to request namespaces and Azure resources through a simple form.

### Create Initial Catalog with Examples

First, let's create a basic catalog file with example entities:

```bash
# Create example entities file that Backstage will load
cat << 'EOF' > /tmp/entities.yaml
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: workshop-platform
  description: Platform Engineering Workshop Infrastructure
spec:
  owner: platform-team
---
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: platform-team
  description: Platform Engineering Team
spec:
  type: team
  children: []
EOF

# Create ConfigMap with entities
kubectl create configmap backstage-examples \
  --from-file=entities.yaml=/tmp/entities.yaml \
  -n backstage

# Update deployment to mount this ConfigMap
kubectl set volume deployment/backstage \
  -n backstage \
  --add \
  --name=examples \
  --type=configmap \
  --configmap-name=backstage-examples \
  --mount-path=/app/examples
```

### Create Namespace Request Template

For this workshop, we'll create a simplified template that shows developers what YAML would be created. In a production setup, you would add the GitHub integration to create PRs automatically.

```bash
# Create a simplified namespace request template
cat << 'EOF' > /tmp/namespace-template.yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: namespace-request
  title: Request Kubernetes Namespace
  description: Request a new Kubernetes namespace with resource quotas
  tags:
    - kubernetes
    - namespace
    - self-service
spec:
  owner: platform-team
  type: resource
  
  parameters:
    - title: Namespace Details
      required:
        - teamName
        - environment
        - contactEmail
      properties:
        teamName:
          title: Team Name
          type: string
          description: Your team name (lowercase, no spaces)
          pattern: '^[a-z0-9-]+$'
          ui:autofocus: true
          ui:help: 'Example: frontend, backend, data'
        
        environment:
          title: Environment
          type: string
          description: Environment for this namespace
          enum:
            - dev
            - staging
            - prod
          enumNames:
            - Development
            - Staging
            - Production
        
        contactEmail:
          title: Contact Email
          type: string
          format: email
          description: Team contact email
        
        purpose:
          title: Purpose
          type: string
          description: What will this namespace be used for?
          ui:widget: textarea
          ui:options:
            rows: 3
    
    - title: Resource Quotas
      properties:
        cpuRequest:
          title: CPU Cores
          type: string
          description: Number of CPU cores
          default: "2"
          enum: ["1", "2", "4", "8"]
        
        memoryRequest:
          title: Memory
          type: string
          description: Memory allocation
          default: "4Gi"
          enum: ["2Gi", "4Gi", "8Gi", "16Gi"]

  steps:
    - id: log
      name: Log Request
      action: debug:log
      input:
        message: |
          Namespace request created:
          Team: ${{ parameters.teamName }}
          Environment: ${{ parameters.environment }}
          Namespace: devops-${{ parameters.teamName }}-${{ parameters.environment }}
  
  output:
    text:
      - title: Namespace YAML Generated
        content: |
          ## Namespace Request for ${{ parameters.teamName }}
          
          ### Generated YAML
          
          Copy this YAML and create a PR in your platform-self-service repository:
          
          **File**: `namespaces/${{ parameters.environment }}/${{ parameters.teamName }}-namespace.yaml`
          
          ```yaml
          apiVersion: v1
          kind: Namespace
          metadata:
            name: devops-${{ parameters.teamName }}-${{ parameters.environment }}
            labels:
              team: ${{ parameters.teamName }}
              environment: ${{ parameters.environment }}
              managed-by: platform-team
              created-via: backstage
            annotations:
              team.contact: "${{ parameters.contactEmail }}"
              purpose: "${{ parameters.purpose }}"
          ---
          apiVersion: v1
          kind: ResourceQuota
          metadata:
            name: ${{ parameters.teamName }}-${{ parameters.environment }}-quota
            namespace: devops-${{ parameters.teamName }}-${{ parameters.environment }}
          spec:
            hard:
              requests.cpu: "${{ parameters.cpuRequest }}"
              requests.memory: ${{ parameters.memoryRequest }}
              limits.cpu: "${{ parameters.cpuRequest * 2 }}"
              limits.memory: "${{ parameters.memoryRequest | replace('Gi', '') | int * 2 }}Gi"
              persistentvolumeclaims: "5"
              services: "10"
          ---
          apiVersion: v1
          kind: LimitRange
          metadata:
            name: ${{ parameters.teamName }}-${{ parameters.environment }}-limits
            namespace: devops-${{ parameters.teamName }}-${{ parameters.environment }}
          spec:
            limits:
            - default:
                cpu: 500m
                memory: 512Mi
              defaultRequest:
                cpu: 100m
                memory: 128Mi
              type: Container
          ```
          
          ### Next Steps
          
          1. Copy the YAML above
          2. Create a new branch in your platform-self-service repo
          3. Add the file to `namespaces/${{ parameters.environment }}/`
          4. Create a Pull Request
          5. After merge, ArgoCD will automatically sync the namespace
          
          **Repository**: https://github.com/${{ secrets.GITHUB_USERNAME }}/platform-self-service
EOF

# Create ConfigMap for the template
kubectl create configmap namespace-template \
  --from-file=template.yaml=/tmp/namespace-template.yaml \
  -n backstage \
  --dry-run=client -o yaml | kubectl apply -f -
```


**Note**: This template uses `debug:log` action which is available in standard Backstage. For production, you would:
- Add the `@backstage/plugin-scaffolder-backend-module-github` plugin
- Configure GitHub integration with tokens
- Use `publish:github:pull-request` action to create PRs automatically

### Create Azure Storage Account Request Template

Similar to the namespace template, this shows the YAML that would be created:

```bash
# Create Azure storage request template
cat << 'EOF' > /tmp/storage-template.yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: azure-storage-request
  title: Request Azure Storage Account
  description: Request an Azure Storage Account for your team
  tags:
    - azure
    - storage
    - self-service
spec:
  owner: platform-team
  type: resource
  
  parameters:
    - title: Storage Account Details
      required:
        - teamName
        - environment
        - storageAccountName
      properties:
        teamName:
          title: Team Name
          type: string
          description: Your team name
          pattern: '^[a-z0-9-]+$'
          ui:autofocus: true
        
        environment:
          title: Environment
          type: string
          enum: [dev, staging, prod]
        
        storageAccountName:
          title: Storage Account Name
          type: string
          description: Globally unique name (3-24 chars, lowercase alphanumeric only)
          pattern: '^[a-z0-9]{3,24}$'
          ui:help: 'Example: myteamstorage001'
        
        purpose:
          title: Purpose
          type: string
          description: What will this storage be used for?
          ui:widget: textarea
    
    - title: Configuration
      properties:
        location:
          title: Azure Region
          type: string
          default: swedencentral
          enum: [swedencentral, westeurope, northeurope]
        
        sku:
          title: SKU/Performance Tier
          type: string
          default: Standard_LRS
          enum:
            - Standard_LRS
            - Standard_GRS
          enumNames:
            - 'Standard Locally Redundant'
            - 'Standard Geo-Redundant'

  steps:
    - id: log
      name: Log Request
      action: debug:log
      input:
        message: |
          Azure Storage request created:
          Team: ${{ parameters.teamName }}
          Storage Account: ${{ parameters.storageAccountName }}
          Region: ${{ parameters.location }}
  
  output:
    text:
      - title: Azure Storage YAML Generated
        content: |
          ## Azure Storage Request for ${{ parameters.teamName }}
          
          ### Generated YAML
          
          Copy this YAML and create a PR in your platform-self-service repository:
          
          **File**: `azure-resources/storage-accounts/${{ parameters.teamName }}-${{ parameters.storageAccountName }}.yaml`
          
          ```yaml
          # Resource Group
          apiVersion: resources.azure.com/v1api20200601
          kind: ResourceGroup
          metadata:
            name: ${{ parameters.teamName }}-${{ parameters.environment }}-rg
            namespace: default
          spec:
            location: ${{ parameters.location }}
            tags:
              team: ${{ parameters.teamName }}
              environment: ${{ parameters.environment }}
              managed-by: platform-team
              created-via: backstage
          ---
          # Storage Account
          apiVersion: storage.azure.com/v1api20230101
          kind: StorageAccount
          metadata:
            name: ${{ parameters.storageAccountName }}
            namespace: default
          spec:
            location: ${{ parameters.location }}
            kind: StorageV2
            sku:
              name: ${{ parameters.sku }}
            owner:
              name: ${{ parameters.teamName }}-${{ parameters.environment }}-rg
            accessTier: Hot
            tags:
              team: ${{ parameters.teamName }}
              environment: ${{ parameters.environment }}
              purpose: "${{ parameters.purpose }}"
              managed-by: platform-team
              created-via: backstage
          ```
          
          ### Next Steps
          
          1. Copy the YAML above
          2. Create a new branch in your platform-self-service repo
          3. Add the file to `azure-resources/storage-accounts/`
          4. Create a Pull Request
          5. After merge, ArgoCD will sync and ASO will create the Azure resources
          
          **Note**: Storage account names must be globally unique across Azure!
EOF

# Create ConfigMap for the storage template
kubectl create configmap storage-template \
  --from-file=template.yaml=/tmp/storage-template.yaml \
  -n backstage \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Register Templates in Backstage

Update the Backstage app-config to load the templates:

```bash
# Create updated app-config with template locations
cat << EOF > /tmp/backstage-catalog.yaml
# Catalog with template locations
catalog:
  locations:
    - type: file
      target: /app/examples/entities.yaml
    - type: file
      target: /app/templates/namespace-template.yaml
    - type: file
      target: /app/templates/storage-template.yaml
EOF

# Update Backstage deployment to mount templates
# First, create a combined app-config

# Update ConfigMap
kubectl create configmap backstage-app-config \
  --from-file=app-config.yaml=/tmp/backstage-app-config.yaml \
  -n backstage \
  --dry-run=client -o yaml | kubectl apply -f -

# Mount templates in deployment
kubectl set volume deployment/backstage \
  -n backstage \
  --add \
  --name=namespace-template \
  --type=configmap \
  --configmap-name=namespace-template \
  --mount-path=/app/templates/namespace-template.yaml \
  --sub-path=template.yaml

kubectl set volume deployment/backstage \
  -n backstage \
  --add \
  --name=storage-template \
  --type=configmap \
  --configmap-name=storage-template \
  --mount-path=/app/templates/storage-template.yaml \
  --sub-path=template.yaml

# Restart Backstage to pick up changes
kubectl rollout restart deployment/backstage -n backstage

# Wait for restart
kubectl wait --for=condition=ready pod -l app=backstage -n backstage --timeout=300s
```

### ✅ Verification Steps - Part 3

```bash
# Check templates are loaded
kubectl get configmaps -n backstage

# Check Backstage logs for template registration
kubectl logs -n backstage -l app=backstage --tail=100 | grep -i template

# Access Backstage UI
echo "Open Backstage at: http://backstage.${YOUR_IP}.nip.io"
echo "Navigate to 'Create' to see your templates"
```

**Expected Output:**
- ConfigMaps created for templates
- Backstage logs show templates were loaded
- Templates visible in Backstage UI under "Create" page

## Part 4: Testing the Self-Service Workflow

Now let's test the complete workflow: Request resources via Backstage → PR created → ArgoCD syncs → Resources deployed.

### Test Namespace Request

1. **Open Backstage in your browser**:
   ```bash
   echo "Open: http://backstage.${YOUR_IP}.nip.io"
   ```

2. **Navigate to Create page**:
   - Click "Create" in the left sidebar
   - Find "Request Kubernetes Namespace" template
   - Click "Choose"

3. **Fill in the form**:
   - Team Name: `testteam`
   - Environment: `dev`
   - Contact Email: `testteam@workshop.local`
   - Purpose: `Testing Backstage self-service workflow`
   - CPU Cores: `2`
   - Memory: `4Gi`

4. **Review and Create**:
   - Click "Review"
   - Click "Create"
   - Backstage will create a Pull Request in your platform-self-service repository

5. **Check the Pull Request**:
   ```bash
   # View PRs in your repository
   curl -H "Authorization: token $GITHUB_TOKEN" \
     "https://api.github.com/repos/$GITHUB_USERNAME/platform-self-service/pulls" | \
     jq '.[] | {title, number, state}'
   ```

6. **Merge the Pull Request**:
   - Open the PR link in your browser
   - Review the changes (namespace YAML)
   - Click "Merge pull request"
   - Click "Confirm merge"

7. **Watch ArgoCD Sync**:
   ```bash
   # ArgoCD will detect the merge and sync automatically (within 3 minutes)
   # Or manually trigger sync:
   argocd app sync dev-namespaces

   # Wait for sync
   argocd app wait dev-namespaces --timeout 300

   # Verify namespace was created
   kubectl get namespace devops-testteam-dev
   kubectl describe namespace devops-testteam-dev
   kubectl get resourcequota -n devops-testteam-dev
   ```

### Test Azure Storage Request (if LAB03 completed)

1. **Navigate to Create page in Backstage**
2. **Find "Request Azure Storage Account" template**
3. **Fill in the form**:
   - Team Name: `testteam`
   - Environment: `dev`
   - Storage Account Name: `teststoragews001` (must be globally unique!)
   - Purpose: `Testing Azure resource provisioning`
   - Azure Region: `swedencentral`
   - SKU: `Standard_LRS`

4. **Create and merge the PR** (same process as namespace)

5. **Verify Azure resources**:
   ```bash
   # Watch ArgoCD sync
   argocd app sync azure-storage-accounts

   # Check storage account in Kubernetes
   kubectl get storageaccount -n default

   # Verify in Azure
   az storage account show --name teststoragews001 --resource-group testteam-dev-rg
   ```

### ✅ Verification Steps - Part 4

Complete workflow verification:

```bash
# Check namespace exists with correct labels
kubectl get namespace devops-testteam-dev -o yaml | grep -A 5 "labels:"

# Verify resource quota is applied
kubectl describe resourcequota -n devops-testteam-dev

# Check ArgoCD application status
argocd app get dev-namespaces | grep -E "(Health|Sync)"

# If Azure resources were created, check them too
kubectl get resourcegroup,storageaccount --all-namespaces | grep testteam

# View recent PRs in your repository
curl -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$GITHUB_USERNAME/platform-self-service/pulls?state=closed" | \
  jq '.[] | {title, merged_at}' | head -20
```

**Expected Results:**
- ✅ Backstage created PRs automatically
- ✅ PRs contain correct YAML manifests
- ✅ After merge, ArgoCD synced changes
- ✅ Resources created in cluster/Azure
- ✅ Complete GitOps audit trail in Git history


## Troubleshooting

### Common Issues

#### Backstage Pod Not Starting

```bash
# Check pod status
kubectl get pods -n backstage
kubectl describe pod -n backstage -l app=backstage

# Check logs
kubectl logs -n backstage -l app=backstage --tail=100

# Common issues:
# 1. Insufficient memory - increase resource limits
# 2. GitHub token invalid - recreate secret with valid token
# 3. ConfigMap mount issues - verify ConfigMaps exist
```

#### Templates Not Visible in UI

```bash
# Verify ConfigMaps exist
kubectl get configmaps -n backstage | grep template

# Check Backstage loaded them
kubectl logs -n backstage -l app=backstage | grep -i "template"

# Restart if needed
kubectl rollout restart deployment/backstage -n backstage
```

#### Pull Request Creation Fails

```bash
# Verify GitHub token has correct permissions
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/user/repos | jq '.[].full_name' | grep platform-self-service

# Check Backstage can reach GitHub
kubectl logs -n backstage -l app=backstage | grep -i "github"

# Verify repository name in template matches your repo
```

#### ArgoCD Not Syncing After PR Merge

```bash
# Check ArgoCD is polling correctly
argocd app get dev-namespaces

# Manually trigger sync
argocd app sync dev-namespaces

# Force refresh from Git
argocd app get dev-namespaces --refresh
```

## Benefits of This Approach

### What You've Built

You now have a complete self-service platform where:

1. **Developers use forms** instead of writing YAML
2. **Pull Requests are automatic** - no manual Git operations
3. **Platform team reviews** PRs before resources are created
4. **ArgoCD automatically syncs** approved changes
5. **Full audit trail** exists in Git history
6. **Resources are standardized** through templates

### Comparison: Before vs After Backstage

**Before (LAB02/LAB03)**:
- Developer learns Git workflow
- Developer writes YAML manually
- Developer creates branch, commits, pushes
- Developer creates Pull Request
- Platform team reviews and merges
- ArgoCD syncs changes

**After (LAB04A)**:
- Developer fills out a form
- Backstage generates correct YAML
- Backstage creates PR automatically
- Platform team reviews and merges
- ArgoCD syncs changes

**Key Improvement**: Less friction, fewer errors, faster onboarding!

### Production Considerations

To make this production-ready, you would:

1. **Authentication**: Replace guest auth with OAuth (GitHub, Azure AD, Okta)
2. **RBAC**: Control who can create which resources
3. **Approvals**: Add approval workflows in GitHub (branch protection, CODEOWNERS)
4. **Monitoring**: Add observability for Backstage, ArgoCD, and resource creation
5. **Cost Controls**: Add budget checks and quotas
6. **Disaster Recovery**: Back up Backstage catalog and configuration

## Cleanup (Optional)

To remove Backstage:

```bash
# Delete Backstage deployment
kubectl delete namespace backstage

# Remove test resources
kubectl delete namespace devops-testteam-dev

# Remove Azure test resources (if created)
az storage account delete --name teststoragews001 --resource-group testteam-dev-rg --yes
az group delete --name testteam-dev-rg --yes
```

## Next Steps

Congratulations! You've completed the Platform Engineering Workshop!

### What You've Learned

Across all labs, you've built a complete Internal Developer Platform with:

**LAB01**: 
- ✅ Local Kubernetes cluster (Kind)
- ✅ GitOps with ArgoCD

**LAB02**:
- ✅ Self-service via Git
- ✅ Multi-tenant namespaces with quotas
- ✅ ArgoCD ApplicationSets for automation

**LAB03**:
- ✅ Azure Service Operator for cloud resources
- ✅ Kubernetes as control plane for Azure
- ✅ GitOps for infrastructure

**LAB04A**:
- ✅ Developer portal (Backstage)
- ✅ Software templates for self-service
- ✅ Automated PR creation
- ✅ Complete developer experience

### Optional: LAB04B

If you have time, continue to **LAB04B: Advanced Platform Concepts - Abstractions** to learn about:
- Kubernetes Resource Model (KRO)
- Creating higher-level abstractions
- Hiding infrastructure complexity
- Building "App Concepts" that compose multiple resources

### Continue Learning

**Platform Engineering**:
- [Platform Engineering website](https://platformengineering.org/)
- [Internal Developer Platform](https://internaldeveloperplatform.org/)
- [Team Topologies book](https://teamtopologies.com/)

**Tools Deep Dive**:
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Backstage Documentation](https://backstage.io/docs/)
- [Azure Service Operator](https://azure.github.io/azure-service-operator/)
- [Crossplane](https://www.crossplane.io/) - Alternative to ASO

**CNCF Landscape**:
- [CNCF Cloud Native Interactive Landscape](https://landscape.cncf.io/)
- Explore tools for observability, security, networking, storage

## Summary

In this lab, you:

1. ✅ Deployed Backstage on Kind cluster
2. ✅ Integrated with GitHub for PR automation
3. ✅ Created software templates for namespaces
4. ✅ Created software templates for Azure resources
5. ✅ Tested complete self-service workflow
6. ✅ Experienced GitOps with user-friendly UI

### Key Takeaways

1. **Developer Experience Matters**: A good UI dramatically improves platform adoption
2. **Templates Enable Golden Paths**: Standardize best practices through forms
3. **GitOps Provides Safety**: All changes go through Git and PR reviews
4. **Automation Reduces Errors**: Generated YAML is more reliable than manual edits
5. **Platform as Product**: Treat your platform like a product developers want to use

## Resources

- [Backstage Software Templates Guide](https://backstage.io/docs/features/software-templates/)
- [GitHub Actions for Backstage](https://github.com/backstage/software-templates)
- [Backstage Community Plugins](https://github.com/backstage/community-plugins)
- [Platform Engineering Slack](https://platformengineering.org/slack-rd)

---

**Congratulations on completing LAB04A!** 

You've built a production-grade self-service platform with:
- Infrastructure as Code (GitOps)
- Self-service portals (Backstage)
- Automated workflows (ArgoCD)
- Cloud resource management (ASO)

This is the foundation of modern Platform Engineering! 🚀
