# Longhorn

[Longhorn](https://longhorn.io/) is the cluster's distributed block storage. It turns the local disks on each TRIGKEY N100 into replicated, persistent volumes for StatefulSets (Postgres, MinIO/Garage, etc.).

## Prerequisites

Each node must have the Longhorn dependencies installed. See [SETUP.md](../../SETUP.md#7-additional-setup-longhorn-deps) for the `open-iscsi`, `nfs-common`, `cryptsetup`, and `dmsetup` install steps, and the `multipathd` disable step.

## How it fits in

Longhorn provisions `PersistentVolumeClaim`s consumed by stateful workloads. PVs are replicated across nodes; volume-level snapshots and S3 backups are available but currently disabled in this homelab.

## Resources

- `values.yaml`: Longhorn Helm chart values (replica count, default storage class).
- `resources/networkpolicy-allow-monitoring.yaml`: `NetworkPolicy` allowing Prometheus to scrape Longhorn's metrics endpoints.

## Deployment

Deployed via ArgoCD. See `ci-cd/argo-cd/applications/bootstrap/longhorn-application-helm.yaml`. Bump chart versions and config there.

## Inspecting a PVC

See [DEBUGGING.md](../../DEBUGGING.md#inspect-pvc) for a recipe to spin up a `pvc-inspector` pod attached to a Longhorn volume.
