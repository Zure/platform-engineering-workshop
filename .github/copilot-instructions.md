# Copilot Instructions for Platform Engineering Workshop

## Repository Summary

This repository contains workshop materials for "Platform Engineering in a day" - a hands-on educational workshop focused on GitOps, Kubernetes, ArgoCD, and platform engineering concepts. The repository is **documentation-only** with no source code, build processes, or continuous integration pipelines.

## High-Level Repository Information

- **Type**: Documentation repository / Workshop materials
- **Size**: Small (5 files total)
- **Languages**: Markdown only
- **Target Technologies**: Kubernetes, ArgoCD, GitOps, Platform Engineering
- **Runtime Requirements**: Docker, kubectl, Kind, ArgoCD CLI (for workshop participants)
- **No build/test/lint processes**: This is purely documentation

## Build and Validation Instructions

### Important: No Traditional Build Process
This repository contains **only documentation files** - there are no build scripts, package managers, or CI/CD pipelines. The "validation" for this repository involves:

1. **Markdown validation**: Ensure .md files are properly formatted
2. **Link checking**: Verify external links in documentation work
3. **Command verification**: Test commands in LAB01.md work as expected

### Validation Commands
Since there are no automated build/test scripts, validation is manual:

```bash
# Check markdown syntax (if markdown linter available)
markdownlint *.md

# Validate external links (if link checker available)  
markdown-link-check *.md

# Check file structure
ls -la
find . -type f -name "*.md" | wc -l  # Should be 3 (README.md, LAB01.md, .github/copilot-instructions.md)
```

### Workshop Environment Setup (for testing lab instructions)
The LAB01.md contains commands for setting up local development environment. **Always test these commands in order** when making changes to lab instructions:

```bash
# Prerequisites check
docker --version  # Must be running
kubectl version --client  # Should be available

# Kind installation verification (varies by OS)
kind version

# Cluster creation test
kind create cluster --name test-workshop
kubectl cluster-info
kind delete cluster --name test-workshop
```

**Time Requirements**: 
- Full lab setup: 15-30 minutes
- ArgoCD installation: 5-10 minutes
- Cluster creation: 2-5 minutes

## Project Layout and Architecture

### Directory Structure
```
platform-engineering-workshop/
├── .git/                    # Git repository metadata
├── .gitignore              # Visual Studio .gitignore (oversized for this repo)
├── LICENSE                 # Apache 2.0 license
├── README.md               # Workshop overview and schedule  
└── LAB01.md               # Detailed setup instructions
```

### Key Files Description

#### README.md
- **Purpose**: Workshop schedule and program overview
- **Content**: 8-hour workshop timeline with topics and lab references
- **Key sections**: Introduction to platform engineering, GitOps, ArgoCD concepts

#### LAB01.md (Primary Content)
- **Purpose**: Hands-on setup instructions for local development environment
- **Scope**: Complete guide for Kind, Kubernetes, NGINX Ingress, ArgoCD setup
- **Platforms**: Windows, macOS, Linux installation instructions
- **Dependencies**: Docker, administrative privileges, internet connection
- **Key Commands**:
  - Kind cluster management: `kind create cluster`, `kind delete cluster`
  - Kubernetes operations: `kubectl` commands for verification
  - ArgoCD setup: Installation, login, application deployment
  - Troubleshooting: Common issues and resolution steps

#### .gitignore
- **Note**: Contains comprehensive Visual Studio ignore patterns 
- **Issue**: Oversized for documentation-only repository
- **Recommendation**: Could be simplified to basic .DS_Store, *.tmp patterns

### Architecture Elements
This repository follows a **simple linear documentation structure**:
1. **Entry point**: README.md (workshop overview)
2. **Primary content**: LAB01.md (hands-on instructions)
3. **Support files**: LICENSE, .gitignore

### Workshop Technology Stack (Target Environment)
- **Container Runtime**: Docker
- **Kubernetes Distribution**: Kind (Kubernetes in Docker)
- **Ingress Controller**: NGINX Ingress Controller  
- **GitOps Tool**: ArgoCD
- **DNS Solution**: nip.io (wildcard DNS for localhost)
- **CLI Tools**: kubectl, argocd, kind

### Validation and Quality Checks

#### Pre-commit Validation
- Ensure markdown formatting is consistent
- Verify all external links are accessible
- Test installation commands on multiple platforms when possible
- Check for broken internal references

#### Content Validation
- Commands in LAB01.md should be tested periodically for accuracy
- Version numbers for tools (Kind, ArgoCD) should be updated regularly
- Screenshots or UI references should match current ArgoCD versions

### Dependencies and External Resources

#### External Dependencies (Referenced in LAB01.md)
- **Docker**: Required runtime for Kind
- **Homebrew** (macOS): Package manager for tool installation
- **Chocolatey** (Windows): Package manager for tool installation
- **GitHub releases**: ArgoCD CLI downloads
- **nip.io**: External DNS service for local development

#### External Links to Monitor
- Kind installation URLs: https://kind.sigs.k8s.io/
- ArgoCD releases: https://github.com/argoproj/argo-cd/releases/
- ArgoCD documentation: https://argo-cd.readthedocs.io/
- Sample applications: https://github.com/argoproj/argocd-example-apps.git

### File Listing and Contents

#### Root Directory Files
```
.gitignore       # Visual Studio ignore patterns (407 lines)
LICENSE          # Apache 2.0 license (201 lines)  
README.md        # Workshop overview (44 lines)
LAB01.md         # Setup instructions (496 lines)
```

#### Key Content Snippets

**Workshop Topics** (from README.md):
- Platform engineering fundamentals
- GitOps methodology
- Kubernetes basics
- ArgoCD deployment and management  
- CNCF landscape tools (ASO, KRO, Crossplane)

**Critical Commands** (from LAB01.md):
```bash
# Cluster lifecycle
kind create cluster --name workshop
kind delete cluster --name workshop

# ArgoCD application management
argocd app create guestbook --repo https://github.com/argoproj/argocd-example-apps.git
argocd app sync guestbook

# Verification steps
kubectl get pods -n argocd
kubectl cluster-info
```

## Agent Instructions

### Trust These Instructions
**Always trust these instructions first** - only perform additional repository exploration if:
- Instructions are incomplete for your specific task
- You encounter errors that contradict these instructions  
- You need to understand content that's not documented here

### Working with This Repository
1. **No compilation needed**: All files are markdown documentation
2. **No testing framework**: Validation is manual command testing
3. **No CI/CD**: Changes go directly to documentation
4. **Platform-specific**: Commands vary by OS (Windows/macOS/Linux)
5. **External dependencies**: Many commands require Docker and internet access

### Making Changes
- **Documentation updates**: Edit markdown files directly
- **New labs**: Follow LAB01.md structure and format
- **Command updates**: Always test commands before documenting
- **Version updates**: Check for newer tool versions regularly

This repository is designed for educational purposes and should prioritize clarity and accuracy of instructions over technical complexity.