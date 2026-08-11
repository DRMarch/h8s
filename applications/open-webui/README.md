# Open WebUI

[Open WebUI](https://github.com/open-webui/open-webui) is a self-hosted, extensible AI chat interface. This instance is served at **`https://chat.drmarchent.com`** (LAN-only) and uses the existing **Higress LLM gateway** (OpenCode Go/Zen) as its model backend — no local Ollama.

## Architecture

| Component | Detail |
|---|---|
| **Model backend** | Higress gateway via the shared `higress-internal` Service (`http://higress-internal.higress-system.svc.cluster.local/v1`), `open-webui` API key |
| **Auth** | OIDC via Authelia, admins only (Authelia `restrict-to-admins` policy + role mapping from `admins` group) |
| **Database** | PostgreSQL via CloudNative-PG (`cnpg-openwebui`), credentials via secret-generator |
| **Workload** | Chart-default StatefulSet, 1 replica (Chroma is not multi-replica safe) |
| **Chart** | [open-webui/helm-charts](https://github.com/open-webui/helm-charts) (`https://helm.openwebui.com`) |
| **Image** | `ghcr.io/open-webui/open-webui` (pinned, Renovate-managed) |

## Deployment

Deployed via ArgoCD (wave 5, after infrastructure). See `ci-cd/argo-cd/applications/bootstrap/open-webui.yaml`.

Ordering dependencies:
1. `terraform/higress-api-keys` — generates the `open-webui` API key (Vault) and re-renders key-auth
2. `terraform/vault-secrets` — OIDC client secret + `WEBUI_SECRET_KEY`
3. `terraform/templates` — gateway listener, HTTPRoute, certificate, Authelia ESO
4. CNPG cluster `cnpg-openwebui` (syncs before the app so Postgres exists)
