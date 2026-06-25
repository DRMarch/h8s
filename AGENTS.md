# AGENTS.md — h8s Homelab

Single-owner, highly-available Kubernetes homelab on three TRIGKEY N100 nodes.
GitOps-managed via ArgoCD, Cilium Gateway API ingress, Vault + ESO for secrets.

## Technology Stack

- **Cluster**: kubeadm, kube-vip, Ubuntu Server 26.04, 3× control-plane/worker nodes
- **CNI / Ingress**: Cilium + Gateway API + HTTPRoute
- **GitOps**: ArgoCD (App-of-Apps), Helm + Kustomize
- **Secrets**: HashiCorp Vault → External Secrets Operator → Kubernetes Secrets
- **IaC / Templating**: Terraform 1.15.6 (two workspaces: `templates`, `vault-secrets`)
- **Dependencies**: Renovate (ArgoCD, Helm, Kubernetes, Dockerfile, Devbox managers)
- **Tooling**: Devbox (kubectl, terraform, helm, awscli2)

## Project Structure

- `ci-cd/argo-cd/` — ArgoCD + App-of-Apps
- `ci-cd/argo-events/` — GitHub webhook listener
- `ci-cd/renovate/` — Dependency automation
- `networking/{cilium,cert-manager,gateway,coredns,cloudflared}/` — CNI, TLS, ingress, DNS, tunnel
- `security/{authelia,vault,external-secrets}/` — SSO, secrets, secret sync
- `storage/{longhorn,cloudnative-pg,garage,harbor,dragonfly}/` — Persistence
- `monitoring/{prometheus-stack,grafana}/` — Observability
- `applications/{endurain,excalidraw,hello-world}/` — Workloads
- `terraform/{templates,vault-secrets}/` — Templating + secret generation

## Code Conventions

### Kubernetes manifests

- Prefer `Kustomization` for raw YAML; use `namespace:` in `kustomization.yaml`
- ArgoCD apps use `finalizers: [resources-finalizer.argocd.argoproj.io]`
- Sync options: `ServerSideApply=true`, `PruneLast=true`, `CreateNamespace=true`
- Helm apps use multi-source: chart repo + local values file (`$h8s/...`) + `ref: h8s`

### Secrets

- **Never** put plaintext secrets, tokens, or private keys in manifests.
- Vault is the source of truth; ESO `ExternalSecret` objects pull into K8s.
- Terraform-generated files live next to their consumers (e.g. `security/authelia/helm/resources/`).

### Naming

- ArgoCD app files: `ci-cd/argo-cd/applications/bootstrap/<name>.yaml`
- Helm values: `<component>/helm/values.yaml`
- Component resources: `<component>/resources/` with `kustomization.yaml`
- Certificates: `networking/cert-manager/resources/certificates/<app>-homelab-local.yaml`
- HTTPRoutes: `networking/gateway/resources/http-routes/<app>.yaml`

## Good vs. Bad Examples

### ✅ Good

- ArgoCD Application: `ci-cd/argo-cd/applications/bootstrap/hello-world.yaml` — uses finalizer, correct repo URL, sync options, and `CreateNamespace=true`.
- ExternalSecret: `security/authelia/helm/resources/encryption-key-externalsecret.yaml` — pulls a secret from Vault into K8s, no plaintext in Git.

### ❌ Bad

- Hardcoded `repoURL`, missing finalizer, missing sync options, or no `CreateNamespace=true`.
- Plaintext `Secret`, `ConfigMap`, or manifest values containing tokens, passwords, or private keys.
- Editing Terraform-generated files by hand instead of updating the `.tftpl` template.

## Security & Secrets

- Vault paths follow `kubernetes-homelab/<component>/<secret>` (see [terraform/README.md](./terraform/README.md)).
- `terraform/vault-secrets/secrets.auto.tfvars` is gitignored — never commit it.
- Rotate secrets in Vault, then restart consumers; do not edit generated K8s Secrets directly.
- Cluster CA lives in Vault; clients must trust `cluster-root-ca.pem` (see [SETUP.md](./SETUP.md)).

## Permissions

### Allowed without prompting

- Read any file in the repo
- Run file-scoped validation (`kustomize build`, `terraform validate`, `helm template`)
- Run `terraform plan` (read-only)
- Edit non-secret YAML in `applications/`, `networking/`, `monitoring/`, `storage/`
- Update `README.md` files

### Require approval first

- `terraform apply` in any workspace
- `kubectl apply` against the cluster
- Installing or upgrading Helm charts manually
- Rotating Vault secrets or unsealing Vault
- Deleting files, ArgoCD apps, or namespaces
- Modifying `ci-cd/argo-cd/applications/bootstrap/` (bootstrap changes)
- Git operations (`git commit`, `git push`, `git rebase`)
- Changing Renovate config or ArgoCD RBAC

## Troubleshooting

- `kubectl get applications -n argocd` — check ArgoCD app health
- `kubectl -n kube-system rollout restart deployment/cilium-operator` — Cilium gateway issues
- `kubectl exec -ti vault-0 -n vault -- vault operator unseal` — Vault rescheduled
- PVC inspection: see [DEBUGGING.md](./DEBUGGING.md)
