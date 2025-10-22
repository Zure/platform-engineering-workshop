# platform-engineering-workshop
Workshop for Platform Engineering in a day


## Program

### 08:30 - 09:00 - Walk in

### 09:00 - 09:45 - Introduction into Platform engineering
- Setting expectations
- what is platform engineering
- GitOps
- Kubernetes
- argoCD
- backstage
- Product mindset
- Building an Internal Developer Platform

### 09:45 - 10:45 - [LAB01: Setting Up Your Environment](LAB01.md)
- k8s (kind / k3s)
- github repo
- argocd

### 10:45 - 11:00 - Coffee Break

### 11:00 - 12:00 - [LAB02: Creating a Basic Self-Service Platform](LAB02.md)
- create 2nd argo project for self service
- create namespaces through GitOps
- multi-tenant self-service workflow

### 12:00 - 13:00 - Lunch

### 13:00 - 14:00 - Exploring the CNCF landscape to help your self service
- ASO
- KRO
- Terranetes
- Crossplane

### 14:00 - 15:00 - [LAB03: Deploying Azure Resources with Azure Service Operator](LAB03.md)
- Azure Service Operator (ASO) installed in your Kubernetes cluster
- Azure credentials configured for ASO authentication
- ArgoCD applications that deploy Azure resources via GitOps
- Experience creating Azure Resource Groups and Storage Accounts
- Understanding of how to manage Azure resources through Kubernetes manifests

### 15:00 - 15:15 - Coffee Break

### 15:15 - 16:30 - [LAB04A: Advanced Platform Concepts - User Interfaces](LAB04A.md)
- Providing an interface for your Internal Developer Platform
- Deploy Backstage as a developer portal
- Integrate backstage with your platform
- Requesting resources through backstage

### 15:15 - 16:30 - [LAB04B: Advanced Platform Concepts - Abstractions](LAB04B.md)
- Abstract Azure resources away in App Concepts
- Using KRO and ASO together
- Deploy KRO in your cluster
- Create App Concepts that use ASO resources

### 16:30 - 17:00 - Wrap up / How to convince your boss / How to continue at home
- Adoption
- Q & A
