# SearXNG

[SearXNG](https://github.com/searxng/searxng) is a self-hosted, privacy-respecting metasearch engine. This instance is served at **`https://search.drmarchent.com`** and aggregates results from upstream search engines without tracking.

## Architecture

| Component | Detail |
|---|---|
| **Workload** | Plain Deployment + Service (no Helm chart) |
| **Auth** | None — open on the LAN behind Authelia (network-level) |
| **Storage** | `emptyDir` for settings; rate-limiter ConfigMap baked in |
| **Metrics** | Prometheus `ServiceMonitor` enabled |
| **Image** | `docker.io/searxng/searxng` (pinned, Renovate-managed) |

## Configuration

- `configmap.yaml`: `settings.yml` (instance name, engines, formats).
- `limiter-configmap.yaml`: bot/real-browser detection rules.
- `searxng-secret-externalsecret.yaml`: pulls the `searxng` secret key from Vault.

## Deployment

Deployed via ArgoCD. See `ci-cd/argo-cd/applications/bootstrap/searxng.yaml`.

Ordering dependencies:

1. `terraform/vault-secrets`: secret key in Vault.
2. `terraform/templates`: HTTPRoute and certificate.
3. ArgoCD syncs the application; ESO materialises the secret.
