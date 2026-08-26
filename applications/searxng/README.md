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

## MCP server

[`mcp-searxng`](https://github.com/ihor-sokoliuk/mcp-searxng) exposes the instance's JSON search API as Model Context Protocol tools (`searxng_web_search`, `searxng_search_suggestions`, `searxng_instance_info`, `web_url_read`).

| Component | Detail |
|---|---|
| **Workload** | `mcp-deployment.yaml` (Deployment, 1 replica) + `mcp-service.yaml` (ClusterIP) |
| **Image** | `docker.io/isokoliuk/mcp-searxng` (digest-pinned, Renovate-managed) |
| **Endpoint** | Streamable HTTP on port `3000` (`MCP_HTTP_HOST=0.0.0.0`; image default binds loopback only) |
| **Upstream** | Internal ClusterIP `http://searxng.searxng.svc.cluster.local:8080` (bypasses Authelia) |
| **Auth** | None — cluster-network trust only; not exposed via Gateway |
| **Limiter** | Already exempt — the pod's CIDR (`10.0.0.0/8` default) is in the limiter `pass_ip` list |


## Deployment

Deployed via ArgoCD. See `ci-cd/argo-cd/applications/bootstrap/searxng.yaml`.

Ordering dependencies:

1. `terraform/vault-secrets`: secret key in Vault.
2. `terraform/templates`: HTTPRoute and certificate.
3. ArgoCD syncs the application; ESO materialises the secret.
