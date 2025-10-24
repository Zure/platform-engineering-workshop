# LAB02: Creating a Basic Self-Service Platform

Welcome to LAB02! In this lab, you'll create a basic self-service platform using ArgoCD projects and GitOps principles. By the end of this lab, you'll have:

- A separate GitHub repository for self-service requests
- Multiple ArgoCD projects for tenant isolation
- A GitOps workflow for creating Kubernetes namespaces
- Understanding of how teams can request resources through Git
- Experience with ArgoCD's multi-tenancy features

## Prerequisites

Before starting, ensure you have completed:
- ✅ **LAB01**: Your local environment should have:
  - Kind cluster running with NGINX ingress
  - ArgoCD installed and accessible
  - ArgoCD CLI configured and working
  - Basic understanding of ArgoCD applications
- ✅ **GitHub Account**: You'll need a GitHub account to create repositories
  - Sign up at [https://github.com](https://github.com) if you don't have one
  - Ensure you're logged in before starting the lab

## Overview

In this lab, we'll simulate a platform engineering scenario where development teams can request resources (like namespaces) through a self-service mechanism. We'll use:

- **ArgoCD Projects**: For tenant isolation and access control
- **GitOps**: Teams submit requests via Pull Requests
- **Namespace-as-Code**: Kubernetes namespaces defined in YAML
- **Automation**: ArgoCD automatically applies approved changes

## Part 1: Setting Up the Self-Service Repository

### Create a GitHub Repository

First, you'll create a GitHub repository that will serve as the source of truth for self-service requests. This repository will be monitored by ArgoCD, and any changes merged to it will automatically be applied to your cluster.

**Step 1: Create the repository on GitHub**

1. Navigate to [GitHub](https://github.com)
2. Click on the "+" icon in the top right corner
3. Select "New repository"
4. Repository settings:
   - **Repository name**: `platform-self-service`
   - **Description**: "Platform self-service resources for the workshop"
   - **Visibility**: Choose "Public" (easier for the workshop)
   - **Initialize**: ✅ Check "Add a README file"
   - **gitignore**: None (we'll create it ourselves)
   - **License**: None
5. Click "Create repository"

**Step 2: Clone your repository locally**

```bash
# Replace YOUR_GITHUB_USERNAME with your actual GitHub username
export GITHUB_USERNAME="YOUR_GITHUB_USERNAME"

# Clone your newly created repository
git clone https://github.com/$GITHUB_USERNAME/platform-self-service.git
cd platform-self-service
```

**Step 3: Create the basic structure**

```bash
# Create the directory structure for self-service resources
mkdir -p {namespaces,projects,applications}
mkdir -p namespaces/{dev,staging,prod}
```

**Step 4: Update the README**

```bash
# Update the README with platform self-service information
cat << 'EOF' > README.md
# Platform Self-Service

This repository contains self-service resources for development teams.

## Structure

- `namespaces/`: Kubernetes namespace definitions
  - `dev/`: Development environment namespaces
  - `staging/`: Staging environment namespaces  
  - `prod/`: Production environment namespaces
- `projects/`: ArgoCD project definitions
- `applications/`: ArgoCD application definitions

## How to Request Resources

1. Create a branch for your request
2. Add your resource definition in the appropriate directory
3. Submit a Pull Request
4. Once approved and merged, ArgoCD will automatically create the resources

## Example Workflow

### Requesting a New Namespace

1. Create a new branch:
   ```bash
   git checkout -b request-myteam-namespace
   ```

2. Add your namespace definition in the appropriate environment directory:
   ```bash
   # Copy a template or create a new file
   cp namespaces/dev/frontend-dev-namespace.yaml namespaces/dev/myteam-dev-namespace.yaml
   # Edit the file with your team's details
   ```

3. Commit and push your changes:
   ```bash
   git add namespaces/dev/myteam-dev-namespace.yaml
   git commit -m "Request namespace for myteam in dev environment"
   git push origin request-myteam-namespace
   ```

4. Create a Pull Request on GitHub

5. Once the PR is approved and merged, ArgoCD will automatically create your namespace!

EOF
```

**Step 5: Create .gitignore**

```bash
# Create .gitignore to exclude temporary files
cat << 'EOF' > .gitignore
.DS_Store
*.tmp
*.log
kind-config.yaml
EOF
```

### Create Namespace Templates

Let's create templates and examples for namespace requests:

```bash
# Create a namespace template with instructions
cat << 'EOF' > namespaces/README.md
# Namespace Requests

## How to Request a Namespace

1. Copy the template below
2. Replace `TEAM_NAME` with your team name
3. Replace `ENVIRONMENT` with dev/staging/prod
4. Save as `namespaces/ENVIRONMENT/TEAM_NAME-namespace.yaml`
5. Create a Pull Request with your changes

## Template

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: TEAM_NAME-ENVIRONMENT
  labels:
    team: TEAM_NAME
    environment: ENVIRONMENT
    managed-by: platform-team
  annotations:
    team.contact: "team-email@company.com"
    purpose: "Brief description of what this namespace is for"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: TEAM_NAME-ENVIRONMENT-quota
  namespace: TEAM_NAME-ENVIRONMENT
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    persistentvolumeclaims: "4"
    services: "5"
    secrets: "10"
    configmaps: "10"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: TEAM_NAME-ENVIRONMENT-limits
  namespace: TEAM_NAME-ENVIRONMENT
spec:
  limits:
  - default:
      cpu: 500m
      memory: 512Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    type: Container
EOF
```

```bash
# Create an example namespace for the "frontend" team
cat << 'EOF' > namespaces/dev/frontend-dev-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: frontend-dev
  labels:
    team: frontend
    environment: dev
    managed-by: platform-team
  annotations:
    team.contact: "frontend-team@company.com"
    purpose: "Frontend application development environment"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: frontend-dev-quota
  namespace: frontend-dev
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    persistentvolumeclaims: "4"
    services: "5"
    secrets: "10"
    configmaps: "10"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: frontend-dev-limits
  namespace: frontend-dev
spec:
  limits:
  - default:
      cpu: 500m
      memory: 512Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    type: Container
EOF
```

```bash
# Create another example for the "backend" team
cat << 'EOF' > namespaces/dev/backend-dev-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: backend-dev
  labels:
    team: backend
    environment: dev
    managed-by: platform-team
  annotations:
    team.contact: "backend-team@company.com"
    purpose: "Backend services development environment"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: backend-dev-quota
  namespace: backend-dev
spec:
  hard:
    requests.cpu: "3"
    requests.memory: 6Gi
    limits.cpu: "6"
    limits.memory: 12Gi
    persistentvolumeclaims: "8"
    services: "10"
    secrets: "15"
    configmaps: "15"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: backend-dev-limits
  namespace: backend-dev
spec:
  limits:
  - default:
      cpu: 1000m
      memory: 1Gi
    defaultRequest:
      cpu: 200m
      memory: 256Mi
    type: Container
EOF
```

### Commit Initial Structure

Now let's commit and push our initial repository structure to GitHub:

```bash
# Add all files
git add .

# Configure git if needed (use your own name and email)
git config user.email "your-email@example.com"
git config user.name "Your Name"

# Commit the changes
git commit -m "Initial self-service repository structure

- Add namespace templates and examples
- Create directory structure for different environments
- Add documentation for teams"

# Push to GitHub
git push origin main
```

### ✅ Verification Steps - Part 1

Before moving forward, let's verify your repository structure is set up correctly:

```bash
# Verify the directory structure was created
tree .

# Verify git repository is initialized and connected to GitHub
git status
git log --oneline
git remote -v

# Check that all expected files exist
ls -la namespaces/dev/
ls -la namespaces/staging/
ls -la namespaces/prod/
cat README.md
```

**Expected Output:**
- Directory structure should show `namespaces`, `projects`, and `applications` folders
- Git log should show your initial commit
- `git remote -v` should show your GitHub repository URL
- `namespaces/dev/` should contain `frontend-dev-namespace.yaml` and `backend-dev-namespace.yaml`
- README.md should contain documentation about the repository structure

**Verify on GitHub:**
- Navigate to `https://github.com/$GITHUB_USERNAME/platform-self-service` in your browser
- You should see all the files and folders you've created
- The README.md should be displayed on the repository homepage

### 🤔 Reflection Questions - Part 1

Take a moment to think about what you've created:

1. **Repository Structure**: Why do you think we separated namespaces into `dev`, `staging`, and `prod` directories? What advantage does this provide?

2. **Resource Quotas**: Look at the ResourceQuota definitions in the namespace files. Why is it important to set both `requests` and `limits` for CPU and memory?

3. **LimitRange vs ResourceQuota**: What's the difference between `LimitRange` and `ResourceQuota`? Why do we need both in our namespace definitions?

4. **Self-Service Workflow**: How does this repository structure enable a self-service workflow? What steps would a development team take to request a new namespace? Why is using Pull Requests beneficial?

5. **GitOps Benefits**: What are the benefits of managing infrastructure resources (like namespaces) through Git compared to creating them manually with `kubectl`? How does having everything in a Git repository help with auditability and rollback?

6. **GitHub Integration**: How does using a real GitHub repository (instead of a local directory) improve the workflow? What features of GitHub can enhance the self-service process?

## Part 2: Setting Up ArgoCD Projects for Multi-Tenancy

ArgoCD Projects provide a way to group applications and provide team-level access control.

### Create ArgoCD Projects

```bash
# Create projects directory structure
mkdir -p projects

# Create the self-service project
cat << 'EOF' > projects/self-service-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: self-service
  namespace: argocd
spec:
  description: "Self-service platform resources"
  
  # Define what repositories this project can use
  sourceRepos:
  - 'https://github.com/*/platform-self-service.git'
  - 'https://github.com/*/platform-self-service'
  - '*'  # Allow all repos for flexibility during the workshop
  
  # Define where apps in this project can deploy to
  destinations:
  - namespace: 'frontend-*'
    server: https://kubernetes.default.svc
  - namespace: 'backend-*'
    server: https://kubernetes.default.svc
  - namespace: 'data-*'
    server: https://kubernetes.default.svc
  - namespace: 'devops-*'
    server: https://kubernetes.default.svc
  
  # Cluster resource allow list
  clusterResourceWhitelist:
  - group: ''
    kind: Namespace
  
  # Namespace resource allow list
  namespaceResourceWhitelist:
  - group: ''
    kind: ResourceQuota
  - group: ''
    kind: LimitRange
  - group: ''
    kind: ConfigMap
  - group: ''
    kind: Secret
  - group: ''
    kind: Service
  - group: 'apps'
    kind: Deployment
  - group: 'apps'
    kind: ReplicaSet
  - group: ''
    kind: Pod
  
  # RBAC roles for this project
  roles:
  - name: developer
    description: "Developer access for self-service resources"
    policies:
    - p, proj:self-service:developer, applications, get, self-service/*, allow
    - p, proj:self-service:developer, applications, sync, self-service/*, allow
    groups:
    - developers
    
  - name: admin
    description: "Admin access for self-service resources"
    policies:
    - p, proj:self-service:admin, applications, *, self-service/*, allow
    - p, proj:self-service:admin, repositories, *, *, allow
    groups:
    - platform-admins
EOF

# Create a development teams project
cat << 'EOF' > projects/dev-teams-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: dev-teams
  namespace: argocd
spec:
  description: "Development teams applications"
  
  sourceRepos:
  - '*'
  
  destinations:
  - namespace: 'frontend-*'
    server: https://kubernetes.default.svc
  - namespace: 'backend-*'
    server: https://kubernetes.default.svc
  - namespace: 'default'
    server: https://kubernetes.default.svc
  
  clusterResourceWhitelist:
  - group: ''
    kind: Namespace
    
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
    
  roles:
  - name: team-member
    description: "Team member access"
    policies:
    - p, proj:dev-teams:team-member, applications, get, dev-teams/*, allow
    - p, proj:dev-teams:team-member, applications, sync, dev-teams/*, allow
    groups:
    - dev-team-members
EOF

# Commit the projects
git add projects/
git commit -m "Add ArgoCD project definitions for multi-tenancy

- self-service project for platform resources
- dev-teams project for application deployments
- RBAC roles and policies defined"

# Push to GitHub
git push origin main
```

### ✅ Verification Steps - Part 2

Verify your ArgoCD project files are created correctly:

```bash
# Check the project files exist
ls -la projects/

# View the content of the projects
cat projects/self-service-project.yaml
cat projects/dev-teams-project.yaml

# Verify the commit was created
git log --oneline -2
```

**Expected Output:**
- Two project files: `self-service-project.yaml` and `dev-teams-project.yaml`
- Each file should contain an `AppProject` resource with `metadata`, `spec`, and `roles`
- Git log should show the latest commit about ArgoCD projects

### 🤔 Reflection Questions - Part 2

Consider these questions about ArgoCD projects and multi-tenancy:

1. **Multi-Tenancy**: How do ArgoCD Projects help achieve multi-tenancy in a Kubernetes cluster? What aspects of isolation do they provide?

2. **Source Repositories**: In the `self-service-project.yaml`, we defined specific source repositories. Why would we restrict which repositories a project can use?

3. **Destination Namespaces**: Notice the namespace patterns like `frontend-*` and `backend-*` in the destinations. Why use wildcards instead of listing specific namespaces?

4. **RBAC Roles**: What's the difference between the `developer` and `admin` roles defined in the self-service project? When would each role be appropriate?

5. **Resource Whitelists**: We defined `clusterResourceWhitelist` and `namespaceResourceWhitelist`. What happens if a team tries to deploy a resource type that's not in these lists?

6. **Security Implications**: How do these project definitions help prevent teams from accidentally (or intentionally) deploying resources they shouldn't?

## Part 3: Creating ArgoCD Applications for Self-Service

### Create the Self-Service Application

Let's create an ArgoCD application that will monitor your GitHub repository for changes:

```bash
# Create applications directory
mkdir -p applications

# Create the self-service application
# Replace YOUR_GITHUB_USERNAME with your actual username
cat << EOF > applications/self-service-namespaces.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: self-service-namespaces
  namespace: argocd
spec:
  project: self-service
  
  source:
    repoURL: 'https://github.com/$GITHUB_USERNAME/platform-self-service.git'
    targetRevision: HEAD
    path: namespaces
    
  destination:
    server: https://kubernetes.default.svc
    
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
    
  # Health check configuration
  ignoreDifferences:
  - group: v1
    kind: Namespace
    jsonPointers:
    - /metadata/annotations
    - /metadata/labels
EOF

# Commit and push the application definition
git add applications/
git commit -m "Add self-service namespaces application

- Monitors namespaces directory for changes
- Automated sync with prune and self-heal
- Creates namespaces automatically from GitHub repository"

git push origin main
```

### ✅ Verification Steps - Part 3

Verify the application definition is correct:

```bash
# Check the application file
ls -la applications/
cat applications/self-service-namespaces.yaml

# Verify all commits so far
git log --oneline
```

**Expected Output:**
- Application file `self-service-namespaces.yaml` should exist
- It should reference `project: self-service`
- The source path should point to `namespaces`
- Git history should show 3 commits

### 🤔 Reflection Questions - Part 3

Think about ArgoCD applications and automation:

1. **Automated Sync**: We enabled `automated` sync with `prune: true` and `selfHeal: true`. What do each of these options do? What are the risks and benefits?

2. **Source Path**: The application watches the `namespaces` path. What happens when someone adds a new YAML file to `namespaces/dev/`?

3. **GitHub Repository**: We're using a real GitHub repository URL `https://github.com/$GITHUB_USERNAME/platform-self-service.git`. What advantages does this provide over a local file path? How does ArgoCD monitor the repository for changes?

4. **Sync Options**: What does `CreateNamespace=true` do? Why might we want to use `PrunePropagationPolicy=foreground`?

5. **Application vs Project**: What's the relationship between an ArgoCD Application and an ArgoCD Project? Why do we need both?

## Part 4: Applying the Configuration to ArgoCD

Now let's apply our configuration to the running ArgoCD instance. ArgoCD will connect to your GitHub repository and start monitoring it for changes.

### Apply ArgoCD Projects

```bash
# Apply the projects to ArgoCD
kubectl apply -f projects/self-service-project.yaml
kubectl apply -f projects/dev-teams-project.yaml

# Verify projects were created
argocd proj list

# Get detailed information about the self-service project
argocd proj get self-service
```

### Configure ArgoCD to Access Your GitHub Repository

ArgoCD needs to be configured to access your GitHub repository. For public repositories, this is straightforward:

```bash
# Add your GitHub repository to ArgoCD
argocd repo add https://github.com/$GITHUB_USERNAME/platform-self-service.git
```

**For Private Repositories (Optional):**

If you created a private repository, you'll need to provide credentials:

```bash
# Option 1: Using HTTPS with Personal Access Token
# Create a token at https://github.com/settings/tokens with 'repo' scope
argocd repo add https://github.com/$GITHUB_USERNAME/platform-self-service.git \
  --username $GITHUB_USERNAME \
  --password YOUR_GITHUB_TOKEN

# Option 2: Using SSH (if you prefer SSH authentication)
# Add your SSH key to GitHub first
argocd repo add git@github.com:$GITHUB_USERNAME/platform-self-service.git \
  --ssh-private-key-path ~/.ssh/id_rsa
```

### Create the ArgoCD Application

Now create the application that will sync your namespaces from GitHub to Kubernetes:

```bash
# Create the application using ArgoCD CLI
argocd app create self-service-namespaces \
  --project self-service \
  --repo https://github.com/$GITHUB_USERNAME/platform-self-service.git \
  --path namespaces \
  --dest-server https://kubernetes.default.svc \
  --sync-policy automated \
  --auto-prune \
  --self-heal

# Alternatively, apply the YAML directly
kubectl apply -f applications/self-service-namespaces.yaml
```

### Sync the Application

Trigger an initial sync to create the namespaces:

```bash
# Sync the application
argocd app sync self-service-namespaces

# Watch the sync progress
argocd app get self-service-namespaces --watch

# Verify the namespaces were created
kubectl get namespaces | grep -E "(frontend|backend)"
kubectl get resourcequota --all-namespaces
kubectl get limitranges --all-namespaces

# Check the labels and annotations
kubectl describe namespace frontend-dev
kubectl describe namespace backend-dev
```

### ✅ Verification Steps - Part 4

Now verify that everything was applied correctly to your cluster:

```bash
# Verify ArgoCD projects were created
argocd proj list

# Get detailed information about the projects
argocd proj get self-service
argocd proj get dev-teams

# Check the projects in Kubernetes
kubectl get appprojects -n argocd

# Verify the repository was added to ArgoCD
argocd repo list

# Check the ArgoCD application status
argocd app get self-service-namespaces
argocd app list

# Verify namespaces were created
kubectl get namespaces | grep -E "(frontend|backend)"

# Check ResourceQuotas are in place
kubectl get resourcequota -n frontend-dev
kubectl get resourcequota -n backend-dev

# Verify LimitRanges are applied
kubectl get limitrange -n frontend-dev
kubectl get limitrange -n backend-dev

# Inspect the namespace details
kubectl describe namespace frontend-dev
kubectl get namespace frontend-dev -o yaml
```

**Expected Output:**
- `argocd proj list` should show both `self-service` and `dev-teams` projects
- `argocd repo list` should show your GitHub repository
- `argocd app get self-service-namespaces` should show status as "Synced" and "Healthy"
- `kubectl get namespaces` should show `frontend-dev` and `backend-dev`
- Each namespace should have a ResourceQuota and LimitRange
- Namespace labels should include `team`, `environment`, and `managed-by`

**View in ArgoCD UI:**

You can also verify this in the ArgoCD web interface:
1. Open ArgoCD in your browser (e.g., http://argocd.127.0.0.1.nip.io)
2. You should see the `self-service-namespaces` application
3. Click on it to see the visualization of deployed resources
4. The application should be in "Synced" and "Healthy" state

### 🤔 Reflection Questions - Part 4

Consider what you've deployed:

1. **Project Visibility**: When you run `argocd proj get self-service`, what information is shown? What are the key restrictions this project enforces?

2. **Resource Limits**: Look at the output of `kubectl describe resourcequota -n frontend-dev`. How much of the quota is currently used vs available?

3. **Default Limits**: When you inspect the LimitRange, you see `default` and `defaultRequest` values. When do these defaults get applied to pods?

4. **Namespace Metadata**: Why did we add labels like `team`, `environment`, and `managed-by` to the namespaces? How could these be useful?

5. **Validation**: If you try to create a pod in `frontend-dev` without specifying resource requests/limits, what would happen? Why?

## Part 5: Demonstrating the Self-Service Workflow

Now we'll demonstrate the complete self-service workflow using Pull Requests on GitHub, just as teams would do in a real platform engineering environment.

### Simulating a Team Request via Pull Request

Let's simulate how a new team would request a namespace through a Pull Request:

**Step 1: Create a new branch for the request**

```bash
# Create a new branch for the mobile team's request
git checkout -b request-mobile-dev-namespace

# Create the namespace definition for the mobile team
cat << 'EOF' > namespaces/dev/mobile-dev-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: mobile-dev
  labels:
    team: mobile
    environment: dev
    managed-by: platform-team
  annotations:
    team.contact: "mobile-team@company.com"
    purpose: "Mobile application development environment"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: mobile-dev-quota
  namespace: mobile-dev
spec:
  hard:
    requests.cpu: "1"
    requests.memory: 2Gi
    limits.cpu: "2"
    limits.memory: 4Gi
    persistentvolumeclaims: "2"
    services: "3"
    secrets: "5"
    configmaps: "5"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: mobile-dev-limits
  namespace: mobile-dev
spec:
  limits:
  - default:
      cpu: 500m
      memory: 512Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    type: Container
EOF

# Commit the change
git add namespaces/dev/mobile-dev-namespace.yaml
git commit -m "Request mobile team development namespace

Requested by: mobile-team@company.com
Purpose: Mobile application development environment
Resources: 1-2 CPU cores, 2-4Gi memory"

# Push the branch to GitHub
git push origin request-mobile-dev-namespace
```

**Step 2: Create a Pull Request on GitHub**

1. Navigate to your repository on GitHub: `https://github.com/$GITHUB_USERNAME/platform-self-service`
2. GitHub will show a banner saying "request-mobile-dev-namespace had recent pushes"
3. Click "Compare & pull request"
4. Fill in the Pull Request details:
   - **Title**: "Request mobile team development namespace"
   - **Description**: 
     ```
     ## Namespace Request
     
     **Team**: Mobile
     **Environment**: Development
     **Contact**: mobile-team@company.com
     **Purpose**: Mobile application development environment
     
     ## Resources
     - CPU: 1-2 cores
     - Memory: 2-4Gi
     - PVCs: 2
     - Services: 3
     ```
5. Click "Create pull request"

**Step 3: Review and Merge the Pull Request**

In a real environment, a platform team member would review the PR. For this workshop, you'll approve your own PR:

1. Review the changes in the "Files changed" tab
2. Click "Merge pull request"
3. Click "Confirm merge"
4. Optionally, delete the branch after merging

**Step 4: Watch ArgoCD Automatically Create the Namespace**

```bash
# Switch back to main branch and pull the changes
git checkout main
git pull origin main

# Watch ArgoCD detect the change and sync
argocd app get self-service-namespaces --watch

# After a few moments (ArgoCD polls every 3 minutes by default), verify the namespace was created
kubectl get namespace mobile-dev

# If you don't want to wait, you can manually trigger a sync
argocd app sync self-service-namespaces

# Verify it was created
kubectl get namespace mobile-dev
kubectl describe namespace mobile-dev

# Check the resource quota
kubectl get resourcequota -n mobile-dev
kubectl describe resourcequota mobile-dev-quota -n mobile-dev
```

### Testing Resource Quotas

Let's test that our resource quotas are working:

```bash
# Create a test deployment in the frontend-dev namespace
cat << 'EOF' > /tmp/test-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: frontend-dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: test-container
        image: nginx:alpine
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
EOF

# Apply the test deployment
kubectl apply -f /tmp/test-deployment.yaml

# Check the deployment
kubectl get deployments -n frontend-dev
kubectl get pods -n frontend-dev

# Check resource usage against quotas
kubectl describe resourcequota frontend-dev-quota -n frontend-dev

# Clean up the test deployment
kubectl delete -f /tmp/test-deployment.yaml
```

### ✅ Verification Steps - Part 5

Verify the self-service workflow worked correctly:

```bash
# Verify you're on the main branch with latest changes
git branch
git log --oneline -3

# Verify the mobile-dev namespace was created
kubectl get namespace mobile-dev
kubectl describe namespace mobile-dev

# Check all our team namespaces
kubectl get namespaces | grep -E "(frontend|backend|mobile)"

# Verify the quota for mobile-dev
kubectl get resourcequota -n mobile-dev
kubectl describe resourcequota mobile-dev-quota -n mobile-dev

# Check in ArgoCD UI or CLI
argocd app get self-service-namespaces
```

**Verify on GitHub:**
- Navigate to your repository's "Pull requests" tab
- You should see the merged PR
- Click on "Closed" to see the merged request
- Review the PR timeline showing the merge event

**Verify in ArgoCD UI:**
- Open ArgoCD web interface
- Click on the `self-service-namespaces` application
- You should see the mobile-dev namespace in the resource tree
- All resources should be in "Synced" and "Healthy" state

**Expected Output:**
- `mobile-dev` namespace should exist with appropriate labels
- Resource quota should show limits: 1-2 CPU, 2-4Gi memory
- Git log should show the merge commit from GitHub
- ArgoCD should show the application is synced
- Pull request on GitHub should be merged and closed

### 🤔 Reflection Questions - Part 5

Reflect on the self-service workflow:

1. **Pull Request Workflow**: Walk through the complete steps a real team would take to request a namespace. How does the PR-based workflow add value compared to direct commits?

2. **Approval Process**: In a real production environment, who should review and approve namespace requests? What should they check before approving a PR?

3. **Resource Allocation**: The mobile team requested fewer resources than the backend team. How does this flexible quota system benefit the organization?

4. **ArgoCD Sync**: After merging the PR, how long did it take for ArgoCD to detect the change? How could you speed this up if needed?

5. **GitOps Audit Trail**: Look at the Git commit history and GitHub PR history. How does this provide better auditability compared to manual `kubectl` commands?

6. **Prune Behavior**: If you created a new branch, deleted the `mobile-dev-namespace.yaml` file, and merged that PR, what would happen in ArgoCD? (With automated sync and prune enabled)

7. **Rollback Scenario**: If there was a problem with the mobile-dev namespace, how could you use Git to roll back the change?

## Part 6: Testing the Complete Self-Service Workflow

Now let's test that resource quotas work correctly and demonstrate additional workflow features.

### Testing Resource Quotas

Let's test that our resource quotas are working:

```bash
# Create a test deployment in the frontend-dev namespace
cat << 'EOF' > /tmp/test-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: frontend-dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: test-container
        image: nginx:alpine
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
EOF

# Apply the test deployment
kubectl apply -f /tmp/test-deployment.yaml

# Check the deployment
kubectl get deployments -n frontend-dev
kubectl get pods -n frontend-dev

# Check resource usage against quotas
kubectl describe resourcequota frontend-dev-quota -n frontend-dev

# Clean up the test deployment
kubectl delete -f /tmp/test-deployment.yaml
```

### Practicing the PR Workflow - Second Request

Let's practice the workflow one more time with a different team:

```bash
# Create a new branch for data team
git checkout -b request-data-staging-namespace

# Create the namespace definition
cat << 'EOF' > namespaces/staging/data-staging-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: data-staging
  labels:
    team: data
    environment: staging
    managed-by: platform-team
  annotations:
    team.contact: "data-team@company.com"
    purpose: "Data processing staging environment"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: data-staging-quota
  namespace: data-staging
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "10"
    services: "5"
    secrets: "15"
    configmaps: "15"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: data-staging-limits
  namespace: data-staging
spec:
  limits:
  - default:
      cpu: 1000m
      memory: 1Gi
    defaultRequest:
      cpu: 250m
      memory: 256Mi
    type: Container
EOF

# Commit and push
git add namespaces/staging/data-staging-namespace.yaml
git commit -m "Request data team staging namespace

Requested by: data-team@company.com
Purpose: Data processing staging environment
Resources: 4-8 CPU cores, 8-16Gi memory"

git push origin request-data-staging-namespace
```

**Now:**
1. Go to GitHub and create a Pull Request for this branch
2. Review the changes
3. Merge the Pull Request
4. Watch ArgoCD sync the changes
5. Verify the namespace was created

```bash
# Return to main and pull changes
git checkout main
git pull origin main

# Sync ArgoCD (or wait for auto-sync)
argocd app sync self-service-namespaces

# Verify the new namespace
kubectl get namespace data-staging
kubectl describe namespace data-staging
```

## Part 7: Advanced Self-Service Features and GitHub Workflows

### Creating Application Templates

Let's create templates for common application deployments:

```bash
# Create application templates directory
mkdir -p applications/templates

# Create a simple web application template
cat << 'EOF' > applications/templates/web-app-template.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: TEAM_NAME-APP_NAME
  namespace: argocd
spec:
  project: dev-teams
  
  source:
    repoURL: 'https://github.com/TEAM_NAME/APP_NAME.git'
    targetRevision: HEAD
    path: k8s
    
  destination:
    server: https://kubernetes.default.svc
    namespace: TEAM_NAME-ENVIRONMENT
    
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=false  # Namespace should already exist via self-service request
EOF

# Create documentation for the template
cat << 'EOF' > applications/templates/README.md
# Application Templates

## Web Application Template

To deploy a web application:

1. Request a namespace first (via PR in namespaces/ directory)
2. Copy `web-app-template.yaml`
3. Replace the following placeholders:
   - `TEAM_NAME`: Your team name
   - `APP_NAME`: Your application name  
   - `ENVIRONMENT`: Target environment (dev/staging/prod)
4. Save as `applications/TEAM_NAME-APP_NAME.yaml`
5. Submit a Pull Request to this repository

## Requirements

- Your application repository must have a `k8s/` directory with Kubernetes manifests
- The target namespace must already exist (request via namespaces/ directory first)
- Your application must follow the resource limits defined in the namespace quota
- Your application repository must be accessible to ArgoCD

## Example

If the "mobile" team wants to deploy their "api" application to the dev environment:

1. First ensure `mobile-dev` namespace exists
2. Copy the template and create `applications/mobile-api-dev.yaml`
3. Replace placeholders:
   - `TEAM_NAME`: mobile
   - `APP_NAME`: api
   - `ENVIRONMENT`: dev
4. Create a PR with the file
5. After merge, ArgoCD will deploy your application!
EOF

# Commit and push
git add applications/templates/
git commit -m "Add application deployment templates

- Web application template for team self-service
- Documentation for template usage
- Follows GitOps best practices with PR workflow"

git push origin main
```

### Optional: Adding GitHub Actions for Validation

You can enhance your self-service repository with GitHub Actions to validate PRs:

```bash
# Create GitHub Actions workflow directory
mkdir -p .github/workflows

# Create a validation workflow
cat << 'EOF' > .github/workflows/validate-pr.yaml
name: Validate Namespace Requests

on:
  pull_request:
    paths:
      - 'namespaces/**/*.yaml'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Validate YAML syntax
        run: |
          for file in $(find namespaces -name "*.yaml"); do
            echo "Validating $file"
            # Check if file is valid YAML
            python3 -c "import yaml; yaml.safe_load(open('$file'))" || exit 1
          done
      
      - name: Check resource limits
        run: |
          echo "✅ YAML validation passed"
          echo "Note: Platform team should review resource quotas before approving"
EOF

# Commit and push
git add .github/workflows/
git commit -m "Add GitHub Actions workflow for PR validation

- Validates YAML syntax for namespace requests
- Runs automatically on pull requests
- Helps catch errors before merge"

git push origin main
```

### ✅ Verification Steps - Part 7

Verify the templates and optional workflows are in place:

```bash
# Check templates directory
ls -la applications/templates/

# View the template files
cat applications/templates/web-app-template.yaml
cat applications/templates/README.md

# Check GitHub Actions workflow (if created)
ls -la .github/workflows/ 2>/dev/null || echo "GitHub Actions not configured"

# Check git history
git log --oneline -5

# Verify all changes are on GitHub
git status
```

**Expected Output:**
- Templates directory should contain `web-app-template.yaml` and `README.md`
- Template should have placeholders like `TEAM_NAME`, `APP_NAME`, `ENVIRONMENT`
- Git log should show the template commits
- All changes should be pushed to GitHub

### 🤔 Reflection Questions - Part 7

Think about application templates and advanced features:

1. **Template Placeholders**: Why use placeholders like `TEAM_NAME` and `APP_NAME` instead of actual values? How would teams customize these templates?

2. **Project Assignment**: The template assigns the application to the `dev-teams` project. Why not the `self-service` project?

3. **Namespace Creation**: Notice `CreateNamespace=false` in the template. Why is this set to false when we had it as true in the self-service application?

4. **Repository Requirements**: The template assumes applications have a `k8s/` directory. What should teams put in this directory?

5. **Automation vs Control**: We've enabled automated sync and self-heal for the application template. In what scenarios might you want to disable automation?

6. **Scaling the Platform**: How would you handle 50 teams each with 5 applications? Would creating 250 individual Application manifests be manageable? What alternatives exist? (Hint: Look into ApplicationSets)

7. **GitHub Actions**: If you added the GitHub Actions workflow, how does automated validation improve the self-service experience? What other validations could you add?

## Troubleshooting

### Common Issues

#### ArgoCD Project Permissions
```bash
# If you get permission errors, check project configuration
argocd proj get self-service

# Verify project policies
kubectl describe appproject self-service -n argocd
```

#### Namespace Creation Issues
```bash
# Check if namespaces were created successfully
kubectl get namespaces | grep -E "(frontend|backend|mobile)"

# Check for events if namespace creation failed
kubectl get events --all-namespaces | grep -i error

# Verify resource quotas are applied
kubectl get resourcequota --all-namespaces
```

#### Application Sync Issues
```bash
# Check application status
argocd app get self-service-namespaces

# Force sync if needed
argocd app sync self-service-namespaces

# Check for sync errors
argocd app get self-service-namespaces --output json | jq '.status.conditions'
```

### Cleanup (Optional)

If you need to start over or clean up resources:

```bash
# Delete created namespaces
kubectl delete namespace frontend-dev backend-dev mobile-dev data-staging 2>/dev/null || true

# Delete ArgoCD applications
argocd app delete self-service-namespaces --yes

# Delete ArgoCD projects  
argocd proj delete self-service dev-teams

# Remove the GitHub repository from ArgoCD
argocd repo rm https://github.com/$GITHUB_USERNAME/platform-self-service.git

# Optionally, delete your local clone
cd ..
rm -rf platform-self-service

# Note: Your GitHub repository will remain - delete it manually on GitHub if desired
```

## Final Verification - Complete Lab Check

Before moving to LAB03, verify your complete setup:

```bash
# Check all ArgoCD projects
argocd proj list

# Verify all namespaces
kubectl get namespaces | grep -E "(frontend|backend|mobile|data)"

# Review all resource quotas
kubectl get resourcequota --all-namespaces

# Check all commits in your self-service repo
git log --oneline --graph --all

# Verify the complete directory structure
tree . -L 3 2>/dev/null || find . -maxdepth 3 -not -path '*/\.git/*'

# Verify everything is pushed to GitHub
git status
git remote -v
```

### ✅ Final Checklist

Ensure you can answer "yes" to all of these:

- [ ] I can explain what ArgoCD Projects are and how they enable multi-tenancy
- [ ] I understand the difference between ResourceQuota and LimitRange
- [ ] I understand the Pull Request workflow for requesting infrastructure resources
- [ ] I know how to create a branch, commit changes, and create a PR on GitHub
- [ ] I can describe what happens when code is merged to the main branch of the self-service repository
- [ ] I understand how automated sync, prune, and self-heal work in ArgoCD
- [ ] I can explain the RBAC roles defined in the ArgoCD projects
- [ ] I know how to verify if a namespace is within its resource quota limits
- [ ] I understand why we use Git for infrastructure as code and the benefits of GitOps
- [ ] I know how GitHub PRs provide auditability and approval workflows for infrastructure changes

### 🎯 Challenge Exercises (Optional)

If you have time, try these challenges:

1. **Create a Production Namespace**: Following the pattern and PR workflow, create a `frontend-prod` namespace with stricter resource limits than dev
2. **Add Network Policy**: Research and add a NetworkPolicy to isolate the frontend-dev namespace, submit via PR
3. **Custom Quota**: Create a namespace for a "data-science" team that needs more CPU but less memory, use the full PR workflow
4. **Validation Webhook**: Research how you could add validation to ensure all namespace requests follow the template correctly (hint: GitHub Actions or OPA Gatekeeper)
5. **Cost Labels**: Add additional labels for cost center and project code to enable chargeback, submit via PR
6. **Branch Protection**: Set up branch protection rules on GitHub to require PR reviews before merging

## Next Steps

Congratulations! You now have:
- ✅ A GitHub repository for self-service platform resources
- ✅ A self-service workflow using Pull Requests
- ✅ ArgoCD projects configured for multi-tenancy
- ✅ Automated namespace creation via GitOps from GitHub
- ✅ Resource quotas and limits for teams
- ✅ Experience with the complete PR-based self-service workflow
- ✅ Templates for common deployment patterns
- ✅ Understanding of how Git history provides auditability

You're ready for LAB03 where we'll explore deploying resources outside of Kubernetes using tools like ASO, KRO, Terranetes, or Crossplane.

### Real-World Implementation

Your lab setup is very close to a production implementation! To enhance it further, you would:

1. **Branch Protection**: Enable branch protection on GitHub requiring:
   - At least one approval before merging
   - Status checks to pass (like GitHub Actions)
   - Prevent direct pushes to main

2. **PR Templates**: Create PR templates in `.github/PULL_REQUEST_TEMPLATE.md` with:
   - Checklist for resource requests
   - Required fields (team name, contact, justification)
   - Link to documentation

3. **CODEOWNERS**: Create a `.github/CODEOWNERS` file specifying who must review changes to specific directories

4. **Advanced Validation**: Add more sophisticated validation:
   - Lint YAML files
   - Check resource quotas are within organization limits
   - Validate naming conventions
   - Cost estimation

5. **Notifications**: Set up notifications:
   - Slack/Teams notifications for new PRs
   - Alerts when resources are created/modified
   - Weekly reports on resource usage

6. **Security**: Implement:
   - Pod Security Standards
   - Network Policies
   - RBAC for actual users (integrate with your identity provider)
   - Secret management (using tools like External Secrets Operator)

### Advanced Features to Explore

- **Policy as Code**: Use OPA Gatekeeper for policy enforcement
- **Cost Management**: Add cost tracking and budgets per namespace
- **Backup**: Implement automated backup strategies
- **Networking**: Add network policies for namespace isolation
- **Security**: Implement Pod Security Standards and vulnerability scanning

## Useful Commands for Future Reference

```bash
# ArgoCD project commands
argocd proj list
argocd proj get PROJECT_NAME
argocd proj create PROJECT_NAME

# Application management
argocd app list
argocd app sync APP_NAME
argocd app get APP_NAME
argocd app delete APP_NAME

# Namespace management
kubectl get namespaces
kubectl describe namespace NAMESPACE_NAME
kubectl get resourcequota --all-namespaces
kubectl get limitranges --all-namespaces

# Git workflow simulation
git add .
git commit -m "Add new team namespace"
git log --oneline
```

## Resources

- [ArgoCD Projects Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/projects/)
- [Kubernetes Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [Kubernetes Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/)
- [GitOps Best Practices](https://argoproj.github.io/argo-cd/user-guide/best_practices/)
- [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [ArgoCD ApplicationSets](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)
- [Pull Request Best Practices](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests)
