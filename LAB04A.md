# LAB04A: Self-Service Platform UI with Simple Web Forms

Welcome to LAB04A! In this lab, you'll add a lightweight developer portal to provide a user-friendly interface for your platform. By the end of this lab, you'll have:

- A simple, reliable web-based form interface for requesting resources
- Pre-built YAML templates for namespaces and Azure resources
- Command-line tools for easy resource requests
- Integration with your platform-self-service repository from LAB02
- A complete self-service workflow where ArgoCD syncs requested resources

**Note**: This lab provides practical, workshop-friendly alternatives to complex developer portals like Backstage, focusing on simplicity and reliability for local development environments.

## Prerequisites

Before starting, ensure you have completed:
- ✅ **LAB01**: Kind cluster with NGINX ingress and ArgoCD installed
- ✅ **LAB02**: Platform-self-service repository and ArgoCD ApplicationSets
- ✅ **LAB03**: Azure Service Operator installed (for Azure resource templates)

**Additional Requirements:**
- ✅ **kubectl**: Command-line tool for Kubernetes
- ✅ **Git**: For committing and pushing resource requests
- ✅ **GitHub Account**: Your platform-self-service repository from LAB02
- ✅ **curl or web browser**: For accessing the simple web UI

## Overview

In previous labs, you created a GitOps-based self-service platform where teams request resources through Git Pull Requests. While powerful, this approach requires developers to:
- Understand Git workflows
- Write YAML manifests correctly
- Wait for PR reviews and merges

In this lab, we'll add **simple, reliable self-service tools** that:
- Provide easy-to-use interfaces instead of complex YAML editing
- Generate correct YAML from templates automatically
- Integrate with your existing GitOps workflow
- Work reliably in workshop and local development environments

### Why Not Backstage?

While Backstage is a powerful platform for production environments, it has challenges in workshop settings:
- Complex installation and configuration
- Heavy resource requirements (Node.js, databases, etc.)
- Requires extensive setup time
- Can be unreliable in local Kind clusters
- Steep learning curve for workshop timeframes

### Alternative Approaches

This lab explores three practical, workshop-friendly alternatives that capture the essence of self-service:

1. **Simple Web UI**: Lightweight HTML forms hosted in your cluster
2. **Command-Line Helper**: Bash scripts that generate YAML from prompts
3. **YAML Templates**: Pre-built templates with simple parameter substitution

All three approaches integrate seamlessly with your GitOps workflow from LAB02.

### Lab Architecture

```
Developer → Simple Web UI / CLI → YAML Templates → Git Commit → ArgoCD → Kubernetes/Azure
            (Easy interface)      (Generated)     (platform-self-service repo)  (Sync)
```

### Lab Flow

1. Set up YAML templates for common resource requests
2. Deploy a simple web UI for form-based requests (Option A)
3. Create command-line helper scripts (Option B)
4. Test the complete workflow: Request → Generate → Commit → Sync → Deployed
5. Compare approaches and choose what works best for your team

## Part 1: Setting Up YAML Templates

Instead of complex form builders, we'll create reusable YAML templates that developers can easily customize. This is lightweight, version-controlled, and requires no special infrastructure.

### Prepare Your Platform Repository

First, ensure you have your platform-self-service repository from LAB02:

```bash
# Navigate to your platform-self-service repository
cd ~/platform-self-service

# If you don't have it, clone it
# git clone https://github.com/YOUR_USERNAME/platform-self-service.git
# cd platform-self-service

# Verify you're in the right place
ls -la
# Should show your namespaces/ and azure-resources/ directories from LAB02
```

### Create Template Directory Structure

```bash
# Create a templates directory
mkdir -p templates/namespaces
mkdir -p templates/azure-storage
mkdir -p templates/helpers

# Verify structure
tree templates/ || ls -R templates/
```

### Create Namespace Request Template

Create a template that developers can easily customize:

```bash
cat << 'EOF' > templates/namespaces/namespace-template.yaml
# Kubernetes Namespace Request Template
# 
# Instructions:
# 1. Copy this file to: namespaces/{environment}/{your-team}-namespace.yaml
# 2. Replace all {{PLACEHOLDERS}} with your values
# 3. Commit and push to create a PR
# 4. After PR approval and merge, ArgoCD will create your namespace
#
# Example values:
#   TEAM_NAME: frontend, backend, data-team
#   ENVIRONMENT: dev, staging, prod
#   CONTACT_EMAIL: team@company.com
#   PURPOSE: Application deployment, testing, etc.
#   CPU_CORES: 1, 2, 4, 8
#   MEMORY_GB: 2, 4, 8, 16

---
apiVersion: v1
kind: Namespace
metadata:
  name: devops-{{TEAM_NAME}}-{{ENVIRONMENT}}
  labels:
    team: {{TEAM_NAME}}
    environment: {{ENVIRONMENT}}
    managed-by: platform-team
    created-via: self-service
  annotations:
    team.contact: "{{CONTACT_EMAIL}}"
    purpose: "{{PURPOSE}}"
    requested-date: "{{DATE}}"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: {{TEAM_NAME}}-{{ENVIRONMENT}}-quota
  namespace: devops-{{TEAM_NAME}}-{{ENVIRONMENT}}
spec:
  hard:
    requests.cpu: "{{CPU_CORES}}"
    requests.memory: "{{MEMORY_GB}}Gi"
    limits.cpu: "{{CPU_CORES * 2}}"
    limits.memory: "{{MEMORY_GB * 2}}Gi"
    persistentvolumeclaims: "5"
    services: "10"
    pods: "20"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: {{TEAM_NAME}}-{{ENVIRONMENT}}-limits
  namespace: devops-{{TEAM_NAME}}-{{ENVIRONMENT}}
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

echo "✅ Created namespace template"
```

### Create Azure Storage Template

```bash
cat << 'EOF' > templates/azure-storage/storage-template.yaml
# Azure Storage Account Request Template
#
# Instructions:
# 1. Copy this file to: azure-resources/storage-accounts/{your-storage-name}.yaml
# 2. Replace all {{PLACEHOLDERS}} with your values
# 3. Commit and push to create a PR
# 4. After PR approval and merge, ArgoCD and ASO will create your storage account
#
# Example values:
#   TEAM_NAME: frontend, backend, data-team
#   ENVIRONMENT: dev, staging, prod
#   STORAGE_NAME: myteamstorage001 (must be globally unique, 3-24 chars, lowercase alphanumeric only)
#   PURPOSE: Application data, backups, etc.
#   AZURE_REGION: swedencentral, westeurope, northeurope
#   SKU: Standard_LRS (local), Standard_GRS (geo-redundant)

---
# Resource Group for Storage
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: {{TEAM_NAME}}-{{ENVIRONMENT}}-storage-rg
  namespace: default
spec:
  location: {{AZURE_REGION}}
  tags:
    team: {{TEAM_NAME}}
    environment: {{ENVIRONMENT}}
    resource-type: storage
    managed-by: platform-team
    created-via: self-service
    requested-date: "{{DATE}}"
---
# Storage Account
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: {{STORAGE_NAME}}
  namespace: default
spec:
  location: {{AZURE_REGION}}
  kind: StorageV2
  sku:
    name: {{SKU}}
  owner:
    name: {{TEAM_NAME}}-{{ENVIRONMENT}}-storage-rg
  accessTier: Hot
  tags:
    team: {{TEAM_NAME}}
    environment: {{ENVIRONMENT}}
    purpose: "{{PURPOSE}}"
    managed-by: platform-team
    created-via: self-service
EOF

echo "✅ Created Azure storage template"
```

### Create README for Templates

```bash
cat << 'EOF' > templates/README.md
# Self-Service Platform Templates

This directory contains templates for requesting platform resources. Developers use these templates to quickly generate properly formatted resource requests.

## Available Templates

### Namespace Request (`namespaces/namespace-template.yaml`)
Request a Kubernetes namespace with resource quotas and limits.

**Required values:**
- `TEAM_NAME`: Your team name (lowercase, no spaces)
- `ENVIRONMENT`: dev, staging, or prod
- `CONTACT_EMAIL`: Team contact email
- `PURPOSE`: What the namespace will be used for
- `CPU_CORES`: Number of CPU cores (1, 2, 4, 8)
- `MEMORY_GB`: Memory in GB (2, 4, 8, 16)
- `DATE`: Request date (YYYY-MM-DD)

### Azure Storage Request (`azure-storage/storage-template.yaml`)
Request an Azure Storage Account for your team.

**Required values:**
- `TEAM_NAME`: Your team name
- `ENVIRONMENT`: dev, staging, or prod
- `STORAGE_NAME`: Globally unique storage name (3-24 chars, lowercase alphanumeric)
- `PURPOSE`: What the storage will be used for
- `AZURE_REGION`: swedencentral, westeurope, or northeurope
- `SKU`: Standard_LRS or Standard_GRS
- `DATE`: Request date (YYYY-MM-DD)

## How to Use Templates

### Manual Method
1. Copy the appropriate template file
2. Replace all `{{PLACEHOLDERS}}` with your actual values
3. Save to the correct directory
4. Commit and push to create a PR
5. Wait for PR approval and merge
6. ArgoCD will automatically sync the resources

### Using Helper Scripts (see Part 2)
Use the provided scripts to interactively generate YAML from templates.

## Directory Structure

```
platform-self-service/
├── namespaces/
│   ├── dev/
│   ├── staging/
│   └── prod/
├── azure-resources/
│   └── storage-accounts/
└── templates/
    ├── namespaces/
    ├── azure-storage/
    └── helpers/
```

## Support

For questions or issues, contact the platform team or consult LAB04A documentation.
EOF

echo "✅ Created templates README"
```

### ✅ Verification Steps - Part 1

```bash
# Verify template structure
ls -la templates/
ls -la templates/namespaces/
ls -la templates/azure-storage/

# View the templates
cat templates/namespaces/namespace-template.yaml
cat templates/azure-storage/storage-template.yaml

# Commit templates to repository
git add templates/
git commit -m "Add self-service YAML templates for namespaces and Azure storage"
git push origin main
```

**Expected Output:**
- Templates directory created with proper structure
- Namespace and storage templates contain placeholder syntax
- Templates committed to Git repository
- README explains how to use templates

## Part 2: Command-Line Helper Scripts (Option A)

The simplest self-service approach is an interactive command-line script that generates YAML from templates. This requires no infrastructure and works everywhere.

### Create the Namespace Request Script

```bash
cat << 'EOF' > templates/helpers/request-namespace.sh
#!/bin/bash
# Interactive script to request a Kubernetes namespace
# This script generates YAML from templates and can optionally commit it

set -e

echo "==================================="
echo "   Namespace Request Tool"
echo "==================================="
echo

# Prompt for values
read -p "Team Name (lowercase, no spaces): " TEAM_NAME
read -p "Environment (dev/staging/prod): " ENVIRONMENT
read -p "Contact Email: " CONTACT_EMAIL
read -p "Purpose: " PURPOSE
read -p "CPU Cores (1/2/4/8): " CPU_CORES
read -p "Memory GB (2/4/8/16): " MEMORY_GB

# Calculate limits (double the requests)
CPU_LIMIT=$((CPU_CORES * 2))
MEMORY_LIMIT=$((MEMORY_GB * 2))

# Get current date
DATE=$(date +%Y-%m-%d)

# Generate YAML
OUTPUT_DIR="../namespaces/${ENVIRONMENT}"
OUTPUT_FILE="${OUTPUT_DIR}/${TEAM_NAME}-namespace.yaml"

# Create directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

echo
echo "Generating YAML file: $OUTPUT_FILE"
echo

# Generate the YAML file
cat > "$OUTPUT_FILE" << YAML
# Kubernetes Namespace Request
# Team: ${TEAM_NAME}
# Environment: ${ENVIRONMENT}
# Requested: ${DATE}
---
apiVersion: v1
kind: Namespace
metadata:
  name: devops-${TEAM_NAME}-${ENVIRONMENT}
  labels:
    team: ${TEAM_NAME}
    environment: ${ENVIRONMENT}
    managed-by: platform-team
    created-via: self-service
  annotations:
    team.contact: "${CONTACT_EMAIL}"
    purpose: "${PURPOSE}"
    requested-date: "${DATE}"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ${TEAM_NAME}-${ENVIRONMENT}-quota
  namespace: devops-${TEAM_NAME}-${ENVIRONMENT}
spec:
  hard:
    requests.cpu: "${CPU_CORES}"
    requests.memory: "${MEMORY_GB}Gi"
    limits.cpu: "${CPU_LIMIT}"
    limits.memory: "${MEMORY_LIMIT}Gi"
    persistentvolumeclaims: "5"
    services: "10"
    pods: "20"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: ${TEAM_NAME}-${ENVIRONMENT}-limits
  namespace: devops-${TEAM_NAME}-${ENVIRONMENT}
spec:
  limits:
  - default:
      cpu: 500m
      memory: 512Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    type: Container
YAML

echo "✅ YAML file generated successfully!"
echo
echo "File location: $OUTPUT_FILE"
echo
echo "Namespace that will be created: devops-${TEAM_NAME}-${ENVIRONMENT}"
echo

# Show the file contents
cat "$OUTPUT_FILE"

echo
echo "=================================="
echo "Next Steps:"
echo "=================================="
echo "1. Review the generated YAML above"
echo "2. Commit the file to git:"
echo "   cd $(dirname $OUTPUT_DIR)"
echo "   git add $OUTPUT_FILE"
echo "   git commit -m 'Request namespace for ${TEAM_NAME} ${ENVIRONMENT}'"
echo "   git push origin main"
echo "3. Create a Pull Request on GitHub"
echo "4. After PR approval, ArgoCD will sync the namespace"
echo

read -p "Would you like to commit this file now? (y/n): " COMMIT_NOW

if [[ "$COMMIT_NOW" == "y" || "$COMMIT_NOW" == "Y" ]]; then
    cd "$(dirname $OUTPUT_DIR)"
    git add "$OUTPUT_FILE"
    git commit -m "Request namespace for ${TEAM_NAME} in ${ENVIRONMENT} environment

Requested by: ${CONTACT_EMAIL}
Purpose: ${PURPOSE}
Resources: ${CPU_CORES} CPU cores, ${MEMORY_GB}GB memory"
    
    echo
    echo "✅ Changes committed locally!"
    echo "Run 'git push origin main' to push to GitHub and create a PR"
fi

echo
echo "Done!"
EOF

# Make script executable
chmod +x templates/helpers/request-namespace.sh

echo "✅ Created namespace request script"
```

### Create the Azure Storage Request Script

```bash
cat << 'EOF' > templates/helpers/request-storage.sh
#!/bin/bash
# Interactive script to request Azure Storage Account
# This script generates YAML from templates and can optionally commit it

set -e

echo "==================================="
echo "   Azure Storage Request Tool"
echo "==================================="
echo

# Prompt for values
read -p "Team Name: " TEAM_NAME
read -p "Environment (dev/staging/prod): " ENVIRONMENT
read -p "Storage Account Name (3-24 chars, lowercase alphanumeric only): " STORAGE_NAME
read -p "Purpose: " PURPOSE
read -p "Azure Region (swedencentral/westeurope/northeurope): " AZURE_REGION
read -p "SKU (Standard_LRS/Standard_GRS): " SKU

# Validate storage name
if [[ ! "$STORAGE_NAME" =~ ^[a-z0-9]{3,24}$ ]]; then
    echo "❌ Error: Storage name must be 3-24 characters, lowercase alphanumeric only"
    exit 1
fi

# Get current date
DATE=$(date +%Y-%m-%d)

# Generate YAML
OUTPUT_DIR="../azure-resources/storage-accounts"
OUTPUT_FILE="${OUTPUT_DIR}/${STORAGE_NAME}.yaml"

# Create directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

echo
echo "Generating YAML file: $OUTPUT_FILE"
echo

# Generate the YAML file
cat > "$OUTPUT_FILE" << YAML
# Azure Storage Account Request
# Team: ${TEAM_NAME}
# Environment: ${ENVIRONMENT}
# Requested: ${DATE}
---
# Resource Group for Storage
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: ${TEAM_NAME}-${ENVIRONMENT}-storage-rg
  namespace: default
spec:
  location: ${AZURE_REGION}
  tags:
    team: ${TEAM_NAME}
    environment: ${ENVIRONMENT}
    resource-type: storage
    managed-by: platform-team
    created-via: self-service
    requested-date: "${DATE}"
---
# Storage Account
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: ${STORAGE_NAME}
  namespace: default
spec:
  location: ${AZURE_REGION}
  kind: StorageV2
  sku:
    name: ${SKU}
  owner:
    name: ${TEAM_NAME}-${ENVIRONMENT}-storage-rg
  accessTier: Hot
  tags:
    team: ${TEAM_NAME}
    environment: ${ENVIRONMENT}
    purpose: "${PURPOSE}"
    managed-by: platform-team
    created-via: self-service
YAML

echo "✅ YAML file generated successfully!"
echo
echo "File location: $OUTPUT_FILE"
echo
echo "Storage account name: ${STORAGE_NAME}"
echo "Resource group: ${TEAM_NAME}-${ENVIRONMENT}-storage-rg"
echo

# Show the file contents
cat "$OUTPUT_FILE"

echo
echo "=================================="
echo "Next Steps:"
echo "=================================="
echo "1. Review the generated YAML above"
echo "2. Commit the file to git:"
echo "   cd $(dirname $OUTPUT_DIR)"
echo "   git add $OUTPUT_FILE"
echo "   git commit -m 'Request storage account ${STORAGE_NAME}'"
echo "   git push origin main"
echo "3. Create a Pull Request on GitHub"
echo "4. After PR approval, ArgoCD and ASO will create the storage account"
echo

read -p "Would you like to commit this file now? (y/n): " COMMIT_NOW

if [[ "$COMMIT_NOW" == "y" || "$COMMIT_NOW" == "Y" ]]; then
    cd "$(dirname $OUTPUT_DIR)"
    git add "$OUTPUT_FILE"
    git commit -m "Request Azure storage account ${STORAGE_NAME}

Team: ${TEAM_NAME}
Environment: ${ENVIRONMENT}
Purpose: ${PURPOSE}
Region: ${AZURE_REGION}
SKU: ${SKU}"
    
    echo
    echo "✅ Changes committed locally!"
    echo "Run 'git push origin main' to push to GitHub and create a PR"
fi

echo
echo "Done!"
EOF

# Make script executable
chmod +x templates/helpers/request-storage.sh

echo "✅ Created storage request script"
```

### Test the Scripts

Let's test the namespace request script:

```bash
# Navigate to the helpers directory
cd templates/helpers

# Run the script interactively
./request-namespace.sh

# Example input:
# Team Name: testteam
# Environment: dev
# Contact Email: testteam@company.com
# Purpose: Testing self-service workflow
# CPU Cores: 2
# Memory GB: 4
# Commit now: n (for now, we'll review first)
```

### ✅ Verification Steps - Part 2

```bash
# Verify scripts were created
ls -la templates/helpers/
file templates/helpers/request-namespace.sh
file templates/helpers/request-storage.sh

# Check scripts are executable
[[ -x templates/helpers/request-namespace.sh ]] && echo "✅ Namespace script is executable"
[[ -x templates/helpers/request-storage.sh ]] && echo "✅ Storage script is executable"

# Commit the helper scripts
cd ~/platform-self-service
git add templates/helpers/
git commit -m "Add interactive CLI helper scripts for self-service"
git push origin main
```

**Expected Output:**
- Two executable shell scripts created
- Scripts have proper permissions
- Scripts committed to repository

## Part 3: Simple Web UI (Option B)

For teams that prefer a web interface, we can deploy a lightweight HTML form that generates YAML. This is much simpler and more reliable than Backstage.

### Create the Web UI

```bash
cat << 'EOF' > templates/helpers/self-service-ui.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Platform Self-Service Portal</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        header {
            background: #2d3748;
            color: white;
            padding: 30px;
            text-align: center;
        }
        h1 {
            font-size: 28px;
            margin-bottom: 10px;
        }
        .subtitle {
            color: #a0aec0;
            font-size: 14px;
        }
        .tabs {
            display: flex;
            background: #edf2f7;
            border-bottom: 2px solid #cbd5e0;
        }
        .tab {
            flex: 1;
            padding: 15px;
            text-align: center;
            cursor: pointer;
            background: #edf2f7;
            border: none;
            font-size: 16px;
            font-weight: 600;
            color: #4a5568;
            transition: all 0.3s;
        }
        .tab:hover {
            background: #e2e8f0;
        }
        .tab.active {
            background: white;
            color: #667eea;
            border-bottom: 3px solid #667eea;
        }
        .tab-content {
            display: none;
            padding: 30px;
        }
        .tab-content.active {
            display: block;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            font-weight: 600;
            color: #2d3748;
        }
        input, select, textarea {
            width: 100%;
            padding: 10px;
            border: 2px solid #e2e8f0;
            border-radius: 5px;
            font-size: 14px;
            transition: border-color 0.3s;
        }
        input:focus, select:focus, textarea:focus {
            outline: none;
            border-color: #667eea;
        }
        textarea {
            resize: vertical;
            min-height: 80px;
        }
        .help-text {
            font-size: 12px;
            color: #718096;
            margin-top: 5px;
        }
        button {
            background: #667eea;
            color: white;
            padding: 12px 30px;
            border: none;
            border-radius: 5px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: background 0.3s;
        }
        button:hover {
            background: #5a67d8;
        }
        .output {
            margin-top: 30px;
            padding: 20px;
            background: #f7fafc;
            border-radius: 5px;
            border: 2px solid #e2e8f0;
        }
        .output h3 {
            margin-bottom: 10px;
            color: #2d3748;
        }
        pre {
            background: #2d3748;
            color: #68d391;
            padding: 15px;
            border-radius: 5px;
            overflow-x: auto;
            font-size: 13px;
            line-height: 1.5;
        }
        .copy-btn {
            background: #48bb78;
            margin-top: 10px;
        }
        .copy-btn:hover {
            background: #38a169;
        }
        .instructions {
            background: #ebf8ff;
            border-left: 4px solid #4299e1;
            padding: 15px;
            margin-top: 15px;
            border-radius: 0 5px 5px 0;
        }
        .instructions h4 {
            color: #2c5282;
            margin-bottom: 10px;
        }
        .instructions ol {
            margin-left: 20px;
            color: #2d3748;
        }
        .instructions li {
            margin-bottom: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🚀 Platform Self-Service Portal</h1>
            <p class="subtitle">Request namespaces and Azure resources with ease</p>
        </header>

        <div class="tabs">
            <button class="tab active" onclick="showTab('namespace')">Namespace Request</button>
            <button class="tab" onclick="showTab('storage')">Azure Storage</button>
        </div>

        <!-- Namespace Tab -->
        <div id="namespace" class="tab-content active">
            <h2>Request Kubernetes Namespace</h2>
            <form onsubmit="generateNamespaceYAML(event)">
                <div class="form-group">
                    <label>Team Name *</label>
                    <input type="text" id="ns-team" required pattern="[a-z0-9-]+" placeholder="frontend">
                    <div class="help-text">Lowercase letters, numbers, and hyphens only</div>
                </div>

                <div class="form-group">
                    <label>Environment *</label>
                    <select id="ns-env" required>
                        <option value="dev">Development</option>
                        <option value="staging">Staging</option>
                        <option value="prod">Production</option>
                    </select>
                </div>

                <div class="form-group">
                    <label>Contact Email *</label>
                    <input type="email" id="ns-email" required placeholder="team@company.com">
                </div>

                <div class="form-group">
                    <label>Purpose *</label>
                    <textarea id="ns-purpose" required placeholder="What will this namespace be used for?"></textarea>
                </div>

                <div class="form-group">
                    <label>CPU Cores *</label>
                    <select id="ns-cpu" required>
                        <option value="1">1 core</option>
                        <option value="2" selected>2 cores</option>
                        <option value="4">4 cores</option>
                        <option value="8">8 cores</option>
                    </select>
                </div>

                <div class="form-group">
                    <label>Memory (GB) *</label>
                    <select id="ns-memory" required>
                        <option value="2">2 GB</option>
                        <option value="4" selected>4 GB</option>
                        <option value="8">8 GB</option>
                        <option value="16">16 GB</option>
                    </select>
                </div>

                <button type="submit">Generate YAML</button>
            </form>

            <div id="ns-output" style="display:none;" class="output">
                <h3>Generated YAML</h3>
                <pre id="ns-yaml"></pre>
                <button class="copy-btn" onclick="copyToClipboard('ns-yaml')">📋 Copy to Clipboard</button>
                
                <div class="instructions">
                    <h4>Next Steps:</h4>
                    <ol>
                        <li>Copy the YAML above</li>
                        <li>Save it to: <code>namespaces/<span id="ns-env-path"></span>/<span id="ns-team-path"></span>-namespace.yaml</code></li>
                        <li>Commit and push to your platform-self-service repository</li>
                        <li>Create a Pull Request on GitHub</li>
                        <li>After approval and merge, ArgoCD will create your namespace</li>
                    </ol>
                </div>
            </div>
        </div>

        <!-- Storage Tab -->
        <div id="storage" class="tab-content">
            <h2>Request Azure Storage Account</h2>
            <form onsubmit="generateStorageYAML(event)">
                <div class="form-group">
                    <label>Team Name *</label>
                    <input type="text" id="st-team" required pattern="[a-z0-9-]+" placeholder="frontend">
                    <div class="help-text">Lowercase letters, numbers, and hyphens only</div>
                </div>

                <div class="form-group">
                    <label>Environment *</label>
                    <select id="st-env" required>
                        <option value="dev">Development</option>
                        <option value="staging">Staging</option>
                        <option value="prod">Production</option>
                    </select>
                </div>

                <div class="form-group">
                    <label>Storage Account Name *</label>
                    <input type="text" id="st-name" required pattern="[a-z0-9]{3,24}" placeholder="myteamstorage001">
                    <div class="help-text">3-24 characters, lowercase letters and numbers only. Must be globally unique!</div>
                </div>

                <div class="form-group">
                    <label>Purpose *</label>
                    <textarea id="st-purpose" required placeholder="What will this storage be used for?"></textarea>
                </div>

                <div class="form-group">
                    <label>Azure Region *</label>
                    <select id="st-region" required>
                        <option value="swedencentral" selected>Sweden Central</option>
                        <option value="westeurope">West Europe</option>
                        <option value="northeurope">North Europe</option>
                    </select>
                </div>

                <div class="form-group">
                    <label>Redundancy Level *</label>
                    <select id="st-sku" required>
                        <option value="Standard_LRS" selected>Standard Locally Redundant (LRS)</option>
                        <option value="Standard_GRS">Standard Geo-Redundant (GRS)</option>
                    </select>
                </div>

                <button type="submit">Generate YAML</button>
            </form>

            <div id="st-output" style="display:none;" class="output">
                <h3>Generated YAML</h3>
                <pre id="st-yaml"></pre>
                <button class="copy-btn" onclick="copyToClipboard('st-yaml')">📋 Copy to Clipboard</button>
                
                <div class="instructions">
                    <h4>Next Steps:</h4>
                    <ol>
                        <li>Copy the YAML above</li>
                        <li>Save it to: <code>azure-resources/storage-accounts/<span id="st-name-path"></span>.yaml</code></li>
                        <li>Commit and push to your platform-self-service repository</li>
                        <li>Create a Pull Request on GitHub</li>
                        <li>After approval and merge, ArgoCD and ASO will create your storage account</li>
                    </ol>
                </div>
            </div>
        </div>
    </div>

    <script>
        function showTab(tabName) {
            // Hide all tabs
            document.querySelectorAll('.tab-content').forEach(tab => tab.classList.remove('active'));
            document.querySelectorAll('.tab').forEach(tab => tab.classList.remove('active'));
            
            // Show selected tab
            document.getElementById(tabName).classList.add('active');
            event.target.classList.add('active');
        }

        function generateNamespaceYAML(event) {
            event.preventDefault();
            
            const team = document.getElementById('ns-team').value;
            const env = document.getElementById('ns-env').value;
            const email = document.getElementById('ns-email').value;
            const purpose = document.getElementById('ns-purpose').value;
            const cpu = document.getElementById('ns-cpu').value;
            const memory = document.getElementById('ns-memory').value;
            const cpuLimit = cpu * 2;
            const memoryLimit = memory * 2;
            const date = new Date().toISOString().split('T')[0];
            
            const yaml = `# Kubernetes Namespace Request
# Team: ${team}
# Environment: ${env}
# Requested: ${date}
---
apiVersion: v1
kind: Namespace
metadata:
  name: devops-${team}-${env}
  labels:
    team: ${team}
    environment: ${env}
    managed-by: platform-team
    created-via: self-service
  annotations:
    team.contact: "${email}"
    purpose: "${purpose}"
    requested-date: "${date}"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ${team}-${env}-quota
  namespace: devops-${team}-${env}
spec:
  hard:
    requests.cpu: "${cpu}"
    requests.memory: "${memory}Gi"
    limits.cpu: "${cpuLimit}"
    limits.memory: "${memoryLimit}Gi"
    persistentvolumeclaims: "5"
    services: "10"
    pods: "20"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: ${team}-${env}-limits
  namespace: devops-${team}-${env}
spec:
  limits:
  - default:
      cpu: 500m
      memory: 512Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    type: Container`;
            
            document.getElementById('ns-yaml').textContent = yaml;
            document.getElementById('ns-output').style.display = 'block';
            document.getElementById('ns-env-path').textContent = env;
            document.getElementById('ns-team-path').textContent = team;
            
            // Scroll to output
            document.getElementById('ns-output').scrollIntoView({ behavior: 'smooth' });
        }

        function generateStorageYAML(event) {
            event.preventDefault();
            
            const team = document.getElementById('st-team').value;
            const env = document.getElementById('st-env').value;
            const name = document.getElementById('st-name').value;
            const purpose = document.getElementById('st-purpose').value;
            const region = document.getElementById('st-region').value;
            const sku = document.getElementById('st-sku').value;
            const date = new Date().toISOString().split('T')[0];
            
            const yaml = `# Azure Storage Account Request
# Team: ${team}
# Environment: ${env}
# Requested: ${date}
---
# Resource Group for Storage
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: ${team}-${env}-storage-rg
  namespace: default
spec:
  location: ${region}
  tags:
    team: ${team}
    environment: ${env}
    resource-type: storage
    managed-by: platform-team
    created-via: self-service
    requested-date: "${date}"
---
# Storage Account
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: ${name}
  namespace: default
spec:
  location: ${region}
  kind: StorageV2
  sku:
    name: ${sku}
  owner:
    name: ${team}-${env}-storage-rg
  accessTier: Hot
  minimumTlsVersion: TLS1_2
  supportsHttpsTrafficOnly: true
  allowBlobPublicAccess: false
  tags:
    team: ${team}
    environment: ${env}
    purpose: "${purpose}"
    managed-by: platform-team
    created-via: self-service`;
            
            document.getElementById('st-yaml').textContent = yaml;
            document.getElementById('st-output').style.display = 'block';
            document.getElementById('st-name-path').textContent = name;
            
            // Scroll to output
            document.getElementById('st-output').scrollIntoView({ behavior: 'smooth' });
        }

        function copyToClipboard(elementId) {
            const text = document.getElementById(elementId).textContent;
            navigator.clipboard.writeText(text).then(() => {
                // Show feedback
                event.target.textContent = '✅ Copied!';
                setTimeout(() => {
                    event.target.textContent = '📋 Copy to Clipboard';
                }, 2000);
            });
        }
    </script>
</body>
</html>
EOF

echo "✅ Created web UI HTML file"
```

### Deploy the Web UI to Your Cluster

```bash
# Create a ConfigMap with the HTML file
kubectl create configmap self-service-ui \
  --from-file=index.html=templates/helpers/self-service-ui.html \
  -n default

# Create a simple nginx deployment to serve the UI
cat << 'EOF' > /tmp/self-service-ui-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: self-service-ui
  namespace: default
  labels:
    app: self-service-ui
spec:
  replicas: 1
  selector:
    matchLabels:
      app: self-service-ui
  template:
    metadata:
      labels:
        app: self-service-ui
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: self-service-ui
---
apiVersion: v1
kind: Service
metadata:
  name: self-service-ui
  namespace: default
spec:
  selector:
    app: self-service-ui
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: self-service-ui
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
  - host: selfservice.127.0.0.1.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: self-service-ui
            port:
              number: 80
EOF

# Apply the deployment
kubectl apply -f /tmp/self-service-ui-deployment.yaml

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=self-service-ui -n default --timeout=60s

echo "✅ Web UI deployed successfully!"
echo
echo "Access the UI at: http://selfservice.127.0.0.1.nip.io"
```

### Test the Web UI

```bash
# Check deployment status
kubectl get pods -l app=self-service-ui -n default
kubectl get svc self-service-ui -n default
kubectl get ingress self-service-ui -n default

# Open in browser
echo "Open your browser to: http://selfservice.127.0.0.1.nip.io"
```

### ✅ Verification Steps - Part 3

```bash
# Verify web UI deployment
kubectl get deployment self-service-ui -n default
kubectl get pods -l app=self-service-ui -n default

# Check service and ingress
kubectl get svc self-service-ui -n default
kubectl get ingress self-service-ui -n default

# Test the UI is accessible
curl -I http://selfservice.127.0.0.1.nip.io

# Commit the web UI file
cd ~/platform-self-service
git add templates/helpers/self-service-ui.html
git commit -m "Add simple web UI for self-service portal"
git push origin main
```

**Expected Output:**
- Web UI HTML file created
- nginx pod running in default namespace
- Service and Ingress configured
- UI accessible at http://selfservice.127.0.0.1.nip.io
- Beautiful form interface for requesting resources

## Part 4: Testing the Self-Service Workflow

Now let's test the complete workflow using either the command-line helper or the web UI.

### Option A: Using Command-Line Helper

```bash
# Navigate to helpers directory
cd ~/platform-self-service/templates/helpers

# Request a namespace for testteam
./request-namespace.sh

# When prompted, enter:
# Team Name: testteam
# Environment: dev
# Contact Email: testteam@workshop.local
# Purpose: Testing self-service workflow with CLI helper
# CPU Cores: 2
# Memory GB: 4
# Commit now: y

# Push to GitHub
git push origin main

# Watch ArgoCD sync the namespace
kubectl get namespace --watch
# (Press Ctrl+C after you see devops-testteam-dev)

# Verify the namespace was created
kubectl get namespace devops-testteam-dev
kubectl describe namespace devops-testteam-dev
kubectl get resourcequota -n devops-testteam-dev
kubectl get limitrange -n devops-testteam-dev
```

### Option B: Using Web UI

1. **Open the Web UI**:
   ```bash
   echo "Open: http://selfservice.127.0.0.1.nip.io"
   ```

2. **Fill in the Namespace Request Form**:
   - Team Name: `webteam`
   - Environment: `dev`
   - Contact Email: `webteam@workshop.local`
   - Purpose: `Testing self-service workflow with web UI`
   - CPU Cores: `2`
   - Memory: `4 GB`

3. **Click "Generate YAML"** and review the output

4. **Copy the YAML** and save it:
   ```bash
   cd ~/platform-self-service
   mkdir -p namespaces/dev
   
   # Paste the copied YAML into a new file
   nano namespaces/dev/webteam-namespace.yaml
   # (or use your preferred editor)
   
   # Commit and push
   git add namespaces/dev/webteam-namespace.yaml
   git commit -m "Request namespace for webteam dev environment"
   git push origin main
   ```

5. **Watch ArgoCD sync**:
   ```bash
   # If you have ArgoCD ApplicationSet from LAB02, it will auto-sync
   # Otherwise, manually sync:
   argocd app sync dev-namespaces
   
   # Verify namespace creation
   kubectl get namespace devops-webteam-dev
   kubectl get resourcequota -n devops-webteam-dev
   ```

### Test Azure Storage Request

Let's test requesting Azure storage using the web UI:

1. **Open the Web UI and switch to "Azure Storage" tab**

2. **Fill in the Storage Request Form**:
   - Team Name: `testteam`
   - Environment: `dev`
   - Storage Account Name: `testteamstorage001` (must be globally unique!)
   - Purpose: `Testing Azure resource provisioning`
   - Azure Region: `swedencentral`
   - Redundancy Level: `Standard_LRS`

3. **Generate and save the YAML**:
   ```bash
   cd ~/platform-self-service
   mkdir -p azure-resources/storage-accounts
   
   # Save the generated YAML to the file
   nano azure-resources/storage-accounts/testteamstorage001.yaml
   
   # Commit and push
   git add azure-resources/storage-accounts/testteamstorage001.yaml
   git commit -m "Request Azure storage account for testteam"
   git push origin main
   ```

4. **Watch ArgoCD sync and ASO create resources**:
   ```bash
   # Sync ArgoCD application
   argocd app sync azure-storage-accounts
   
   # Watch resources being created
   kubectl get resourcegroup,storageaccount --watch
   
   # Verify storage account (this may take a few minutes)
   kubectl get storageaccount -n default
   kubectl describe storageaccount testteamstorage001
   ```

### ✅ Verification Steps - Part 4

Complete workflow verification:

```bash
# Check namespaces created
kubectl get namespace | grep devops
kubectl get namespace devops-testteam-dev -o yaml | grep -A 5 "labels:"
kubectl get namespace devops-webteam-dev -o yaml | grep -A 5 "labels:"

# Verify resource quotas
kubectl get resourcequota --all-namespaces | grep testteam
kubectl describe resourcequota -n devops-testteam-dev

# Check Azure resources (if LAB03 completed)
kubectl get resourcegroup,storageaccount --all-namespaces | grep testteam

# View Git history
cd ~/platform-self-service
git log --oneline --graph -10

# Check ArgoCD application status
argocd app list
argocd app get dev-namespaces | grep -E "(Health|Sync)"
```

**Expected Results:**
- ✅ Namespaces created with correct labels and quotas
- ✅ Resource limits applied
- ✅ Azure storage account request in queue or created
- ✅ Git history shows commits from self-service requests
- ✅ ArgoCD applications healthy and synced


## Troubleshooting

### Common Issues

#### Web UI Not Accessible

```bash
# Check pod status
kubectl get pods -l app=self-service-ui -n default
kubectl describe pod -l app=self-service-ui -n default

# Check logs
kubectl logs -l app=self-service-ui -n default

# Verify ingress
kubectl get ingress self-service-ui -n default
kubectl describe ingress self-service-ui -n default

# Test locally
kubectl port-forward -n default svc/self-service-ui 8080:80
# Then open http://localhost:8080
```

#### Script Permission Issues

```bash
# Make sure scripts are executable
chmod +x ~/platform-self-service/templates/helpers/*.sh

# Check script permissions
ls -la ~/platform-self-service/templates/helpers/

# If permission denied, check file ownership
ls -l ~/platform-self-service/templates/helpers/request-namespace.sh
```

#### YAML Generation Problems

```bash
# Validate generated YAML
cd ~/platform-self-service
kubectl apply --dry-run=client -f namespaces/dev/testteam-namespace.yaml

# Check for syntax errors
kubectl apply --dry-run=server -f namespaces/dev/testteam-namespace.yaml

# Verify placeholders were replaced
cat namespaces/dev/testteam-namespace.yaml | grep -E "{{|}}"
# Should return no results if all placeholders were replaced
```

#### ArgoCD Not Syncing After Commit

```bash
# Check ArgoCD is polling correctly
argocd app get dev-namespaces

# Manually trigger sync
argocd app sync dev-namespaces

# Force refresh from Git
argocd app get dev-namespaces --refresh

# Check repository connection
argocd repo list
```

#### Git Push Issues

```bash
# Verify Git configuration
cd ~/platform-self-service
git remote -v
git status

# Check for uncommitted changes
git diff

# If push fails, pull first
git pull origin main
git push origin main
```

## Benefits of This Approach

### What You've Built

You now have a lightweight, reliable self-service platform where:

1. **Developers use simple tools** instead of complex infrastructure
2. **YAML is generated automatically** from templates
3. **No heavy dependencies** - works reliably in local environments
4. **Multiple interfaces** - CLI for automation, Web UI for convenience
5. **Full GitOps workflow** maintained from LAB02
6. **Platform team reviews** PRs before resources are created
7. **Complete audit trail** exists in Git history

### Comparison: Simple vs Complex Portals

**Simple Approach (LAB04A Updated)**:
- ✅ Quick to set up (minutes, not hours)
- ✅ Minimal dependencies (nginx, bash, git)
- ✅ Easy to customize and extend
- ✅ Reliable in workshop/local environments
- ✅ Low resource requirements
- ✅ GitOps workflow maintained
- ⚠️ Manual PR creation step
- ⚠️ No built-in resource catalog

**Complex Portal (e.g., Backstage)**:
- ✅ Rich UI with many features
- ✅ Automatic PR creation
- ✅ Service catalog and discovery
- ✅ Plugins for extensibility
- ⚠️ Complex setup and configuration
- ⚠️ Heavy resource requirements
- ⚠️ Can be unreliable in local/Kind environments
- ⚠️ Steeper learning curve

### When to Use Each Approach

**Use Simple Approach When:**
- Workshop or training environments
- Local development on Kind/k3s
- Small teams (5-20 developers)
- Getting started with platform engineering
- Limited infrastructure resources
- Need quick wins and fast iteration

**Consider Complex Portal When:**
- Large organizations (100+ developers)
- Production environments with dedicated infrastructure
- Need advanced features (service catalog, tech radar, etc.)
- Have platform team to maintain the portal
- Integration with many external systems
- Mature platform engineering practice

### Production Considerations

To make this approach production-ready, you would:

1. **Authentication**: Add authentication to the web UI (OAuth, OIDC)
2. **RBAC**: Implement role-based access control for Git repository
3. **Validation**: Add admission controllers to validate generated YAML
4. **Automation**: Create GitHub Actions to automate PR creation from forms
5. **Approvals**: Configure branch protection and CODEOWNERS for reviews
6. **Monitoring**: Add metrics for resource requests and usage
7. **Documentation**: Create comprehensive guides for developers
8. **Templates**: Expand template library for all common resources

## Cleanup (Optional)

To remove the self-service tools:

```bash
# Delete web UI deployment
kubectl delete deployment self-service-ui -n default
kubectl delete svc self-service-ui -n default
kubectl delete ingress self-service-ui -n default
kubectl delete configmap self-service-ui -n default

# Remove test resources
kubectl delete namespace devops-testteam-dev
kubectl delete namespace devops-webteam-dev

# Remove Azure test resources (if created)
# az storage account delete --name testteamstorage001 --resource-group testteam-dev-storage-rg --yes
# az group delete --name testteam-dev-storage-rg --yes

# Keep templates in repository for future use
# They're lightweight and valuable for the platform
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
- ✅ Simple, reliable self-service tools
- ✅ YAML templates for common resources
- ✅ Command-line and web interfaces
- ✅ Practical approach for workshop environments
- ✅ Complete developer experience with GitOps

### Optional: LAB04B

If you have time, continue to **LAB04B: Advanced Platform Concepts - Abstractions** to learn about:
- Kubernetes Resource Model (KRO)
- Creating higher-level abstractions
- Hiding infrastructure complexity
- Building "App Concepts" that compose multiple resources

### Evolution Path

As your platform matures, you can evolve this approach:

1. **Phase 1** (Where you are now):
   - Simple templates and scripts
   - Manual PR creation
   - Basic GitOps workflow

2. **Phase 2** (Near future):
   - GitHub Actions to automate PR creation from web UI
   - More sophisticated templates
   - Validation webhooks

3. **Phase 3** (Mature platform):
   - Consider adopting Backstage or similar portal
   - Advanced service catalog
   - Self-service for all platform capabilities
   - Integration with monitoring, logging, etc.

### Continue Learning

**Platform Engineering**:
- [Platform Engineering website](https://platformengineering.org/)
- [Internal Developer Platform](https://internaldeveloperplatform.org/)
- [Team Topologies book](https://teamtopologies.com/)

**Tools Deep Dive**:
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Backstage Documentation](https://backstage.io/docs/) - When you're ready for it
- [Azure Service Operator](https://azure.github.io/azure-service-operator/)
- [Crossplane](https://www.crossplane.io/) - Alternative to ASO

**Self-Service Patterns**:
- [GitOps Patterns](https://www.weave.works/blog/gitops-operations-by-pull-request)
- [Platform as a Product](https://martinfowler.com/articles/talk-about-platforms.html)
- [Developer Experience](https://developerexperience.io/)

**CNCF Landscape**:
- [CNCF Cloud Native Interactive Landscape](https://landscape.cncf.io/)
- Explore tools for observability, security, networking, storage

## Summary

In this lab, you:

1. ✅ Created reusable YAML templates for common resources
2. ✅ Built interactive command-line helper scripts
3. ✅ Deployed a simple, beautiful web UI for self-service
4. ✅ Tested complete self-service workflow
5. ✅ Maintained GitOps principles with simple tools
6. ✅ Learned practical alternatives to complex developer portals

### Key Takeaways

1. **Simplicity is Powerful**: Simple tools can provide great developer experience
2. **Templates are Golden Paths**: Standardized templates reduce errors and ensure best practices
3. **GitOps Provides Safety**: All changes go through Git and PR reviews
4. **Right Tool for Context**: Choose tools appropriate for your environment and maturity
5. **Developer Experience Matters**: Even simple interfaces dramatically improve adoption
6. **Start Simple, Evolve**: Begin with simple approaches and add complexity as needed
7. **Reliability Wins**: Tools that work reliably are better than feature-rich but problematic ones

### Advantages of This Approach

1. **Workshop-Friendly**: Reliable in time-constrained workshop settings
2. **Low Resource**: Runs smoothly on local Kind clusters
3. **Fast Setup**: Minutes instead of hours
4. **Easy to Understand**: Participants can see how everything works
5. **Maintainable**: No complex dependencies to manage
6. **Extensible**: Easy to add new templates and features
7. **Production-Ready Path**: Clear evolution to more sophisticated tools

## Resources

**Template Systems**:
- [Kustomize](https://kustomize.io/) - For more advanced YAML templating
- [Helm](https://helm.sh/) - Package manager that can work with templates
- [yq](https://github.com/mikefarah/yq) - YAML processor for scripts

**GitOps Best Practices**:
- [GitOps Principles](https://opengitops.dev/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [Git Workflow Patterns](https://www.atlassian.com/git/tutorials/comparing-workflows)

**Developer Portals** (when you're ready):
- [Backstage](https://backstage.io/)
- [Port](https://www.getport.io/)
- [Humanitec](https://humanitec.com/)
- [Kratix](https://kratix.io/)

**Platform Engineering Community**:
- [Platform Engineering Slack](https://platformengineering.org/slack-rd)
- [CNCF Slack - #platform-engineering](https://slack.cncf.io/)
- [Platform Engineering Blog](https://platformengineering.org/blog)

---

**Congratulations on completing LAB04A!** 

You've built a practical, workshop-friendly self-service platform with:
- ✅ Simple, reliable tools that work everywhere
- ✅ Beautiful web interface and convenient CLI tools
- ✅ YAML templates for standardized resources
- ✅ Complete GitOps workflow maintained
- ✅ Low resource requirements for local development
- ✅ Clear path to more sophisticated solutions

This approach demonstrates that you don't always need complex tools to deliver great developer experience. Sometimes, the simplest solution is the best solution! 🚀
