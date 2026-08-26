# Renovate

[Renovate](https://github.com/renovatebot/renovate) keeps dependencies up to date across this repository. It runs as a `CronJob`-style `RenovateJob` (via [renovate-operator](https://github.com/mogenius/renovate-operator)) inside the cluster and opens PRs against `DRMarch/h8s`.

## Schedule

Runs daily at **19:00 UTC** (`0 19 * * *`). PRs target the same repository; `parallelism: 1` keeps the queue small.

## Authentication

- The GitHub fine-grained PAT lives in Vault at `kubernetes-homelab/renovate/github` (key `token`).
- It is materialised into the `renovate-operator` namespace by ESO via `resources/github-token-secret.yaml`.
- PAT generation and rotation are handled by `terraform/vault-secrets` — see [terraform/README.md](../../terraform/README.md) and [security/vault/README.md](../../security/vault/README.md#renovate).

The PAT **must** have `Contents: Write` and `Pull requests: Write` on `DRMarch/h8s`, or Renovate will fail with `403` when pushing.

## What Renovate manages

See [`renovate.json`](../../renovate.json) at the repo root for the full matchers list. Summary:

- **ArgoCD** Applications (chart `targetRevision`).
- **Helm** chart versions referenced by `ci-cd/argo-cd/applications/bootstrap/*.yaml`.
- **Kubernetes** manifests (image tags, resource versions).
- **Dockerfile** base images.
- **Devbox** packages (`devbox.json`).

## Resources

- `resources/renovatejob-h8s.yaml` — the `RenovateJob` CRD.
- `resources/github-token-secret.yaml` — ESO binding for the GitHub PAT.
- `operator/values.yaml` — chart values for renovate-operator.
