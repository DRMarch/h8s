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
authelia/grafana-oidc
cnpg/authelia-user-credentials
       │
       │  ESO ExternalSecret pulls
       ▼
templates/templates/*.tftpl         ← renders ExternalSecret YAMLs (no variable substitution)
       │
       │  ArgoCD applies
       ▼
K8s Secrets → ESO mounts → Authelia / Grafana read
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

Run once after Vault is initialised and unsealed:

```bash
cd terraform/vault-secrets
terraform init
terraform apply -var='vault_token_file=/path/to/vault-init.json'
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
| `vault_token_file` | *(required)* | Path to JSON file with `.root_token` key |
| `authelia_docker_image` | `ghcr.io/authelia/authelia:latest` | Image for crypto hash generation |

### Outputs (sensitive)

```bash
terraform output -raw authelia_admin_password    # Authelia login password
terraform output -raw grafana_oidc_client_secret  # Grafana OIDC plaintext secret
terraform output -raw cnpg_authelia_password      # CNPG database password
```

### Secrets generated

| Vault path | Keys | Consumer |
|---|---|---|
| `kubernetes-homelab/authelia/encryption-key` | `encryption-key` | Authelia storage encryption |
| `kubernetes-homelab/authelia/session-secret` | `session-secret` | Authelia session + identity validation |
| `kubernetes-homelab/authelia/hmac-secret` | `hmac-secret` | Authelia OIDC token signing |
| `kubernetes-homelab/authelia/admin-password` | `hash` (argon2) | Authelia init container |
| `kubernetes-homelab/authelia/grafana-oidc` | `client-secret-hash` (pbkdf2), `client-secret-plaintext` | Authelia (hash) + Grafana (plaintext) |
| `kubernetes-homelab/cnpg/authelia-user-credentials` | `username`, `password` | CNPG + Authelia Postgres auth |
