# Terraform

This directory contains two **separate** Terraform workspaces with distinct lifecycles:

| Workspace | Directory | Purpose | Run |
|---|---|---|---|
| **Templates** | `templates/` | Renders K8s manifests from `.tftpl` files (ExternalSecrets, HTTPRoutes, certificates) | Every config change |
| **Secrets** | `vault-secrets/` | Generates random secrets, hashes (argon2, pbkdf2), pushes to Vault | Once at cluster bootstrap |

## Why separate?

Templates **never** contain secret values — they only reference Vault paths. Secrets provisioning **never** renders K8s manifests — it only pushes values to Vault. The contract between them is the Vault path schema.

```
vault-secrets/main.tf               ← generates random_password, hashes, vault kv put
       │
       ▼
    Vault
authelia/encryption-key
authelia/session-secret
authelia/hmac-secret
authelia/admin-password
authelia/guest-password
authelia/grafana-oidc
authelia/endurain-oidc
cnpg/authelia-user-credentials
endurain/fernet-key
endurain/secret-key
renovate/github                    (token — GitHub fine-grained PAT)
       │
       │  ESO ExternalSecret pulls
       ▼
templates/templates/*.tftpl         ← renders ExternalSecret YAMLs (no variable substitution)
       │
       │  ArgoCD applies
       ▼
K8s Secrets → ESO mounts → Authelia / Grafana / Endurain / Renovate read
```

## Templates workspace (`templates/`)

Renders ExternalSecrets, HTTPRoutes, certificates, and other K8s resources. Run whenever you change a template or variable.

```bash
cd terraform/templates
terraform init
terraform apply
```

Rendered files land in their target directories (committed to git).

### Variables

Edit [`templates/variables.tf`](./templates/variables.tf):

| Variable | Default | Description |
|---|---|---|
| `kube_vip_ip` | `192.168.1.10` | LAN fixed IP for the cluster |
| `coredns_ip` | `192.168.1.11` | LAN fixed IP for CoreDNS |
| `gateway_lan_ip` | `192.168.1.12` | LAN IP for ingress traffic |
| `kubernetes_domain` | `drmarchent.com` | Domain for ingress |
| `s3_bucket_names` | `["default"]` | Garage S3 bucket names |

## Secrets workspace (`vault-secrets/`)

Run once after Vault is initialised and unsealed.

### Quick start (recommended)

The recommended workflow is to put all bring-your-own secrets in a single
`secrets.auto.tfvars` file, which Terraform loads automatically — no `-var`
flags needed:

```bash
cd terraform/vault-secrets
cp secrets.example.tfvars secrets.auto.tfvars
$EDITOR secrets.auto.tfvars      # fill in vault_token, github_app_id, etc.

terraform init
terraform apply
```

`secrets.auto.tfvars` is gitignored — never commit real values.

### Legacy: passing variables on the CLI

You can still pass variables on the command line (backward compatible):

```bash
cd terraform/vault-secrets
terraform init
terraform apply \
  -var='vault_token_file=/path/to/vault-init.json' \
  -var='github_pat_token=github_pat_xxxxxxxxxxxxx'
```

Save the sensitive outputs:

```bash
terraform output -json > terraform.tfstate.outputs.json
```

### Variables

Edit [`vault-secrets/variables.tf`](./vault-secrets/variables.tf):

| Variable | Default | Description |
|---|---|---|
| `vault_namespace` | `vault` | K8s namespace where Vault runs |
| `vault_pod` | `vault-0` | Vault pod name |
| `vault_kv_mount` | `kubernetes-homelab` | Vault KV v2 mount path |
| `vault_token_file` | `""` | Path to JSON file with `.root_token` key (fallback if `vault_token` not set) |
| `authelia_docker_image` | `ghcr.io/authelia/authelia:latest` | Image for crypto hash generation |
| `vault_token` | `""` | Vault root token (preferred over `vault_token_file`) |
| `github_pat_token` | `""` | GitHub fine-grained PAT for Renovate |

### Outputs (sensitive)

All values that are recoverable in plaintext live as Terraform outputs. The user-facing login passwords are `authelia_admin_password` and `authelia_guest_password`; the rest are application-to-application credentials (OIDC client secrets, DB passwords, app encryption keys) you typically only need for debugging or rotation.

```bash
# Standard users (hand these out to humans)
terraform output -raw authelia_admin_password     # Admin login at https://auth.drmarchent.com
terraform output -raw authelia_guest_password     # Guest login (forward-auth only, no OIDC)

# OIDC client secrets (between Authelia and the relying party)
terraform output -raw grafana_oidc_client_secret   # Grafana -> Authelia token exchange
terraform output -raw endurain_oidc_client_secret  # Endurain -> Authelia token exchange

# Database + app secrets (rarely needed; keep safe)
terraform output -raw cnpg_authelia_password       # Postgres role `authelia`
terraform output -raw endurain_fernet_key          # Endurain Fernet key
terraform output -raw endurain_secret_key          # Endurain session secret
```

**Persisting for later:** Terraform does not retain sensitive outputs across `terraform apply` runs once the state is read. To preserve them after the initial bootstrap:

```bash
terraform output -json > terraform.tfstate.outputs.json
chmod 600 terraform.tfstate.outputs.json
```

Then retrieve later with:

```bash
terraform output -raw authelia_guest_password      # works as long as state is intact
# OR, if the state is gone but Vault still has the value:
kubectl exec -n vault vault-0 -- \
  vault kv get -format=json kubernetes-homelab/authelia/guest-password
```

> **Note:** for the `authelia/*-password` paths, Vault only stores the **argon2 hash**, not the plaintext. Once the Terraform state is lost, the plaintext is unrecoverable and the user must be reset (see "Rotation" in `security/authelia/README.md`).

### Secrets generated

| Vault path | Keys | Consumer |
|---|---|---|
| `kubernetes-homelab/authelia/encryption-key` | `encryption-key` | Authelia storage encryption |
| `kubernetes-homelab/authelia/session-secret` | `session-secret` | Authelia session + identity validation |
| `kubernetes-homelab/authelia/hmac-secret` | `hmac-secret` | Authelia OIDC token signing |
| `kubernetes-homelab/authelia/admin-password` | `hash` (argon2) | Authelia init container — `admin` user |
| `kubernetes-homelab/authelia/guest-password` | `hash` (argon2) | Authelia init container — `guest` user (restricted) |
| `kubernetes-homelab/authelia/grafana-oidc` | `client-secret-hash` (pbkdf2), `client-secret-plaintext` | Authelia (hash) + Grafana (plaintext) |
| `kubernetes-homelab/authelia/endurain-oidc` | `client-secret-hash` (pbkdf2), `client-secret-plaintext` | Authelia (hash) + Endurain (plaintext) |
| `kubernetes-homelab/cnpg/authelia-user-credentials` | `username`, `password` | CNPG + Authelia Postgres auth |
| `kubernetes-homelab/endurain/fernet-key` | `fernet_key` | Endurain Fernet crypto |
| `kubernetes-homelab/endurain/secret-key` | `secret_key` | Endurain session signing |
| `kubernetes-homelab/renovate/github` | `token` | Renovate GitHub fine-grained PAT |
