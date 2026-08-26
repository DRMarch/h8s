# Argo Events

[Argo Events](https://argoproj.github.io/argo-events/) is the GitHub webhook listener for the cluster. It receives push events from the `DRMarch/h8s` repository on GitHub and dispatches them to downstream Argo Workflows / Sensors.

## How it fits in

```text
GitHub push
  -> EventSource (github webhook, /push endpoint)
  -> Sensor (filters event, triggers Workflow)
```

The GitHub App private key is stored in Vault at `kubernetes-homelab/argo-events/github-app` and materialised into the `argo-events` namespace via ESO. See [security/vault/README.md](../../security/vault/README.md#github-app) for the one-time setup.

## Resources

- `resources/h8s-github-listener.yaml` — `EventSource` for the `DRMarch/h8s` repo.
- `resources/secrets/` — per-namespace `ExternalSecret` rendering the GitHub App key.

## Deployment

Argo Events itself is installed via the `argocd-helm` bootstrap application (it shares a chart with Argo CD). The `h8s-github-listener` and any `Sensor` resources are applied with:

```bash
kubectl apply -k ci-cd/argo-events/resources
```

After the initial bootstrap, ArgoCD reconciles these resources.
