# Self-Service Infrastructure Demo

This directory contains example infrastructure requests that teams can submit via GitOps.

## How to Request Infrastructure

1. Copy one of the example CloudResource files
2. Customize the variables (resource names, etc.)
3. Commit to your team's directory
4. ArgoCD will automatically sync and Terranetes will provision the infrastructure

## Examples

- `team-alpha-infra.yaml` - Example infrastructure for team-alpha
- `team-beta-infra.yaml` - Example infrastructure for team-beta

## What Gets Created

Each CloudResource using the `workshop-infra` revision will create:
- **Azure Resource Group** - For organizing Azure resources
- **GitHub Repository** - For storing code/configuration

## Monitoring

View status in ArgoCD: http://argocd.127.0.0.1.nip.io:8080

Check Terranetes resources:
```bash
kubectl get cloudresources -n <your-namespace>
kubectl describe cloudresource <name> -n <your-namespace>
```
