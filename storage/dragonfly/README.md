# DragonflyDB

## Overview

[DragonflyDB](https://dragonflydb.io/) is a modern, high-performance in-memory datastore that is fully compatible with the Redis and Memcached wire protocols. It offers significant memory savings and multi-threaded performance compared to traditional Redis.

### What it does in this cluster

The DragonflyDB **operator** is installed in this cluster (via the official [Dragonfly Operator](https://github.com/dragonflydb/dragonfly-operator)) but no Dragonfly instances are currently deployed. The operator is kept available so future workloads (e.g. an application that needs Redis) can install a `Dragonfly` CR without having to install the operator separately.

> **Note:** As of the Authentik → Authelia migration (Phase 3, June 2026), the only consumer of Dragonfly was Authentik. With Authentik removed, the `redis` Dragonfly instance in the `authentik` namespace has been pruned and no replacement instance has been created. The operator remains installed for future use.

## Architecture

| Component | Detail |
|-----------|--------|
| **Operator namespace** | `dragonfly-operator-system` |
| **Operator sync-wave** | `-397` (ArgoCD) |
| **Chart** | `oci://ghcr.io/dragonflydb/dragonfly-operator/helm/dragonfly-operator` v1.5.0 |
| **Dragonfly CRs** | None deployed. |
| **CRDs** | `dragonflies.dragonflydb.io` is installed by the operator. |

## Deployment

### Operator

The Dragonfly Operator is deployed via the ArgoCD Helm application `dragonfly-operator-helm.yaml` (sync-wave `-397`). Values are defined in `storage/dragonfly/operator/values.yaml`.

### Adding a new Dragonfly instance

If a future workload needs Redis-compatible storage, create a `Dragonfly` CR in the target namespace. For example, to spin up a `redis` instance in a new `myapp` namespace:

```yaml
apiVersion: dragonflydb.io/v1alpha1
kind: Dragonfly
metadata:
  name: redis
  namespace: myapp
spec:
  replicas: 1
  args:
    - --proactor_threads=1
  resources:
    requests:
      memory: 128Mi
    limits:
      memory: 512Mi
```

Apply it with `kubectl apply -f` and the operator will provision the StatefulSet + Service.

### Verify operator is running

```bash
kubectl get pods -n dragonfly-operator-system
```

## Resources

- [DragonflyDB Documentation](https://dragonflydb.io/docs)
- [Dragonfly Operator Documentation](https://www.dragonflydb.io/docs/managing-dragonfly/operator/installation)
- [Dragonfly Operator GitHub](https://github.com/dragonflydb/dragonfly-operator)
