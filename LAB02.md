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
- ✅ **GitHub Account**: You'll need a GitHub account to create repositories
  - Sign up at [https://github.com](https://github.com) if you don't have one

## Overview

In this lab, we'll simulate a platform engineering scenario where development teams can request resources (like namespaces) through a self-service mechanism. We'll use:

- **ArgoCD Projects**: For tenant isolation and access control
- **GitOps**: Teams submit requests via Pull Requests
- **Namespace-as-Code**: Kubernetes namespaces defined in YAML
- **Automation**: ArgoCD automatically applies approved changes

## Part 1: Setting Up the Self-Service Repository

### Create a GitHub Repository

First, you'll create a GitHub repository that will serve as the source of truth for self-service requests.

**Step 1: Create the repository on GitHub**

1. Navigate to [GitHub](https://github.com)
2. Click on the "+" icon in the top right corner
3. Select "New repository"
4. Repository settings:
   - **Repository name**: `platform-self-service`
   - **Description**: "Platform self-service resources for the workshop"
   - **Visibility**: Choose "Public" (easier for the workshop)
   - **Initialize**: ✅ Check "Add a README file"
5. Click "Create repository"

**Step 2: Clone and set up the repository**

```bash
# Replace YOUR_GITHUB_USERNAME with your actual GitHub username
export GITHUB_USERNAME="YOUR_GITHUB_USERNAME"

# Clone your newly created repository
git clone https://github.com/$GITHUB_USERNAME/platform-self-service.git
cd platform-self-service

# Create the directory structure for self-service resources
mkdir -p namespaces/{dev,staging,prod}
mkdir -p projects
mkdir -p applications
```

# Update the README
```bash
cat << 'EOF' > README.md
# Platform Self-Service

This repository contains self-service resources for development teams.

## Structure

- `namespaces/`: Kubernetes namespace definitions organized by environment
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

## Example: Requesting a New Namespace

```bash
# 1. Create a new branch
git checkout -b request-myteam-namespace

# 2. Create your namespace file (use existing examples as templates)
cp namespaces/dev/frontend-dev-namespace.yaml namespaces/dev/myteam-dev-namespace.yaml
# Edit the file with your team's details

# 3. Commit and push
git add namespaces/dev/myteam-dev-namespace.yaml
git commit -m "Request namespace for myteam in dev environment"
git push origin request-myteam-namespace

# 4. Create a Pull Request on GitHub
# 5. After PR is approved and merged, ArgoCD will create your namespace

EOF
```

# Create .gitignore
```bash
cat << 'EOF' > .gitignore
.DS_Store
*.tmp
*.log
kind-config.yaml
EOF
```

### Create Namespace Examples

Let's create two namespace examples that teams can use as templates:

```bash
# Create namespace for the "frontend" team
cat << 'EOF' > namespaces/dev/frontend-dev-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: devops-frontend-dev
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
  namespace: devops-frontend-dev
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
  namespace: devops-frontend-dev
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

# Create namespace for the "backend" team with different resource limits
cat << 'EOF' > namespaces/dev/backend-dev-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: devops-backend-dev
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
  namespace: devops-backend-dev
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
  namespace: devops-backend-dev
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
# Add all files
git add .

# Configure git if needed
git config user.email "your-email@example.com"
git config user.name "Your Name"

# Commit the changes
git commit -m "Initial self-service repository structure

- Add namespace examples for frontend and backend teams
- Create directory structure for different environments
- Add documentation for self-service workflow"

# Push to GitHub
git push origin main
```

### ✅ Verification - Part 1

```bash
# Verify the directory structure
tree . -L 2 2>/dev/null || find . -maxdepth 2 -not -path '*/\.git/*'

# Verify git status
git log --oneline
git remote -v

# Verify on GitHub
echo "Visit: https://github.com/$GITHUB_USERNAME/platform-self-service"
```

**Expected Output:**
- Directory structure with `namespaces/dev`, `projects`, and `applications` folders
- Two namespace files in `namespaces/dev/`
- Files visible on GitHub

## Part 2: Setting Up ArgoCD Projects for Multi-Tenancy

ArgoCD Projects provide a way to group applications and provide team-level access control. Let's create projects for our platform.

### Create ArgoCD Projects

```bash
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
  - namespace: 'devops-*'
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
git commit -m "Add ArgoCD project definitions for multi-tenancy"
git push origin main
```

### Apply ArgoCD Projects

```bash
# Apply the projects to ArgoCD
kubectl apply -f projects/self-service-project.yaml
kubectl apply -f projects/dev-teams-project.yaml

# Verify projects were created
argocd proj list
```

### ✅ Verification - Part 2

```bash
# Check projects in Kubernetes and ArgoCD
kubectl get appprojects -n argocd
argocd proj get self-service
```

**Expected Output:**
- Two projects: `self-service` and `dev-teams`
- Each project has defined source repos, destinations, and RBAC policies

## Part 3: Creating ArgoCD ApplicationSet

Now we'll create an ArgoCD ApplicationSet that automatically monitors your GitHub repository and creates applications for each environment directory.

### Create the Self-Service ApplicationSet

```bash
# Create the ApplicationSet
cat << EOF > applications/self-service-namespaces.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: self-service-namespaces
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/$GITHUB_USERNAME/platform-self-service.git
        revision: HEAD
        directories:
          - path: namespaces/*
  template:
    metadata:
      name: '{{path.basename}}-namespaces'
    spec:
      project: self-service
      source:
        repoURL: https://github.com/$GITHUB_USERNAME/platform-self-service.git
        targetRevision: HEAD
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: devops-namespaces
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
EOF

# Commit and push
git add applications/
git commit -m "Add self-service namespaces ApplicationSet

- Monitors namespaces directory for changes
- Automatically creates applications for each environment
- Automated sync with prune and self-heal enabled"
git push origin main
```

### Configure ArgoCD Repository Access

```bash
# Add your GitHub repository to ArgoCD
argocd repo add https://github.com/$GITHUB_USERNAME/platform-self-service.git

# Verify the repository was added
argocd repo list
```

### Apply the ApplicationSet

```bash
# Apply the ApplicationSet
kubectl apply -f applications/self-service-namespaces.yaml

# The ApplicationSet will automatically generate Applications
# Wait a moment, then check what was generated
sleep 5
argocd app list | grep namespaces

# Sync the generated applications
for app in $(argocd app list -o name | grep namespaces); do
  echo "Syncing $app"
  argocd app sync $app
done

# Verify the namespaces were created
kubectl get namespaces | grep -E "(frontend|backend)"
kubectl get resourcequota --all-namespaces | grep -E "(frontend|backend)"
```

### ✅ Verification - Part 3

```bash
# Check ApplicationSet status
kubectl get applicationset -n argocd
argocd app list | grep namespaces

# Verify namespaces and their resources
kubectl get namespaces | grep devops
kubectl describe namespace devops-frontend-dev
kubectl get resourcequota -n devops-frontend-dev
```

**Expected Output:**
- ApplicationSet `self-service-namespaces` exists
- Generated applications like `dev-namespaces` are visible
- Namespaces `devops-frontend-dev` and `devops-backend-dev` exist
- Each namespace has ResourceQuota and LimitRange applied

**View in ArgoCD UI:**
1. Open ArgoCD: `http://argocd.127.0.0.1.nip.io` (or your ingress URL)
2. See the `dev-namespaces` application
3. Click on it to see the resource tree
4. All resources should be "Synced" and "Healthy"

## Part 4: Testing the Self-Service Workflow

Now let's test the complete GitOps workflow by simulating **a new team (the mobile team)** requesting a namespace through a Pull Request. This demonstrates how additional development teams can onboard themselves to the platform using the same self-service workflow.

### Create a Namespace Request via Pull Request

```bash
# Create a new branch for the mobile team's request
# (Simulating a third development team joining the platform)
git checkout -b request-mobile-dev-namespace

# Create the namespace definition
cat << 'EOF' > namespaces/dev/mobile-dev-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: devops-mobile-dev
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
  namespace: devops-mobile-dev
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
  namespace: devops-mobile-dev
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

# Commit the chang
git add namespaces/dev/mobile-dev-namespace.yaml
git commit -m "Request mobile team development namespace

Requested by: mobile-team@company.com
Purpose: Mobile application development environment
Resources: 1-2 CPU cores, 2-4Gi memory"

# Push the branch to GitHub
git push origin request-mobile-dev-namespace
```

### Create and Merge Pull Request on GitHub

1. Navigate to your repository on GitHub: `https://github.com/$GITHUB_USERNAME/platform-self-service`
2. Click "Compare & pull request" for the `request-mobile-dev-namespace` branch
3. Fill in the Pull Request details:
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
     ```
4. Click "Create pull request"
5. Review the changes and click "Merge pull request"
6. Click "Confirm merge"

### Watch ArgoCD Sync the Change

```bash
# Switch back to main branch and pull
git checkout main
git pull origin main

# Watch ArgoCD detect and sync the change
argocd app list | grep namespaces

# If you don't want to wait for auto-sync (default is 3 minutes), manually trigger it
argocd app sync dev-namespaces

# Verify the namespace was created
kubectl get namespace devops-mobile-dev
kubectl describe namespace devops-mobile-dev
kubectl get resourcequota -n devops-mobile-dev
```

### ✅ Verification - Part 4

```bash
# Verify the new namespace exists
kubectl get namespaces | grep mobile
kubectl describe namespace devops-mobile-dev

# Check all team namespaces
kubectl get namespaces | grep devops

# Verify in ArgoCD
argocd app get dev-namespaces
```

**Expected Output:**
- `devops-mobile-dev` namespace exists
- Resource quota shows limits: 1-2 CPU, 2-4Gi memory
- Git log shows the merge commit from GitHub
- ArgoCD application is synced and healthy

**Verify on GitHub:**
- Pull request is merged and closed
- The file is visible in the main branch

## Part 5: Reflection and Key Takeaways

Congratulations! You've built a self-service platform with GitOps. Take a moment to reflect on what you've learned.

### Final Verification

```bash
# Check all components are working
echo "=== ArgoCD Projects ==="
argocd proj list

echo -e "\n=== ArgoCD Applications ==="
argocd app list | grep namespaces

echo -e "\n=== Kubernetes Namespaces ==="
kubectl get namespaces | grep devops

echo -e "\n=== Resource Quotas ==="
kubectl get resourcequota --all-namespaces | grep devops

echo -e "\n=== Repository ==="
git log --oneline -5
```

### 🤔 Reflection Questions

Take a few minutes to discuss or think about these questions:

#### GitOps & Workflow
1. **Pull Request Workflow**: What are the benefits of using PRs for infrastructure requests compared to direct commits or manual `kubectl` commands?

2. **Approval Process**: In a real production environment, who should review and approve namespace requests? What should they check?

3. **Audit Trail**: How does using Git for infrastructure provide better auditability? Where would you look to see who requested what and when?

4. **Rollback**: If there was a problem with a namespace, how could you use Git to roll back the change?

#### ArgoCD Concepts
5. **ApplicationSets vs Applications**: What's the advantage of using an ApplicationSet that monitors `namespaces/*` directories instead of creating individual Applications? What happens when you add a new environment directory like `prod/`?

6. **Automated Sync**: We enabled automated sync with `prune: true` and `selfHeal: true`. What does each option do? What happens if someone manually modifies a namespace label?

7. **Projects for Multi-Tenancy**: How do ArgoCD Projects help achieve multi-tenancy? What isolation do they provide?

#### Resource Management
8. **ResourceQuota vs LimitRange**: What's the difference between these two resources? When do LimitRange defaults get applied to pods?

9. **Resource Allocation**: The backend team requested more resources than the frontend team. How does this flexible quota system benefit the organization?

10. **Namespace Patterns**: We used the pattern `devops-{team}-{environment}`. Why is having a consistent naming pattern important?

### What You've Accomplished

You now have:
- ✅ A GitHub repository for self-service platform resources
- ✅ A self-service workflow using Pull Requests
- ✅ ArgoCD projects configured for multi-tenancy
- ✅ Automated namespace creation via GitOps
- ✅ Resource quotas and limits for teams
- ✅ Experience with the complete PR-based workflow
- ✅ Understanding of how Git provides auditability

### Real-World Enhancements

To take this to production, you would add:

1. **Branch Protection**: Require PR approvals before merging
2. **Validation**: GitHub Actions to validate YAML and check resource limits
3. **CODEOWNERS**: Specify who must review changes to specific directories
4. **Notifications**: Slack/Teams alerts for new PRs and resource creation
5. **Templates**: Provide templates for teams (we'll explore this in LAB04A)
6. **Policy Enforcement**: OPA Gatekeeper for advanced validation

## Troubleshooting

### Common Issues

#### ArgoCD won't sync
```bash
# Check application status
argocd app get dev-namespaces --refresh

# Check for sync errors
argocd app get dev-namespaces

# Force a sync
argocd app sync dev-namespaces --prune
```

#### Namespace not created
```bash
# Check ArgoCD application logs
kubectl logs -n argocd deployment/argocd-application-controller

# Check for events
kubectl get events --all-namespaces | grep -i error

# Verify ApplicationSet generated the app
kubectl get applicationset self-service-namespaces -n argocd -o yaml
```

#### Repository access issues
```bash
# Verify repository is accessible
argocd repo list

# Re-add repository if needed
argocd repo add https://github.com/$GITHUB_USERNAME/platform-self-service.git
```

## Cleanup (Optional)

If you want to start over or clean up:

```bash
# Delete namespaces
kubectl delete namespace devops-frontend-dev devops-backend-dev devops-mobile-dev

# Delete ApplicationSet (also removes generated applications)
kubectl delete applicationset self-service-namespaces -n argocd

# Delete ArgoCD projects
argocd proj delete self-service dev-teams

# Remove repository
argocd repo rm https://github.com/$GITHUB_USERNAME/platform-self-service.git

# Optionally delete local repository
cd .. && rm -rf platform-self-service
```

## Next Steps

You're ready for **LAB03** where we'll extend this platform to deploy Azure resources using Azure Service Operator (ASO). The same GitOps patterns and ApplicationSets you learned here will be used to manage cloud infrastructure!

## Resources

- [ArgoCD Projects Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/projects/)
- [ArgoCD ApplicationSets](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)
- [Kubernetes Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [Kubernetes Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/)
- [GitOps Principles](https://opengitops.dev/)
- [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow)
