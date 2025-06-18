# LAB01: Setting Up Your Environment

Welcome to LAB01! In this lab, you'll set up your local development environment for platform engineering. By the end of this lab, you'll have:

- A local Kubernetes cluster running with Kind
- ArgoCD installed and configured
- Basic understanding of how to access these tools

## Prerequisites

Before starting, ensure you have:
- Docker installed and running on your machine
- Administrative privileges to install software
- Internet connection for downloading tools

## Part 1: Installing Kind

Kind (Kubernetes in Docker) allows you to run Kubernetes clusters locally using Docker containers as nodes.

### Windows Installation

#### Option 1: Using Chocolatey (Recommended)
```powershell
# Install Chocolatey if you haven't already
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install Kind
choco install kind
```

#### Option 2: Manual Installation
```powershell
# Download the latest release
curl.exe -Lo kind-windows-amd64.exe https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64
# Move to a location in your PATH
Move-Item .\kind-windows-amd64.exe C:\Windows\System32\kind.exe
```

### macOS Installation

#### Option 1: Using Homebrew (Recommended)
```bash
# Install Homebrew if you haven't already
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Kind
brew install kind
```

#### Option 2: Manual Installation
```bash
# For Intel Macs
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-amd64
# For Apple Silicon Macs
[ $(uname -m) = arm64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

### Linux Installation

#### Option 1: Using Package Manager
```bash
# For Ubuntu/Debian
curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep "browser_download_url.*linux-amd64" | cut -d '"' -f 4 | wget -qi -
chmod +x kind-linux-amd64
sudo mv kind-linux-amd64 /usr/local/bin/kind

# For RHEL/CentOS/Fedora
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

### Verify Kind Installation

Run the following command to verify Kind is installed correctly:

```bash
kind version
```

You should see output similar to:
```
kind v0.20.0 go1.20.4 linux/amd64
```

## Part 2: Creating a Kubernetes Cluster

Now let's create a local Kubernetes cluster using Kind.

### Create a Cluster

```bash
# Create a new cluster named "workshop"
kind create cluster --name workshop

# Verify the cluster is running
kubectl cluster-info --context kind-workshop
```

### Install kubectl (if not already installed)

#### Windows
```powershell
# Using Chocolatey
choco install kubernetes-cli

# Or download directly
curl.exe -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"
```

#### macOS
```bash
# Using Homebrew
brew install kubectl

# Or download directly
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
```

#### Linux
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
```

### Verify Cluster Access

```bash
# Check nodes
kubectl get nodes

# Check that all system pods are running
kubectl get pods -n kube-system
```

You should see one node in "Ready" state and several system pods running.

## Part 3: Installing ArgoCD

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes.

### Install ArgoCD

```bash
# Create namespace for ArgoCD
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for all pods to be ready (this may take a few minutes)
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

### Access ArgoCD UI

#### Option 1: Port Forwarding (Recommended for this workshop)
```bash
# Forward the ArgoCD server port to your local machine
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Now you can access ArgoCD at: `https://localhost:8080`

#### Option 2: Load Balancer (Alternative)
```bash
# Patch the service to use LoadBalancer type
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Get the external IP (may take a few minutes)
kubectl get svc argocd-server -n argocd
```

### Get ArgoCD Admin Password

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

### Login to ArgoCD

1. Open your browser and navigate to `https://localhost:8080`
2. Accept the self-signed certificate warning
3. Use the following credentials:
   - Username: `admin`
   - Password: (the password you retrieved from the previous step)

### Install ArgoCD CLI (Optional but Recommended)

#### Windows
```powershell
# Download the latest release
$version = (Invoke-RestMethod https://api.github.com/repos/argoproj/argo-cd/releases/latest).tag_name
$url = "https://github.com/argoproj/argo-cd/releases/download/" + $version + "/argocd-windows-amd64.exe"
$output = "$env:USERPROFILE\argocd.exe"
Invoke-WebRequest -Uri $url -OutFile $output
```

#### macOS
```bash
# Using Homebrew
brew install argocd

# Or download directly
curl -sSL -o argocd-darwin-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-darwin-amd64
sudo install -m 555 argocd-darwin-amd64 /usr/local/bin/argocd
```

#### Linux
```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
```

### Login via CLI
```bash
# Login using the CLI (use the same password from earlier)
argocd login localhost:8080 --username admin --password <your-password> --insecure
```

## Part 4: Verification

Let's verify everything is working correctly.

### Verify Kind Cluster
```bash
# Check cluster status
kind get clusters

# Verify kubectl context
kubectl config current-context

# Check cluster info
kubectl cluster-info
```

### Verify ArgoCD Installation
```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Check ArgoCD services
kubectl get svc -n argocd

# Test ArgoCD CLI
argocd version
```

## Part 5: Basic ArgoCD Configuration

Let's do a quick configuration to prepare for future labs.

### Create a Sample Application

```bash
# Create a simple application via CLI
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

# Sync the application
argocd app sync guestbook
```

### Verify the Application
```bash
# Check the application status
argocd app get guestbook

# Check the deployed resources
kubectl get all -l app.kubernetes.io/instance=guestbook
```

## Troubleshooting

### Common Issues

#### Docker Not Running
- Ensure Docker Desktop is running on Windows/macOS
- On Linux, start Docker with: `sudo systemctl start docker`

#### kubectl Not Finding Cluster
```bash
# Set the correct context
kubectl config use-context kind-workshop
```

#### ArgoCD Pods Not Starting
```bash
# Check pod logs
kubectl logs -n argocd deployment/argocd-server

# Check resource usage
kubectl top nodes
```

#### Port 8080 Already in Use
```bash
# Use a different port
kubectl port-forward svc/argocd-server -n argocd 8081:443
```

### Cleanup (Optional)

If you need to start over:

```bash
# Delete the Kind cluster
kind delete cluster --name workshop

# This will remove everything we've created
```

## Next Steps

Congratulations! You now have:
- ✅ Kind installed and a local Kubernetes cluster running
- ✅ ArgoCD installed and accessible via UI and CLI
- ✅ A sample application deployed via ArgoCD

You're ready for LAB02 where we'll explore creating basic self-service capabilities with ArgoCD projects and namespaces.

## Useful Commands for Future Reference

```bash
# Kind commands
kind create cluster --name <cluster-name>
kind delete cluster --name <cluster-name>
kind get clusters

# Kubectl commands
kubectl get nodes
kubectl get pods --all-namespaces
kubectl config get-contexts

# ArgoCD commands
argocd app list
argocd app sync <app-name>
argocd app get <app-name>
```

## Resources

- [Kind Documentation](https://kind.sigs.k8s.io/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)