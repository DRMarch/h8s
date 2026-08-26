# External Secrets Operator

[External Secrets Operator (ESO)](https://external-secrets.io/) syncs secrets from HashiCorp Vault into Kubernetes `Secret` resources. It is the bridge between the Vault source of truth and workloads that need a `Secret` to mount.

## How it fits in

```text
Vault (kubernetes-homelab/...)
  -> SecretStore (VaultBackend, kubernetes auth)
  -> ExternalSecret (per-consumer)
  -> Kubernetes Secret
  -> mounted by the workload
```

The Vault Kubernetes auth role (`external-secrets-vault-auth`) is bound to the `external-secrets-vault-auth` ServiceAccount in the `external-secrets` namespace, see [security/vault/README.md](../vault/README.md#kubernetes-service-accounts).

## Resources

- `resources/vault-cluster-secretstore.yaml`: cluster-wide `SecretStore` for Vault (server: `http://vault.vault.svc.cluster.local:8200`, mount: `kubernetes-homelab`).
- `resources/external-secrets-vault-auth-sa.yaml`: ServiceAccount used by ESO for Vault kubernetes auth.
- `helm/values.yaml`: ESO Helm chart values.

## Deployment

Deployed via ArgoCD with two bootstrap applications:

- `external-secrets-helm.yaml`: installs ESO itself.
- `external-secrets-resources.yaml`: applies the cluster `SecretStore` and auth ServiceAccount.

Bump chart versions and config there.
