# Grimmory

Self-hosted ebook/PDF library ([grimmory-tools/grimmory](https://github.com/grimmory-tools/grimmory)). Served at `https://read.drmarchent.com`.

## Deployment

ArgoCD multi-source app: the Helm chart bundled in the app repo at `deploy/helm/grimmory`, local values from `applications/grimmory/helm/values.yaml`, and PVCs/ExternalSecrets from `applications/grimmory/resources/`. Vault secrets are provisioned by `terraform/vault-secrets/`.

Storage is plain Longhorn PVCs with the app's default `DISK_TYPE=LOCAL` (full functionality). The MariaDB holds all annotations, reading progress and OIDC config — backups are not wired yet (Longhorn snapshots + Velero offsite are the planned follow-up).

## Initial setup

1. `terraform apply` in `terraform/vault-secrets/`, then let ArgoCD sync.
2. The `grimmory-bootstrap-oidc` PostSync job provisions the admin user (Vault: `grimmory/admin-credentials`), configures, tests and enables OIDC automatically.
3. Only manual step: create the first library rooted at `/books` — **Book Per File** suits papers (organization mode is permanent per library).

Local admin backdoor: `/login?local=true` (or set `FORCE_DISABLE_OIDC=true` in the Helm values if locked out).

## Notes

- OIDC: confidential client, PKCE S256, restricted to `admins` with 2FA. Authelia has no back-channel logout, so that endpoint is unused.
- The chart has no `strategy: Recreate` knob; an image upgrade can stall if the new pod lands off the RWO node — `kubectl -n grimmory delete pod -l app.kubernetes.io/name=grimmory` unsticks it.
