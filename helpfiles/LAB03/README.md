apply this CM patch with

```bash
kubectl patch configmap argocd-cm -n argocd --patch-file argocd-cm-patch.yaml

kubectl rollout restart deployment argocd-repo-server -n argocd
```