# Higress API Keys

Generates the API keys used by the Higress [`key-auth`](https://higress.ai/en/docs/latest/user/plugins/authentication/key-auth/) plugin and renders the relevant K8s manifests and pushes the keys to the vault.


## Quick start

```bash
cd terraform/higress-api-keys
cp secrets.example.tfvars secrets.auto.tfvars
$EDITOR secrets.auto.tfvars

terraform init
terraform apply
```

## Getting an API key

To get and API key for a consumer run:

```bash
CONSUMER="<CONSUMER_NAME>"
terraform output -json api_keys | jq -r --arg name "$CONSUMER" '.[$name]'
```

## Adding/Removing consumer api_keys

Consumers are split into two scopes, each mapped to its own domain in the key-auth
WasmPlugin — a key issued for one scope does **not** work on the other:

| Variable | Domain (fixed) | Purpose |
|---|---|---|
| `higress_external_api_consumers` | `llm.drmarchent.com` | Public LAN API consumers (e.g. `domain-admin`) |
| `higress_internal_api_consumers` | `higress-internal.higress-system.svc.cluster.local` | In-cluster apps (e.g. `open-webui`) |

1. Add/Remove a name in the appropriate list in [`variables.tf`](./variables.tf).
2. Run `terraform apply` — a new key is generated, pushed to Vault, and the ExternalSecret + key-auth WasmPlugin are re-rendered with the consumer.
3. Commit and push (ArgoCD syncs the generated manifests).

## Constraints

- Consumer names must be lowercase DNS labels (`^[a-z0-9]([-a-z0-9]*[a-z0-9])?$`): they double as Vault path segments and Kubernetes Secret keys.
