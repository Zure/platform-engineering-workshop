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

# Initialize git repository
git init

# Create the basic structure
mkdir -p {namespaces,projects,applications}
mkdir -p namespaces/{dev,staging,prod}

# Create README
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

EOF

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
```
EOF

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