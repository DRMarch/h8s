# CloudNative-PG

[CloudNative-PG (CNPG)](https://cloudnative-pg.io/) is the operator for PostgreSQL clusters on the cluster. It manages HA Postgres with streaming replication, point-in-time recovery, and managed backups; it is used by Authelia, Open WebUI, and others.

## How it fits in

Each database consumer (Authelia, Open WebUI, MLflow, ...) gets its own `Cluster` CR in this directory. Secrets (superuser password, app role) are pulled from Vault via ESO and referenced as `bootstrap.initdb.secretRefs` or via `applicationDatabaseSecret` references.

## Resources

- `operator/values.yaml`: CNPG operator Helm chart values.
- `resources/clusters/`: one `Cluster` manifest per database consumer.

## Deployment

Deployed via ArgoCD:

- `cloudnative-pg-helm.yaml`: the operator.
- `cloudnative-pg-resources.yaml`: the per-consumer `Cluster` CRs (with the matching HTTPRoute and ExternalSecret dependencies already synced).

## Adding a new Postgres database

1. Add a Vault path under `kubernetes-homelab/cnpg/<consumer>` with the role credentials (see [terraform/README.md](../../terraform/README.md)).
2. Add an `ExternalSecret` that materialises them (the `secret-generator` app can do this: see `ci-cd/argo-cd/applications/bootstrap/secret-generator.yaml`).
3. Add a new `Cluster` manifest in `resources/clusters/` referencing the secret.
4. Add the cluster to the app-of-apps.
