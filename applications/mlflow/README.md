# MLflow

[MLflow](https://mlflow.org) is an open-source platform for the machine learning lifecycle: experiment tracking, model registry, and model deployment. Served at `https://mlflow.drmarchent.com` (LAN-only) via the Cilium Gateway.

## What it does in this cluster

- **Experiment tracking** — log parameters, metrics, artifacts, and models from Python training scripts
- **Model registry** — version, stage, and annotate trained models
- **LLM tracing** — capture traces from LLM applications and agent frameworks

## Architecture

| Component | Detail |
|---|---|
| **Auth** | OIDC SSO via Authelia (`mlflow-oidc-auth` plugin) |
| **Database** | PostgreSQL via CloudNative-PG (`cnpg-mlflow` cluster) |
| **Artifacts** | S3-compatible storage via Garage (`mlflow` bucket) |
| **Charts** | [community-charts/mlflow](https://github.com/community-charts/helm-charts) (bundles the OIDC plugin) |
| **Image** | [`burakince/mlflow`](https://hub.docker.com/r/burakince/mlflow) |

### OIDC Auth Flow

1. User visits `https://mlflow.drmarchent.com` → redirected to Authelia login
2. Authelia authenticates (password/TOTP), returns ID token with group claims
3. Plugin provisions the user, maps `admins` → admin, `app-users` → default permissions
4. Session cookie set; subsequent requests validated against the session

## Deployment

Deployed via ArgoCD (wave `5`, after all infrastructure). See `ci-cd/argo-cd/applications/bootstrap/mlflow.yaml`.

## Source Files

| File | Role |
|---|---|
| `ci-cd/argo-cd/applications/bootstrap/mlflow.yaml` | ArgoCD Application |
| `applications/mlflow/helm/values.yaml` | Helm values (DB, S3, OIDC) |
| `applications/mlflow/resources/kustomization.yaml` | K8s resources bundle |
| `applications/mlflow/resources/mlflow-oidc-externalsecret.yaml` | ESO: OIDC client secret + session key |
| `applications/mlflow/resources/garage-key.yaml` | Garage S3 access key |
| `storage/cloudnative-pg/.../clusters/mlflow/` | CNPG cluster + database |
| `storage/garage/resources/buckets/mlflow/` | Garage S3 bucket |
| `security/authelia/helm/resources/mlflow-client-secret-externalsecret.yaml` | ESO: Authelia OIDC client hash |
| `security/authelia/helm/values.yaml` | Authelia OIDC client definition |
| `terraform/vault-secrets/main.tf` | Vault secrets (OIDC client secret + session key) |
| `networking/cert-manager/.../mlflow-homelab-local.yaml` | TLS certificate |
| `networking/gateway/.../lan.yaml` | Gateway listener (LAN-only) |
| `networking/gateway/.../http-routes/mlflow.yaml` | HTTPRoute |

## Client Usage

```python
import mlflow

mlflow.set_tracking_uri("https://mlflow.drmarchent.com")

# Authenticate via OIDC (first login opens browser)
# Or use Basic Auth with a pre-created user/password

with mlflow.start_run():
    mlflow.log_param("learning_rate", 0.01)
    mlflow.log_metric("accuracy", 0.95)
    mlflow.log_artifact("model.pkl")
```

## Permissions

Admin users (Authelia group `admins`) get full MANAGE access automatically. Regular users (`app-users`) get the configured `defaultPermission`. Fine-grained permissions are managed through the plugin's `/permissions` UI.

Group names in the Helm values match the existing Authelia groups — no new groups were created for this deployment.
