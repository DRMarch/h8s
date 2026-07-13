# ByteStash

Self-hosted code snippet storage ([jordan-dalby/ByteStash](https://github.com/jordan-dalby/ByteStash)).
Served at `https://bytestash.drmarchent.com` via Cilium Gateway (LAN + Cloudflare).

## Deployment

Deployed via ArgoCD using the [official Helm chart](https://jordan-dalby.github.io/ByteStash/).
Vault secrets are provisioned by `terraform/vault-secrets/`; ExternalSecrets pull them into K8s.

## OIDC / Authelia SSO

ByteStash handles auth at the app level via OIDC to Authelia (no gateway ExternalAuth).

| Component | Path | Role |
|---|---|---|
| Authelia OIDC client | `security/authelia/helm/values.yaml` | Issues ID tokens to ByteStash |
| Vault secrets | `bytestash/jwt`, `bytestash/oidc`, `authelia/bytestash-oidc` | JWT secret + OIDC client secret |
| ESO pulls secrets | `applications/bytestash/resources/` | JWT → `bytestash-secrets`, OIDC → `bytestash-oidc` |
| Helm values | `applications/bytestash/helm/values.yaml` | App config (OIDC, PVC, replicas) |
| ArgoCD Application | `ci-cd/argo-cd/applications/bootstrap/bytestash.yaml` | Multi-source: Helm chart + local values + ESO resources |

Any authenticated Authelia user can log in. The `ADMIN_USERNAMES: "admin"` env var gates admin panel access within ByteStash.
