# Cilium

## Deployment

Cilium is managed via an ArgoCD Helm application (`cilium-helm.yaml`) that follows the same
multi-source pattern as the other cluster services. The chart and values are defined in the
ArgoCD Application, which adopts the existing Helm release after the initial bootstrap.

### Initial Bootstrap

Before ArgoCD exists, Cilium must be installed manually so the cluster has a working CNI:

```bash
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --version 1.20.0-pre.3 --namespace kube-system \
  -f networking/cilium/helm/values.yaml
```

Once ArgoCD is deployed, the `cilium-helm` Application (sync-wave -1000) adopts the release.
All future upgrades are done by changing `targetRevision` in `cilium-helm.yaml`.

### Cilium Resources

```bash
kubectl apply -k networking/cilium/resources
```

This deploys IP pools, L2 announcement policies, and other Cilium configuration resources.
These are also managed by the `cilium-resources` ArgoCD Application.
