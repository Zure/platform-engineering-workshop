# LAB04A: Advanced Platform Concepts - User Interfaces

Welcome to LAB04A! In this lab, you'll enhance your platform by adding a developer portal using Backstage. By the end of this lab, you'll have:

- Backstage deployed as a developer portal in your Kubernetes cluster
- Backstage integrated with your Kubernetes cluster and ArgoCD
- Software templates for self-service resource requests
- A complete developer experience for requesting and managing platform resources
- Understanding of how to provide user-friendly interfaces for Internal Developer Platforms

## Prerequisites

Before starting, ensure you have completed:
- ✅ **LAB01**: Kind cluster with NGINX ingress and ArgoCD
- ✅ **LAB02**: Multi-tenant ArgoCD setup with self-service workflows
- ✅ **LAB03**: Azure Service Operator (optional, but recommended for full experience)

**Additional Requirements for this lab:**
- ✅ **Helm 3**: For deploying Backstage
- ✅ **GitHub Account**: For Backstage GitHub integration (optional but recommended)
- ✅ **8GB+ RAM**: Backstage is resource-intensive in local environments

## Overview

In this lab, we'll deploy **Backstage**, an open-source developer portal created by Spotify. Backstage provides:

- **Service Catalog**: Centralized view of all services, APIs, and resources
- **Software Templates**: Self-service scaffolding for creating new projects
- **TechDocs**: Documentation as code, integrated with your services
- **Kubernetes Plugin**: View and manage Kubernetes resources
- **ArgoCD Plugin**: Monitor GitOps deployments
- **Extensible Platform**: Plugin architecture for adding custom functionality

### What is Backstage?

Backstage is an open platform for building developer portals. It helps organizations:
- Provide a single pane of glass for developers to access all platform capabilities
- Enable self-service through software templates and golden paths
- Improve developer productivity by reducing context switching
- Standardize development practices across teams
- Maintain a service catalog that reflects your infrastructure

### Lab Flow

In this lab, we'll:
1. Understand Backstage architecture and components
2. Prepare the environment for Backstage deployment
3. Deploy Backstage using Helm with built-in storage
4. Configure Backstage with Kubernetes and ArgoCD plugins
5. Access Backstage through ingress
6. Create software templates for requesting resources
7. Test the complete self-service workflow

This lab focuses on practical implementation while understanding the value Backstage brings to platform engineering.

## Part 1: Understanding Backstage Architecture

Before we start, let's understand what we're deploying:

### Backstage Components

```
┌─────────────────────────────────────────────────────┐
│                   Backstage UI                       │
│  (React frontend - user interface for developers)   │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│              Backstage Backend                       │
│  (Node.js API - handles catalog, templates, etc.)   │
└──────────────────────┬──────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
  ┌──────────┐  ┌──────────┐  ┌──────────────┐
  │  SQLite  │  │Kubernetes│  │  GitHub API  │
  │ Storage  │  │   API    │  │   (optional) │
  └──────────┘  └──────────┘  └──────────────┘
```

### Key Concepts

- **Software Catalog**: YAML-based catalog of services, APIs, and resources
- **Software Templates**: Cookiecutter-style templates for creating new resources
- **Plugins**: Extend Backstage functionality (K8s, ArgoCD, Prometheus, etc.)
- **TechDocs**: Documentation site generator built into the platform

### ✅ Verification Steps - Part 1

Let's verify prerequisites before installation:

```bash
# Verify Helm is installed
helm version

# Verify Kind cluster is running
kubectl cluster-info

# Check available resources in cluster
kubectl top nodes || echo "Metrics server not installed (optional)"

# Verify ArgoCD is accessible
kubectl get pods -n argocd

# Check available storage classes (needed for PostgreSQL)
kubectl get storageclass
```

**Expected Output:**
- Helm version 3.x installed
- Kind cluster responding to kubectl commands
- ArgoCD pods running in argocd namespace
- At least one storage class available

### 🤔 Reflection Questions - Part 1

Before proceeding, think about:

1. **Developer Experience**: What challenges do developers face when interacting with multiple platform tools (kubectl, ArgoCD, Azure Portal, etc.)? How does a unified portal help?

2. **Self-Service**: In previous labs, teams requested resources through Pull Requests. What are the pros and cons compared to using a UI like Backstage?

3. **Golden Paths**: Backstage promotes "golden paths" - standardized, best-practice ways to accomplish common tasks. Why is standardization important in platform engineering?

4. **Catalog-Driven**: Backstage maintains a catalog of all services and resources. How does this help with discoverability and governance?

5. **Adoption**: Introducing a new tool requires developer adoption. What features would make developers want to use Backstage over existing tools?

## Part 2: Preparing for Backstage Deployment

### Create Namespace

First, let's create a dedicated namespace for Backstage:

```bash
# Create namespace for Backstage
kubectl create namespace backstage

# Verify namespace was created
kubectl get namespace backstage
```

### Understanding Backstage Storage

Backstage needs persistent storage for its catalog data. The official Backstage Helm chart includes built-in support for:
- **SQLite** (default, suitable for development/workshop environments)
- **PostgreSQL** (recommended for production, can be configured externally)

For this workshop, we'll use the default SQLite storage which is included in the Backstage Helm chart. This simplifies our setup while still demonstrating all key Backstage concepts.

### ✅ Verification Steps - Part 2

Verify the namespace is ready:

```bash
# Check namespace exists
kubectl get namespace backstage

# Verify you can create resources in the namespace
kubectl auth can-i create pods --namespace backstage
```

**Expected Output:**
- Backstage namespace showing Active status
- Permission check returning "yes"

### 🤔 Reflection Questions - Part 2

Consider the deployment choices:

1. **Storage Options**: We're using SQLite for this workshop. What are the trade-offs between SQLite and PostgreSQL for Backstage?

2. **Persistence**: Even with SQLite, Backstage will need persistent storage. How does Kubernetes handle this with PersistentVolumes?

3. **Production Considerations**: What would you change about this setup for a production environment?

4. **Scalability**: SQLite is single-file based. How does this impact Backstage's ability to scale horizontally?

5. **Backup Strategy**: How would you implement backups for Backstage data in a workshop environment vs production?

## Part 3: Deploying Backstage with Helm

### Add Backstage Helm Repository

```bash
# Add Backstage Helm repository
helm repo add backstage https://backstage.github.io/charts
helm repo update

# Search for available Backstage charts
helm search repo backstage
```

### Determine Your IP Address

Before configuring Backstage, you need to know your machine's IP address for the nip.io domain:

```bash
# On macOS/Linux - find your IP
ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1

# Or use this simpler command
hostname -I | awk '{print $1}'

# On Windows (PowerShell)
# (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike "*Loopback*"}).IPAddress

# Alternative: If you're on a local machine, you might use
ip addr show | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | cut -d/ -f1 | head -1
```

**Note your IP address** - you'll use it as `YOUR_IP` in the following commands. For example, if your IP is `192.168.1.100`, you'll use `backstage.192.168.1.100.nip.io`.

### Create Backstage Configuration

Let's create a custom values file for our Backstage deployment:

```bash
# Set your IP address (replace with your actual IP)
export YOUR_IP="192.168.1.100"  # Replace with your actual IP from the command above

# Create values file for Backstage
cat << EOF > /tmp/backstage-values.yaml
backstage:
  # Image configuration
  image:
    registry: ghcr.io
    repository: backstage/backstage
    tag: latest
    pullPolicy: Always

  # App configuration
  appConfig:
    app:
      title: Platform Engineering Workshop
      baseUrl: http://backstage.${YOUR_IP}.nip.io
    
    backend:
      baseUrl: http://backstage.${YOUR_IP}.nip.io
      listen:
        port: 7007
      cors:
        origin: http://backstage.${YOUR_IP}.nip.io
        methods: [GET, HEAD, PATCH, POST, PUT, DELETE]
        credentials: true
      database:
        client: better-sqlite3
        connection: ':memory:'
    
    catalog:
      import:
        entityFilename: catalog-info.yaml
      rules:
        - allow: [Component, System, API, Resource, Location, Group, User]
      locations:
        # Example components
        - type: url
          target: https://github.com/backstage/backstage/blob/master/packages/catalog-model/examples/all.yaml
    
    kubernetes:
      serviceLocatorMethod:
        type: 'multiTenant'
      clusterLocatorMethods:
        - type: 'config'
          clusters:
            - url: https://kubernetes.default.svc
              name: workshop-cluster
              authProvider: 'serviceAccount'
              skipTLSVerify: true
              skipMetricsLookup: false

  # Resources
  resources:
    requests:
      memory: 512Mi
      cpu: 250m
    limits:
      memory: 1Gi
      cpu: 1000m

  # Container ports
  containerPorts:
    backend: 7007

# Ingress configuration
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
  host: backstage.${YOUR_IP}.nip.io
  tls:
    enabled: false

# Service configuration
service:
  type: ClusterIP
  ports:
    backend: 7007
    name: http

# ServiceAccount - needed for Kubernetes plugin
serviceAccount:
  create: true
  automountServiceAccountToken: true
EOF
```

**Important**: Make sure to replace `YOUR_IP` with your actual IP address throughout the configuration. The examples use `192.168.1.100` - substitute your real IP.

### Install Backstage

```bash
# Install Backstage with custom values
helm install backstage backstage/backstage \
  --namespace backstage \
  --values /tmp/backstage-values.yaml \
  --wait \
  --timeout 10m

# Monitor the deployment
kubectl get pods -n backstage --watch
```

**Note**: Backstage can take several minutes to start as it builds the catalog and loads plugins. Be patient!

### Troubleshooting Installation Issues

If Backstage fails to start, check:

```bash
# Check pod status and events
kubectl get pods -n backstage
kubectl describe pod -n backstage -l app.kubernetes.io/name=backstage

# Check logs for errors
kubectl logs -n backstage -l app.kubernetes.io/name=backstage --tail=100

# Common issues:
# 1. Memory limits - Backstage needs at least 512Mi RAM
# 2. Image pull issues - check image registry and tag
# 3. Storage issues - verify PersistentVolume can be created
```
# 3. Image pull issues - check image registry and tag
```

### ✅ Verification Steps - Part 3

Verify Backstage is running:

```bash
# Check all pods in backstage namespace
kubectl get pods -n backstage

# Verify Backstage pod is ready
kubectl get pod -n backstage -l app.kubernetes.io/name=backstage

# Check service is created
kubectl get svc -n backstage -l app.kubernetes.io/name=backstage

# Verify ingress is configured
kubectl get ingress -n backstage

# Test backend API is responding
kubectl run curl-test --rm -it --restart=Never \
  --image=curlimages/curl:latest \
  --namespace backstage \
  --command -- curl -s http://backstage-backstage:7007/api/catalog/entities | head -20
```

**Expected Output:**
- Backstage pod showing 1/1 Ready
- Service exposing port 7007
- Ingress configured for backstage.YOUR_IP.nip.io (e.g., backstage.192.168.1.100.nip.io)
- API responding with JSON catalog data

### 🤔 Reflection Questions - Part 3

Think about the deployment:

1. **Resource Requirements**: Backstage requires significant resources (512Mi RAM minimum). How does this impact the design of your platform?

2. **Configuration Management**: We stored configuration in app-config.yaml. In a production environment, how would you manage secrets and environment-specific config?

3. **Plugin Architecture**: Backstage's power comes from plugins. How does the plugin system affect deployment and maintenance?

4. **Startup Time**: Backstage takes several minutes to start. What does this mean for deployment strategies and high availability?

5. **Version Management**: We used the "latest" tag. What are the implications for stability and reproducibility?

## Part 4: Accessing Backstage

### Access Through Ingress

Now let's access Backstage through our NGINX ingress:

```bash
# Verify ingress is working
kubectl get ingress -n backstage

# Get the ingress URL (replace YOUR_IP with your actual IP)
echo "Backstage URL: http://backstage.YOUR_IP.nip.io"

# Test connectivity (replace YOUR_IP with your actual IP)
curl -I http://backstage.YOUR_IP.nip.io

# Open in browser (if running on your local machine)
# Visit: http://backstage.YOUR_IP.nip.io (replace YOUR_IP with your actual IP)
```

### First-Time Setup

When you first access Backstage:

1. **Home Page**: You'll see the Backstage home page with navigation menu
2. **Catalog**: Click "Catalog" to see example components
3. **Create**: Click "Create" to see software templates
4. **Explore**: Navigate through the UI to familiarize yourself

### Configure Guest Access (Optional)

For this workshop, we'll use guest authentication:

```bash
# Backstage is already configured with guest auth by default
# All users will access as "Guest" with full permissions
# In production, you would integrate with your identity provider (OAuth, SAML, etc.)
```

### ✅ Verification Steps - Part 4

Verify you can access Backstage:

```bash
# Test the home page loads (replace YOUR_IP with your actual IP)
curl -s http://backstage.YOUR_IP.nip.io | grep -i "backstage" || echo "Backstage not responding"

# Test the API (replace YOUR_IP with your actual IP)
curl -s http://backstage.YOUR_IP.nip.io/api/catalog/entities | jq '.[] | .metadata.name' | head -5

# Check for any errors in logs
kubectl logs -n backstage -l app.kubernetes.io/name=backstage --tail=50 | grep -i error
```

**Expected Output:**
- Home page HTML containing "Backstage"
- API returning JSON with catalog entities
- No critical errors in logs

### 🤔 Reflection Questions - Part 4

Consider the user experience:

1. **Authentication**: We're using guest access. What authentication methods would you use in production, and why?

2. **Navigation**: Explore the Backstage UI. How does the navigation compare to using kubectl or the ArgoCD UI directly?

3. **Discoverability**: How does Backstage help developers discover what services and resources are available?

4. **Context Switching**: Before Backstage, developers needed to use multiple tools. How does Backstage reduce context switching?

5. **Customization**: The UI can be customized with themes and plugins. How would you decide what to show or hide for your organization?

## Part 5: Configuring Kubernetes Plugin

### Create Service Account for Backstage

Backstage needs permissions to read Kubernetes resources:

```bash
# Create ClusterRole for Backstage to read K8s resources
cat << 'EOF' > /tmp/backstage-k8s-rbac.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backstage-k8s
  namespace: backstage
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: backstage-k8s-reader
rules:
  - apiGroups:
      - '*'
    resources:
      - pods
      - configmaps
      - services
      - deployments
      - replicasets
      - horizontalpodautoscalers
      - ingresses
      - statefulsets
      - daemonsets
      - cronjobs
      - jobs
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - batch
    resources:
      - jobs
      - cronjobs
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - apps
    resources:
      - deployments
      - daemonsets
      - statefulsets
      - replicasets
    verbs:
      - get
      - list
      - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: backstage-k8s-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: backstage-k8s-reader
subjects:
  - kind: ServiceAccount
    name: backstage-k8s
    namespace: backstage
EOF

# Apply the RBAC configuration
kubectl apply -f /tmp/backstage-k8s-rbac.yaml
```

### Add Kubernetes Plugin to Catalog

Let's register some Kubernetes resources in the Backstage catalog:

```bash
# Create a catalog entry for our ArgoCD application
cat << 'EOF' > /tmp/argocd-component.yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: argocd
  description: GitOps Continuous Delivery tool
  annotations:
    backstage.io/kubernetes-id: argocd-server
    backstage.io/kubernetes-namespace: argocd
    backstage.io/kubernetes-label-selector: 'app.kubernetes.io/name=argocd-server'
spec:
  type: service
  lifecycle: production
  owner: platform-team
  system: platform-infrastructure
---
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: platform-infrastructure
  description: Core platform infrastructure services
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

# Create a ConfigMap with this catalog entry
kubectl create configmap backstage-catalog \
  -n backstage \
  --from-file=argocd-component.yaml=/tmp/argocd-component.yaml

# Update Backstage to include this catalog location
# Note: This requires restarting Backstage to pick up the changes
kubectl rollout restart deployment -n backstage -l app.kubernetes.io/name=backstage
```

### ✅ Verification Steps - Part 5

Verify Kubernetes plugin is working:

```bash
# Check RBAC is configured
kubectl get clusterrole backstage-k8s-reader
kubectl get clusterrolebinding backstage-k8s-reader

# Verify ConfigMap was created
kubectl get configmap backstage-catalog -n backstage

# Check Backstage pod restarted successfully
kubectl get pods -n backstage -l app.kubernetes.io/name=backstage

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=backstage -n backstage --timeout=300s

# Access Backstage and check catalog
# Visit: http://backstage.YOUR_IP.nip.io/catalog (replace YOUR_IP with your actual IP)
```

**Expected Output:**
- ClusterRole and ClusterRoleBinding created
- Backstage pod restarted successfully
- In Backstage UI: ArgoCD component visible in catalog with Kubernetes tab showing pods

### 🤔 Reflection Questions - Part 5

Think about the integration:

1. **RBAC Design**: We gave Backstage read-only access to many Kubernetes resources. What's the security principle behind read-only access? When might you need write access?

2. **Service Account vs User Credentials**: Why use a Kubernetes ServiceAccount instead of user credentials for Backstage?

3. **Catalog Annotations**: The catalog entry uses annotations like `backstage.io/kubernetes-id`. How do these annotations link catalog entries to real infrastructure?

4. **Multi-Cluster**: Our setup uses a single cluster. How would you configure Backstage to show resources from multiple Kubernetes clusters?

5. **Real-Time Updates**: How frequently does Backstage refresh Kubernetes data? What are the trade-offs of frequent vs infrequent updates?

## Part 6: Integrating with ArgoCD

### Install ArgoCD Plugin for Backstage

Let's add ArgoCD visibility to our Backstage instance:

```bash
# Set your IP address (replace with your actual IP)
export YOUR_IP="192.168.1.100"  # Replace with your actual IP

# First, get the ArgoCD admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Login to ArgoCD CLI (replace YOUR_IP with your actual IP)
argocd login argocd.${YOUR_IP}.nip.io --username admin --password $ARGOCD_PASSWORD --insecure

# Create API token for Backstage
ARGOCD_TOKEN=$(argocd account generate-token --account admin)

# Create secret with ArgoCD token
kubectl create secret generic argocd-credentials \
  -n backstage \
  --from-literal=token=$ARGOCD_TOKEN \
  --dry-run=client -o yaml | kubectl apply -f -

echo "ArgoCD token created for Backstage"
```

### Configure ArgoCD Integration

Update Backstage configuration to include ArgoCD:

```bash
# Set your IP address if not already set
export YOUR_IP="192.168.1.100"  # Replace with your actual IP

# Create updated values file with ArgoCD config
cat << EOF > /tmp/backstage-values-argocd.yaml
backstage:
  image:
    registry: ghcr.io
    repository: backstage/backstage
    tag: latest
    pullPolicy: Always

  extraEnvVars:
    - name: ARGOCD_AUTH_TOKEN
      valueFrom:
        secretKeyRef:
          name: argocd-credentials
          key: token

  appConfig:
    app:
      title: Platform Engineering Workshop
      baseUrl: http://backstage.${YOUR_IP}.nip.io
    
    backend:
      baseUrl: http://backstage.${YOUR_IP}.nip.io
      listen:
        port: 7007
      cors:
        origin: http://backstage.${YOUR_IP}.nip.io
        methods: [GET, HEAD, PATCH, POST, PUT, DELETE]
        credentials: true
      database:
        client: better-sqlite3
        connection: ':memory:'
    
    catalog:
      import:
        entityFilename: catalog-info.yaml
      rules:
        - allow: [Component, System, API, Resource, Location, Group, User]
      locations:
        - type: url
          target: https://github.com/backstage/backstage/blob/master/packages/catalog-model/examples/all.yaml
    
    argocd:
      username: admin
      appLocatorMethods:
        - type: 'config'
          instances:
            - name: workshop-argocd
              url: http://argocd-server.argocd.svc.cluster.local
              token: \${ARGOCD_AUTH_TOKEN}
    
    kubernetes:
      serviceLocatorMethod:
        type: 'multiTenant'
      clusterLocatorMethods:
        - type: 'config'
          clusters:
            - url: https://kubernetes.default.svc
              name: workshop-cluster
              authProvider: 'serviceAccount'
              skipTLSVerify: true
              skipMetricsLookup: false

  resources:
    requests:
      memory: 512Mi
      cpu: 250m
    limits:
      memory: 1Gi
      cpu: 1000m

  containerPorts:
    backend: 7007

ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
  host: backstage.${YOUR_IP}.nip.io
  tls:
    enabled: false

service:
  type: ClusterIP
  ports:
    backend: 7007
    name: http

serviceAccount:
  create: true
  automountServiceAccountToken: true
EOF

# Upgrade Backstage with ArgoCD configuration
helm upgrade backstage backstage/backstage \
  --namespace backstage \
  --values /tmp/backstage-values-argocd.yaml \
  --wait \
  --timeout 10m
```

### Add ArgoCD Applications to Catalog

```bash
# Create catalog entry with ArgoCD annotation
cat << 'EOF' > /tmp/guestbook-component.yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: guestbook-app
  description: Example guestbook application deployed via ArgoCD
  annotations:
    backstage.io/kubernetes-id: guestbook-ui
    backstage.io/kubernetes-namespace: default
    argocd/app-name: guestbook
spec:
  type: service
  lifecycle: experimental
  owner: platform-team
  system: demo-applications
---
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: demo-applications
  description: Demo applications for platform workshop
spec:
  owner: platform-team
EOF

# Update ConfigMap
kubectl create configmap backstage-catalog \
  -n backstage \
  --from-file=argocd-component.yaml=/tmp/argocd-component.yaml \
  --from-file=guestbook-component.yaml=/tmp/guestbook-component.yaml \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart Backstage to pick up changes
kubectl rollout restart deployment -n backstage -l app.kubernetes.io/name=backstage
```

### ✅ Verification Steps - Part 6

Verify ArgoCD integration:

```bash
# Check ArgoCD credentials secret exists
kubectl get secret argocd-credentials -n backstage

# Verify Backstage pod restarted successfully
kubectl get pods -n backstage -l app.kubernetes.io/name=backstage

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=backstage -n backstage --timeout=300s

# Check Backstage can communicate with ArgoCD
kubectl logs -n backstage -l app.kubernetes.io/name=backstage --tail=100 | grep -i argocd

# Access Backstage UI and check ArgoCD data
# Visit: http://backstage.YOUR_IP.nip.io/catalog (replace YOUR_IP with your actual IP)
# Select a component and look for ArgoCD tab
```

**Expected Output:**
- ArgoCD credentials secret created
- Backstage pod running successfully
- In Backstage UI: Components showing ArgoCD deployment status
- ArgoCD tab visible on component pages showing sync status

### 🤔 Reflection Questions - Part 6

Consider the integration:

1. **Unified View**: How does seeing ArgoCD application status in Backstage improve the developer experience compared to switching between tools?

2. **API Tokens**: We created an ArgoCD API token for Backstage. What are the security considerations? How would you rotate tokens?

3. **Real-Time Sync**: ArgoCD application status is shown in Backstage. What happens when an application is out of sync? How would a developer see this?

4. **GitOps Workflow**: With Backstage + ArgoCD integration, trace the complete workflow: Developer changes Git → ArgoCD syncs → Backstage shows status. Where could this workflow break?

5. **Multiple ArgoCD Instances**: Our setup uses one ArgoCD instance. How would you configure Backstage to show applications from multiple ArgoCD instances across different clusters?

## Part 7: Creating Software Templates

Software Templates are Backstage's way of enabling self-service. Let's create a template for requesting a namespace:

### Create Namespace Request Template

```bash
# Create a software template for namespace requests
cat << 'EOF' > /tmp/namespace-template.yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: namespace-request
  title: Request a Kubernetes Namespace
  description: Request a new Kubernetes namespace with resource quotas
  tags:
    - kubernetes
    - namespace
    - self-service
spec:
  owner: platform-team
  type: resource
  
  parameters:
    - title: Namespace Information
      required:
        - team_name
        - environment
      properties:
        team_name:
          title: Team Name
          type: string
          description: Name of your team (lowercase, no spaces)
          pattern: '^[a-z0-9-]+$'
          ui:autofocus: true
          ui:help: 'Example: frontend, backend, data-team'
        
        environment:
          title: Environment
          type: string
          description: Which environment is this namespace for?
          enum:
            - dev
            - staging
            - prod
          enumNames:
            - 'Development'
            - 'Staging'
            - 'Production'
        
        contact_email:
          title: Contact Email
          type: string
          format: email
          description: Team contact email for notifications
        
        purpose:
          title: Purpose
          type: string
          description: Brief description of what this namespace will be used for
          ui:widget: textarea
          ui:options:
            rows: 3
    
    - title: Resource Quotas
      required:
        - cpu_request
        - memory_request
      properties:
        cpu_request:
          title: CPU Request
          type: string
          description: Total CPU cores (e.g., "2" for 2 cores)
          default: "2"
          enum:
            - "1"
            - "2"
            - "4"
            - "8"
        
        memory_request:
          title: Memory Request
          type: string
          description: Total memory
          default: "4Gi"
          enum:
            - "2Gi"
            - "4Gi"
            - "8Gi"
            - "16Gi"

  steps:
    - id: log
      name: Log Parameters
      action: debug:log
      input:
        message: |
          Creating namespace: ${{ parameters.team_name }}-${{ parameters.environment }}
          Contact: ${{ parameters.contact_email }}
          Resources: CPU=${{ parameters.cpu_request }}, Memory=${{ parameters.memory_request }}
  
  output:
    text:
      - title: Namespace Details
        content: |
          ## Namespace Request Submitted
          
          Your namespace request has been created with the following details:
          
          - **Namespace Name**: `${{ parameters.team_name }}-${{ parameters.environment }}`
          - **Environment**: ${{ parameters.environment }}
          - **Contact**: ${{ parameters.contact_email }}
          - **CPU Request**: ${{ parameters.cpu_request }}
          - **Memory Request**: ${{ parameters.memory_request }}
          
          ### Next Steps
          
          In a real platform, this template would:
          1. Create a Pull Request in your GitOps repository
          2. Include the namespace YAML with your specifications
          3. Trigger ArgoCD to apply the changes once approved
          
          For this workshop, you would manually create the namespace manifest in your platform-self-service repository.
          
          ### Manual Steps (Workshop Only)
          
          ```yaml
          apiVersion: v1
          kind: Namespace
          metadata:
            name: ${{ parameters.team_name }}-${{ parameters.environment }}
            labels:
              team: ${{ parameters.team_name }}
              environment: ${{ parameters.environment }}
              managed-by: platform-team
            annotations:
              team.contact: "${{ parameters.contact_email }}"
              purpose: "${{ parameters.purpose }}"
          ---
          apiVersion: v1
          kind: ResourceQuota
          metadata:
            name: ${{ parameters.team_name }}-${{ parameters.environment }}-quota
            namespace: ${{ parameters.team_name }}-${{ parameters.environment }}
          spec:
            hard:
              requests.cpu: "${{ parameters.cpu_request }}"
              requests.memory: ${{ parameters.memory_request }}
              limits.cpu: "${{ parameters.cpu_request * 2 }}"
              limits.memory: "${{ parameters.memory_request * 2 }}"
          ```
EOF

# Create ConfigMap with the template
kubectl create configmap backstage-templates \
  -n backstage \
  --from-file=namespace-template.yaml=/tmp/namespace-template.yaml \
  --dry-run=client -o yaml | kubectl apply -f -

# Register the template in Backstage catalog
cat << 'EOF' > /tmp/template-location.yaml
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: workshop-templates
  description: Software templates for platform self-service
spec:
  type: url
  targets:
    - http://backstage-backstage.backstage.svc.cluster.local:7007/templates
EOF

kubectl create configmap backstage-locations \
  -n backstage \
  --from-file=template-location.yaml=/tmp/template-location.yaml \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Alternative: File-Based Template Registration

For this workshop, let's use a simpler approach - placing templates directly:

```bash
# Create a simple example template that doesn't require GitHub integration
cat << 'EOF' > /tmp/example-template.yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: hello-world-template
  title: Hello World Example
  description: A simple example template to test Backstage software templates
  tags:
    - example
    - getting-started
spec:
  owner: platform-team
  type: service
  
  parameters:
    - title: Basic Information
      required:
        - name
      properties:
        name:
          title: Name
          type: string
          description: Give your resource a name
          ui:autofocus: true

  steps:
    - id: log
      name: Log Information
      action: debug:log
      input:
        message: 'Hello, ${{ parameters.name }}! This is a test template.'

  output:
    text:
      - title: Success!
        content: |
          ## Template Executed Successfully
          
          Your input was: **${{ parameters.name }}**
          
          This is a demo template to show how Backstage Software Templates work.
          
          In a real scenario, this template would:
          - Create a new repository
          - Generate project files from a cookiecutter template  
          - Register the new service in the catalog
          - Set up CI/CD pipelines
          - Create associated cloud resources
EOF
```

**Note**: For fully functional templates that create resources, you would need:
- GitHub integration (Personal Access Token)
- GitHub Action to create repositories
- Integration with your GitOps repository
- Additional Backstage plugins

For this workshop, we'll demonstrate the UI and concept, with manual steps for resource creation.

### ✅ Verification Steps - Part 7

Verify templates are available:

```bash
# Check ConfigMaps were created
kubectl get configmap -n backstage | grep template

# Restart Backstage to pick up templates
kubectl rollout restart deployment -n backstage -l app.kubernetes.io/name=backstage

# Wait for restart
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=backstage -n backstage --timeout=300s

# Access Backstage and check templates
# Visit: http://backstage.YOUR_IP.nip.io/create (replace YOUR_IP with your actual IP)
# You should see your templates listed
```

**Expected Output:**
- ConfigMaps created with template definitions
- Backstage UI showing "Create" page with available templates
- Templates can be opened and show form fields

### 🤔 Reflection Questions - Part 7

Think about self-service templates:

1. **Golden Paths**: Software templates enforce "golden paths" - standardized ways to create resources. How does this help with governance and best practices?

2. **Parameter Validation**: The template includes validation rules (regex patterns, enums). Why is validation at the UI level important?

3. **Template Maintenance**: Who should own and maintain software templates? How do you ensure they stay up to date with platform changes?

4. **Discoverability**: Templates are tagged and searchable. How does good template documentation impact adoption?

5. **Abstraction Level**: Our template asks for "CPU Request" rather than detailed Kubernetes YAML. What's the right level of abstraction for your platform users?

## Part 8: Testing the Complete Workflow

### Exercise: Request a Namespace Through Backstage

Let's walk through the complete self-service workflow:

1. **Open Backstage**: Visit http://backstage.YOUR_IP.nip.io (replace YOUR_IP with your actual IP)

2. **Browse Catalog**:
   - Click "Catalog" in the left menu
   - Explore the components registered
   - Click on a component to see details, Kubernetes pods, etc.

3. **Create New Resource**:
   - Click "Create" in the left menu
   - Find "Request a Kubernetes Namespace" template (if available)
   - Or try the "Hello World Example" template
   - Fill in the form with your values
   - Submit the template

4. **View Results**:
   - Read the output showing what would be created
   - In a full implementation, this would create a PR in GitHub

### Manual Resource Creation (Following Template Output)

Since we're in a workshop environment, let's manually create the resource that the template would generate:

```bash
# Based on your template input, create the namespace
# Example: team=myteam, environment=dev
cat << 'EOF' > /tmp/myteam-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: myteam-dev
  labels:
    team: myteam
    environment: dev
    managed-by: backstage
  annotations:
    team.contact: "myteam@company.com"
    purpose: "Development environment for my team"
    created-via: backstage-template
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: myteam-dev-quota
  namespace: myteam-dev
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
---
apiVersion: v1
kind: LimitRange
metadata:
  name: myteam-dev-limits
  namespace: myteam-dev
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

# Apply the namespace
kubectl apply -f /tmp/myteam-namespace.yaml

# Verify it was created
kubectl get namespace myteam-dev
kubectl describe namespace myteam-dev
kubectl get resourcequota -n myteam-dev
```

### Register New Namespace in Backstage Catalog

```bash
# Create catalog entry for the new namespace
cat << 'EOF' > /tmp/myteam-catalog.yaml
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: myteam-dev-namespace
  description: Development namespace for MyTeam
  annotations:
    backstage.io/kubernetes-id: myteam-dev
    backstage.io/kubernetes-namespace: myteam-dev
  tags:
    - kubernetes
    - namespace
    - myteam
spec:
  type: kubernetes-namespace
  owner: myteam
  system: myteam-system
---
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: myteam-system
  description: MyTeam's applications and services
spec:
  owner: myteam
---
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: myteam
  description: My Application Team
spec:
  type: team
  children: []
EOF

# Add to catalog ConfigMap
kubectl create configmap myteam-catalog \
  -n backstage \
  --from-file=myteam-catalog.yaml=/tmp/myteam-catalog.yaml

# Note: Backstage needs to be configured to read from this ConfigMap
# For this workshop, the namespace exists and can be viewed via Kubernetes plugin
```

### ✅ Verification Steps - Part 8

Verify the complete workflow:

```bash
# Check namespace was created
kubectl get namespace myteam-dev
kubectl get all -n myteam-dev

# Verify resource quotas
kubectl get resourcequota -n myteam-dev -o yaml

# Check in Backstage
# 1. Visit http://backstage.YOUR_IP.nip.io (replace YOUR_IP with your actual IP)
# 2. Go to Catalog
# 3. Search for "myteam"
# 4. View resource details

# Test deploying something in the new namespace
kubectl run nginx --image=nginx -n myteam-dev
kubectl get pods -n myteam-dev

# Clean up test pod
kubectl delete pod nginx -n myteam-dev
```

**Expected Output:**
- Namespace exists with correct labels and annotations
- ResourceQuota and LimitRange applied
- Can deploy workloads to the namespace
- Resource limits enforced

### 🤔 Reflection Questions - Part 8

Reflect on the complete experience:

1. **User Experience**: Compare this workflow to previous labs where you manually created namespaces through Git. What are the pros and cons of each approach?

2. **Developer Empowerment**: How does a UI like Backstage enable developers who may not be familiar with Kubernetes YAML?

3. **Governance**: Even with a UI, the platform team still controls what can be created (through templates). How does this balance self-service with governance?

4. **Approval Workflows**: Our template creates resources immediately (in theory). When would you want approval steps before resource creation?

5. **Platform Evolution**: As your platform grows, what other templates would be valuable? (Hint: databases, message queues, CI/CD pipelines, monitoring dashboards)

## Part 9: Advanced Backstage Features (Optional)

If you have time, explore these additional Backstage capabilities:

### TechDocs

```bash
# TechDocs allows you to write documentation in Markdown alongside your code
# and have it automatically built and published in Backstage

# Example: Add docs to a component
# Create a docs/ folder with Markdown files
# Reference it in catalog-info.yaml:
# metadata:
#   annotations:
#     backstage.io/techdocs-ref: dir:.
```

### Search

```bash
# Backstage includes powerful search across catalog, docs, and more
# Try the search bar at the top of the UI
# Search for components, APIs, documentation, etc.
```

### API Catalog

```bash
# Register APIs to create a centralized API catalog
# Example API definition:
cat << 'EOF' > /tmp/example-api.yaml
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: platform-api
  description: Platform Engineering Workshop API
spec:
  type: openapi
  lifecycle: production
  owner: platform-team
  system: platform-infrastructure
  definition: |
    openapi: 3.0.0
    info:
      title: Platform API
      version: 1.0.0
    paths:
      /health:
        get:
          summary: Health check
          responses:
            '200':
              description: Healthy
EOF
```

### Custom Plugins

Backstage's real power is in plugins. Popular plugins include:
- **Cost Insights**: Cloud cost visibility
- **Tech Radar**: Technology adoption tracking
- **Lighthouse**: Web performance metrics
- **Prometheus**: Metrics and monitoring
- **SonarQube**: Code quality
- **PagerDuty**: Incident management
- **Jenkins/GitLab CI**: Build status

## Troubleshooting

### Common Issues and Solutions

#### Issue: Backstage Pod Won't Start

```bash
# Check pod status and events
kubectl get pods -n backstage
kubectl describe pod -n backstage -l app.kubernetes.io/name=backstage

# Common causes:
# 1. Insufficient memory - increase limits in values.yaml
# 2. Database connection issues - verify PostgreSQL is running
# 3. Invalid configuration - check app-config.yaml syntax

# Check logs for specific errors
kubectl logs -n backstage -l app.kubernetes.io/name=backstage --tail=200
```

#### Issue: Can't Access Backstage UI

```bash
# Check ingress is configured
kubectl get ingress -n backstage

# Verify NGINX ingress is working
kubectl get pods -n ingress-nginx

# Test ingress directly (replace YOUR_IP with your actual IP)
curl -v http://backstage.YOUR_IP.nip.io

# Check Backstage service
kubectl get svc -n backstage
kubectl port-forward -n backstage svc/backstage-backstage 7007:7007
# Then visit http://localhost:7007
```

#### Issue: Kubernetes Plugin Not Showing Resources

```bash
# Verify ServiceAccount has correct permissions
kubectl get clusterrole backstage-k8s-reader
kubectl describe clusterrolebinding backstage-k8s-reader

# Check catalog annotations are correct
# metadata:
#   annotations:
#     backstage.io/kubernetes-id: <deployment-name>
#     backstage.io/kubernetes-namespace: <namespace>

# Verify Backstage can reach Kubernetes API
kubectl logs -n backstage -l app.kubernetes.io/name=backstage | grep -i kubernetes
```

#### Issue: ArgoCD Plugin Not Working

```bash
# Verify ArgoCD token is valid
kubectl get secret argocd-credentials -n backstage -o yaml

# Check Backstage can reach ArgoCD API
kubectl run curl-test --rm -it --restart=Never \
  --image=curlimages/curl:latest \
  --namespace backstage \
  --command -- curl -v http://argocd-server.argocd.svc.cluster.local

# Check ArgoCD annotations in catalog
# metadata:
#   annotations:
#     argocd/app-name: <application-name>
```

#### Issue: Templates Not Appearing

```bash
# Check template YAML syntax is valid
kubectl get configmap backstage-templates -n backstage -o yaml

# Verify Backstage loaded the templates
kubectl logs -n backstage -l app.kubernetes.io/name=backstage | grep -i template

# Templates require proper apiVersion
# apiVersion: scaffolder.backstage.io/v1beta3
# kind: Template

# Restart Backstage after adding templates
kubectl rollout restart deployment -n backstage -l app.kubernetes.io/name=backstage
```

### ✅ Final Verification

Before finishing, verify everything is working:

```bash
# Check all pods are running
kubectl get pods -n backstage
kubectl get pods -n argocd

# Verify services are accessible (replace YOUR_IP with your actual IP)
curl -s http://backstage.YOUR_IP.nip.io | grep -i backstage
curl -s http://argocd.YOUR_IP.nip.io | grep -i argocd

# Check created resources
kubectl get namespaces | grep -E "(myteam|frontend|backend)"

# Verify Backstage catalog has entries (replace YOUR_IP with your actual IP)
curl -s http://backstage.YOUR_IP.nip.io/api/catalog/entities | jq '. | length'
```

**Expected State:**
- ✅ Backstage running and accessible via browser
- ✅ Kubernetes plugin showing cluster resources
- ✅ Kubernetes plugin showing cluster resources
- ✅ ArgoCD integration showing application status
- ✅ Software templates available in Create page
- ✅ Test namespace created through self-service workflow
- ✅ Catalog showing registered components and resources

### 🤔 Final Reflection Questions

Take a moment to reflect on the entire lab:

1. **Platform Value**: How does Backstage change the developer experience compared to using kubectl, ArgoCD UI, and Azure Portal separately?

2. **Adoption Strategy**: What would be your strategy to drive adoption of Backstage in your organization? What features would you emphasize?

3. **Customization vs Standard**: Backstage is highly customizable. How do you balance customization (making it perfect for your org) vs using standard features (easier upgrades)?

4. **Golden Paths**: With software templates, you can encode "golden paths" for common tasks. What templates would be most valuable for your platform?

5. **Metrics and Success**: How would you measure the success of your Backstage implementation? What metrics matter?

6. **Platform Evolution**: You now have ArgoCD for GitOps, ASO for cloud resources, and Backstage for the UI. What would you add next to your platform?

## Cleanup (Optional)

If you want to clean up Backstage from your cluster:

```bash
# Delete test namespaces
kubectl delete namespace myteam-dev --grace-period=0 --force

# Uninstall Backstage
helm uninstall backstage -n backstage

# Delete namespace
kubectl delete namespace backstage

# Delete RBAC resources
kubectl delete clusterrole backstage-k8s-reader
kubectl delete clusterrolebinding backstage-k8s-reader
```

## Next Steps

Congratulations! You now have:
- ✅ Backstage deployed as a developer portal
- ✅ Integration with Kubernetes for resource visibility
- ✅ Integration with ArgoCD for GitOps status
- ✅ Software templates for self-service resource requests
- ✅ Complete understanding of how to build user interfaces for your platform
- ✅ Hands-on experience with a production-grade developer portal

### Optional: LAB04B

Continue to **LAB04B: Advanced Platform Concepts - Abstractions** where you'll explore:
- Kubernetes Resource Orchestration (KRO)
- Creating higher-level abstractions over Azure resources
- Building "App Concepts" that hide infrastructure complexity
- Combining KRO with ASO for powerful platform capabilities

### Key Takeaways

From this lab, you should understand:

1. **Developer Portals Are Essential**: As platforms grow complex, a unified UI becomes critical for developer productivity

2. **Backstage Is a Framework**: Backstage isn't just a tool - it's a framework for building your custom developer portal

3. **Plugins Enable Integration**: The plugin architecture allows you to bring all your tools into one place

4. **Software Templates = Self-Service**: Templates turn complex infrastructure into simple forms that anyone can use

5. **Catalog-Driven Architecture**: Maintaining a catalog of services, APIs, and resources creates visibility and governance

6. **Platform as Product**: With Backstage, you're not just providing infrastructure - you're building a product for developers

## Resources and Further Learning

### Official Documentation
- [Backstage Official Documentation](https://backstage.io/docs/overview/what-is-backstage)
- [Backstage Architecture](https://backstage.io/docs/overview/architecture-overview)
- [Software Templates](https://backstage.io/docs/features/software-templates/)
- [Backstage Plugins](https://backstage.io/plugins)

### Kubernetes Integration
- [Kubernetes Plugin](https://github.com/backstage/backstage/tree/master/plugins/kubernetes)
- [ArgoCD Plugin](https://roadie.io/backstage/plugins/argo-cd/)

### Community and Examples
- [Backstage GitHub Repository](https://github.com/backstage/backstage)
- [Backstage Community Plugins](https://github.com/backstage/community-plugins)
- [Backstage Demo](https://demo.backstage.io/)

### Related Topics
- [Platform Engineering](https://platformengineering.org/)
- [Internal Developer Platforms](https://internaldeveloperplatform.org/)
- [Golden Paths](https://engineering.atspotify.com/2020/08/how-we-use-golden-paths-to-solve-fragmentation-in-our-software-ecosystem/)

### Useful Commands Reference

```bash
# Backstage Management
kubectl get pods -n backstage
kubectl logs -n backstage -l app.kubernetes.io/name=backstage --tail=100
kubectl rollout restart deployment -n backstage -l app.kubernetes.io/name=backstage
helm list -n backstage

# Backstage API Testing (replace YOUR_IP with your actual IP)
curl http://backstage.YOUR_IP.nip.io/api/catalog/entities
curl http://backstage.YOUR_IP.nip.io/api/catalog/entities?filter=kind=component

# Configuration
kubectl get configmap -n backstage
kubectl describe configmap backstage-catalog -n backstage

# Troubleshooting
kubectl describe pod -n backstage -l app.kubernetes.io/name=backstage
kubectl port-forward -n backstage svc/backstage-backstage 7007:7007
```

## Summary

In this lab, you've built a complete developer portal that:
- Provides a single interface for all platform capabilities
- Integrates with Kubernetes, ArgoCD, and other platform tools
- Enables self-service through software templates
- Creates visibility through a service catalog
- Reduces cognitive load for developers
- Enables platform teams to scale their impact

You've experienced firsthand how Backstage transforms a collection of tools and APIs into a cohesive Internal Developer Platform with a great user experience.

This is the power of platform engineering - not just providing infrastructure, but creating products that developers love to use! 🚀
