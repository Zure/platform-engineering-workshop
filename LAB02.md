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

## Overview

In this lab, we'll simulate a platform engineering scenario where development teams can request resources (like namespaces) through a self-service mechanism. We'll use:

- **ArgoCD Projects**: For tenant isolation and access control
- **GitOps**: Teams submit requests via Pull Requests
- **Namespace-as-Code**: Kubernetes namespaces defined in YAML
- **Automation**: ArgoCD automatically applies approved changes

## Part 1: Setting Up the Self-Service Repository

### Create a Self-Service Repository

First, let's create a repository structure for self-service requests.

```bash
# Create a local directory for our self-service repo
mkdir -p /tmp/platform-self-service
cd /tmp/platform-self-service
```

```bash
# Initialize git repository
git init
```

```bash
# Create the basic structure
mkdir -p {namespaces,projects,applications}
mkdir -p namespaces/{dev,staging,prod}
```

```bash
# Create README
cat << 'EOF' > README.md
```
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

```bash
# Create .gitignore
cat << 'EOF' > .gitignore
.DS_Store
*.tmp
*.log
EOF
```

### Create Namespace Templates

Let's create templates and examples for namespace requests:

```bash
# Create a namespace template
cat << 'EOF' > namespaces/README.md

# Namespace Requests

## How to Request a Namespace

1. Copy the template below
2. Replace `TEAM_NAME` with your team name
3. Replace `ENVIRONMENT` with dev/staging/prod
4. Save as `namespaces/ENVIRONMENT/TEAM_NAME-namespace.yaml`
5. Submit a Pull Request

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

```bash
# Add all files and commit
git add .
git config user.email "platform@company.com"
git config user.name "Platform Team"
git commit -m "Initial self-service repository structure

- Add namespace templates and examples
- Create directory structure for different environments
- Add documentation for teams"
```

### ✅ Verification Steps - Part 1

Before moving forward, let's verify your repository structure is set up correctly:

```bash
# Verify the directory structure was created
tree /tmp/platform-self-service

# Verify git repository is initialized
cd /tmp/platform-self-service
git status
git log --oneline

# Check that all expected files exist
ls -la namespaces/dev/
ls -la namespaces/staging/
ls -la namespaces/prod/
cat README.md
```

**Expected Output:**
- Directory structure should show `namespaces`, `projects`, and `applications` folders
- Git log should show your initial commit
- `namespaces/dev/` should contain `frontend-dev-namespace.yaml` and `backend-dev-namespace.yaml`
- README.md should contain documentation about the repository structure

### 🤔 Reflection Questions - Part 1

Take a moment to think about what you've created:

1. **Repository Structure**: Why do you think we separated namespaces into `dev`, `staging`, and `prod` directories? What advantage does this provide?

2. **Resource Quotas**: Look at the ResourceQuota definitions in the namespace files. Why is it important to set both `requests` and `limits` for CPU and memory?

3. **LimitRange vs ResourceQuota**: What's the difference between `LimitRange` and `ResourceQuota`? Why do we need both in our namespace definitions?

4. **Self-Service Workflow**: How does this repository structure enable a self-service workflow? What steps would a development team take to request a new namespace?

5. **GitOps Benefits**: What are the benefits of managing infrastructure resources (like namespaces) through Git compared to creating them manually with `kubectl`?

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

Let's create an ArgoCD application that will monitor our self-service repository:

```bash
# Create applications directory
mkdir -p applications

# Create the self-service application
cat << 'EOF' > applications/self-service-namespaces.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: self-service-namespaces
  namespace: argocd
spec:
  project: self-service
  
  source:
    repoURL: 'file:///tmp/platform-self-service'  # For this lab, we'll use local path
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

git add applications/
git commit -m "Add self-service namespaces application

- Monitors namespaces directory for changes
- Automated sync with prune and self-heal
- Creates namespaces automatically"
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

3. **File vs Git Repository**: We're using `file:///tmp/platform-self-service` for this lab. How would behavior differ if we used a real GitHub repository?

4. **Sync Options**: What does `CreateNamespace=true` do? Why might we want to use `PrunePropagationPolicy=foreground`?

5. **Application vs Project**: What's the relationship between an ArgoCD Application and an ArgoCD Project? Why do we need both?

## Part 4: Applying the Configuration to ArgoCD

Now let's apply our configuration to the running ArgoCD instance:

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

### Create Repository for Local Testing

For this lab, we'll simulate a Git repository using a local path. In a real environment, you would push this to GitHub and configure ArgoCD to use the GitHub repository.

```bash
# Create a way for ArgoCD to access our local repo
# In production, you would use a GitHub repository instead

# First, let's create the application using ArgoCD CLI
argocd app create self-service-namespaces \
  --project self-service \
  --repo file:///tmp/platform-self-service \
  --path namespaces \
  --dest-server https://kubernetes.default.svc \
  --sync-policy automated \
  --auto-prune \
  --self-heal

# Alternative: Apply the YAML directly (if CLI method doesn't work with local files)
# We'll modify our application to use a more practical approach
```

### Alternative Approach: Using kubectl apply

Since local file repositories might not work directly with ArgoCD, let's use a different approach:

```bash
# Apply namespaces directly to demonstrate the concept
kubectl apply -f namespaces/dev/

# Verify the namespaces were created
kubectl get namespaces
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
- `kubectl get namespaces` should show `frontend-dev` and `backend-dev`
- Each namespace should have a ResourceQuota and LimitRange
- Namespace labels should include `team`, `environment`, and `managed-by`

### 🤔 Reflection Questions - Part 4

Consider what you've deployed:

1. **Project Visibility**: When you run `argocd proj get self-service`, what information is shown? What are the key restrictions this project enforces?

2. **Resource Limits**: Look at the output of `kubectl describe resourcequota -n frontend-dev`. How much of the quota is currently used vs available?

3. **Default Limits**: When you inspect the LimitRange, you see `default` and `defaultRequest` values. When do these defaults get applied to pods?

4. **Namespace Metadata**: Why did we add labels like `team`, `environment`, and `managed-by` to the namespaces? How could these be useful?

5. **Validation**: If you try to create a pod in `frontend-dev` without specifying resource requests/limits, what would happen? Why?

## Part 5: Demonstrating the Self-Service Workflow

### Simulating a Team Request

Let's simulate how a new team would request a namespace:

```bash
# Simulate a new team "mobile" requesting a development namespace
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

# Apply the new namespace
kubectl apply -f namespaces/dev/mobile-dev-namespace.yaml

# Verify it was created
kubectl get namespace mobile-dev
kubectl describe namespace mobile-dev

# Commit the change
git add namespaces/dev/mobile-dev-namespace.yaml
git commit -m "Add mobile team development namespace

Requested by: mobile-team@company.com
Purpose: Mobile application development environment
Resources: 1-2 CPU cores, 2-4Gi memory"
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

Verify the new namespace and test deployment:

```bash
# Verify the mobile-dev namespace was created
kubectl get namespace mobile-dev
kubectl describe namespace mobile-dev

# Check all our team namespaces
kubectl get namespaces | grep -E "(frontend|backend|mobile)"

# Verify the quota for mobile-dev
kubectl get resourcequota -n mobile-dev
kubectl describe resourcequota mobile-dev-quota -n mobile-dev

# Check that the test deployment was created and then deleted
kubectl get deployments -n frontend-dev
kubectl get pods -n frontend-dev

# Review the resource quota usage after cleanup
kubectl describe resourcequota frontend-dev-quota -n frontend-dev
```

**Expected Output:**
- `mobile-dev` namespace should exist with appropriate labels
- Resource quota should show limits: 1-2 CPU, 2-4Gi memory
- After cleanup, no deployments should exist in `frontend-dev`
- Resource quota should show 0 usage after test deployment is deleted

### 🤔 Reflection Questions - Part 5

Reflect on the self-service workflow:

1. **Team Request Simulation**: Walk through the steps a real team would take to request a namespace. What would be different in a production environment with GitHub?

2. **Resource Allocation**: The mobile team requested fewer resources than the backend team. How does this flexible quota system benefit the organization?

3. **Quota Enforcement**: When you ran `kubectl describe resourcequota`, what did the output tell you about current usage? What happens when a team tries to exceed their quota?

4. **Testing Impact**: When you deployed the test application, how much of the frontend-dev quota did it consume? How did you determine this?

5. **GitOps Workflow**: In a real scenario, the mobile team would submit a Pull Request. What validations would you want to run before approving such a PR?

6. **Prune Behavior**: If you deleted the `mobile-dev-namespace.yaml` file and committed it, what would happen in ArgoCD? (With automated sync and prune enabled)

## Part 6: Setting Up GitHub Integration (Optional)

For a complete self-service setup, you would integrate with GitHub:

### GitHub Repository Setup

```bash
# Commands you would run to set up a real GitHub repository
# (These are for reference - don't run in this lab)

# 1. Create repository on GitHub
# gh repo create platform-self-service --public --description "Platform self-service resources"

# 2. Push our local repository
# git remote add origin https://github.com/YOUR_ORG/platform-self-service.git
# git branch -M main
# git push -u origin main

# 3. Configure ArgoCD to use the GitHub repository
# argocd repo add https://github.com/YOUR_ORG/platform-self-service.git

# 4. Update the application to use GitHub URL
# argocd app set self-service-namespaces --repo https://github.com/YOUR_ORG/platform-self-service.git
```

### ArgoCD Repository Configuration

Here's how you would configure ArgoCD to use a GitHub repository:

```yaml
# Example repository configuration (save as repo-config.yaml)
apiVersion: v1
kind: Secret
metadata:
  name: platform-self-service-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: https://github.com/YOUR_ORG/platform-self-service.git
  # For private repositories, add credentials:
  # username: your-username
  # password: your-token
```

## Part 7: Advanced Self-Service Features

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
    - CreateNamespace=false  # Namespace should already exist
EOF

# Create documentation for the template
cat << 'EOF' > applications/templates/README.md
# Application Templates

## Web Application Template

To deploy a web application:

1. Copy `web-app-template.yaml`
2. Replace the following placeholders:
   - `TEAM_NAME`: Your team name
   - `APP_NAME`: Your application name  
   - `ENVIRONMENT`: Target environment (dev/staging/prod)
3. Save as `applications/TEAM_NAME-APP_NAME.yaml`
4. Submit a Pull Request

## Requirements

- Your application repository must have a `k8s/` directory with Kubernetes manifests
- The target namespace must already exist (request via namespaces/ directory)
- Your application must follow the resource limits defined in the namespace
EOF

git add applications/templates/
git commit -m "Add application deployment templates

- Web application template for team self-service
- Documentation for template usage
- Follows GitOps best practices"
```

### ✅ Verification Steps - Part 7

Verify the templates are in place:

```bash
# Check templates directory
ls -la applications/templates/

# View the template files
cat applications/templates/web-app-template.yaml
cat applications/templates/README.md

# Check git history
git log --oneline
```

**Expected Output:**
- Templates directory should contain `web-app-template.yaml` and `README.md`
- Template should have placeholders like `TEAM_NAME`, `APP_NAME`, `ENVIRONMENT`
- Git log should show the template commit

### 🤔 Reflection Questions - Part 7

Think about application templates and advanced features:

1. **Template Placeholders**: Why use placeholders like `TEAM_NAME` and `APP_NAME` instead of actual values? How would teams customize these templates?

2. **Project Assignment**: The template assigns the application to the `dev-teams` project. Why not the `self-service` project?

3. **Namespace Creation**: Notice `CreateNamespace=false` in the template. Why is this set to false when we had it as true in the self-service application?

4. **Repository Requirements**: The template assumes applications have a `k8s/` directory. What should teams put in this directory?

5. **Automation vs Control**: We've enabled automated sync and self-heal for the application template. In what scenarios might you want to disable automation?

6. **Scaling the Platform**: How would you handle 50 teams each with 5 applications? Would creating 250 individual Application manifests be manageable? What alternatives exist?

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

If you need to start over:

```bash
# Delete created namespaces
kubectl delete namespace frontend-dev backend-dev mobile-dev

# Delete ArgoCD applications
argocd app delete self-service-namespaces

# Delete ArgoCD projects  
argocd proj delete self-service dev-teams

# Clean up local repository
rm -rf /tmp/platform-self-service
```

## Part 8: Monitoring and Observability

### Setting Up Basic Monitoring

```bash
# Create monitoring configuration for our self-service platform
mkdir -p monitoring

cat << 'EOF' > monitoring/namespace-monitoring.yaml
# This would typically be a ServiceMonitor or similar monitoring configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: namespace-monitoring-config
  namespace: argocd
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
    - job_name: 'kubernetes-namespaces'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_namespace]
        regex: (frontend|backend|mobile)-.*
        action: keep
EOF

git add monitoring/
git commit -m "Add basic monitoring configuration for self-service namespaces"
```

### ✅ Verification Steps - Part 8

Verify monitoring configuration:

```bash
# Check monitoring files
ls -la monitoring/
cat monitoring/namespace-monitoring.yaml

# Apply the monitoring config
kubectl apply -f monitoring/namespace-monitoring.yaml

# Verify the ConfigMap was created
kubectl get configmap -n argocd | grep namespace-monitoring
kubectl describe configmap namespace-monitoring-config -n argocd

# Check the git log
git log --oneline --all
```

**Expected Output:**
- Monitoring directory with `namespace-monitoring.yaml`
- ConfigMap should be created in the argocd namespace
- Git log should show all commits made during the lab

### 🤔 Reflection Questions - Part 8

Consider monitoring and observability:

1. **Monitoring Scope**: The configuration monitors namespaces matching `(frontend|backend|mobile)-.*`. How does this regex pattern work? What namespaces would it match?

2. **Observability**: Why is monitoring important for a self-service platform? What metrics would be most valuable to track?

3. **ConfigMap vs Deployment**: We created monitoring config as a ConfigMap. How would this integrate with an actual Prometheus deployment?

4. **Alerting**: What alerts would you want to set up for this self-service platform? When should the platform team be notified?

5. **Cost Tracking**: How could you use namespace labels and monitoring to track costs per team?

## Final Verification - Complete Lab Check

Before moving to LAB03, verify your complete setup:

```bash
# Check all ArgoCD projects
argocd proj list

# Verify all namespaces
kubectl get namespaces | grep -E "(frontend|backend|mobile)"

# Review all resource quotas
kubectl get resourcequota --all-namespaces

# Check all commits in your self-service repo
cd /tmp/platform-self-service
git log --oneline --graph --all

# Verify the complete directory structure
tree /tmp/platform-self-service
```

### ✅ Final Checklist

Ensure you can answer "yes" to all of these:

- [ ] I can explain what ArgoCD Projects are and how they enable multi-tenancy
- [ ] I understand the difference between ResourceQuota and LimitRange
- [ ] I know how to request a new namespace through the self-service workflow
- [ ] I can describe what happens when code is merged to the self-service repository
- [ ] I understand how automated sync, prune, and self-heal work in ArgoCD
- [ ] I can explain the RBAC roles defined in the ArgoCD projects
- [ ] I know how to verify if a namespace is within its resource quota limits
- [ ] I understand why we use Git for infrastructure as code

### 🎯 Challenge Exercises (Optional)

If you have time, try these challenges:

1. **Create a Production Namespace**: Following the pattern, create a `frontend-prod` namespace with stricter resource limits than dev
2. **Add Network Policy**: Research and add a NetworkPolicy to isolate the frontend-dev namespace
3. **Custom Quota**: Create a namespace for a "data-science" team that needs more CPU but less memory
4. **Validation Webhook**: Research how you could add validation to ensure all namespace requests follow the template correctly
5. **Cost Labels**: Add additional labels for cost center and project code to enable chargeback

## Next Steps

Congratulations! You now have:
- ✅ A self-service repository structure for team requests
- ✅ ArgoCD projects configured for multi-tenancy
- ✅ Automated namespace creation via GitOps
- ✅ Resource quotas and limits for teams
- ✅ Understanding of the self-service workflow
- ✅ Templates for common deployment patterns

You're ready for LAB03 where we'll explore deploying resources outside of Kubernetes using tools like ASO, KRO, Terranetes, or Crossplane.

### Real-World Implementation

To implement this in a real environment, you would:

1. **Create GitHub Repository**: Set up `platform-self-service` repository in your organization
2. **Configure ArgoCD**: Point ArgoCD to your GitHub repository
3. **Set up CI/CD**: Add validation and approval workflows for Pull Requests
4. **Add Security**: Implement proper RBAC and security policies
5. **Monitoring**: Set up monitoring and alerting for namespace usage
6. **Documentation**: Create team onboarding guides and runbooks

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
