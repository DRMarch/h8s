# DragonflyDB

## Overview

[DragonflyDB](https://dragonflydb.io/) is a modern, high-performance in-memory datastore that is fully compatible with the Redis and Memcached wire protocols. It offers significant memory savings and multi-threaded performance compared to traditional Redis.

### What it does in this cluster

DragonflyDB provides a Redis-compatible datastore for applications that need caching, session storage, or task queuing. In this cluster, it:

- Serves as the session store and task broker for Authentik
- Provides Redis-compatible APIs (port 6379) as a drop-in replacement
- Exports Prometheus metrics via ServiceMonitor
- Includes a pre-built Grafana dashboard

## Architecture

DragonflyDB is deployed via the official [Dragonfly Operator](https://github.com/dragonflydb/dragonfly-operator) and managed by ArgoCD.

| Component | Detail |
|-----------|--------|
| **Operator** | `dragonfly-operator-system` namespace, sync-wave `-397` |
| **Chart** | `oci://ghcr.io/dragonflydb/dragonfly-operator/helm/dragonfly-operator` v1.5.0 |
| **Dragonfly instance** | `authentik` namespace, sync-wave `-396` |
| **CRD name** | `redis` (produces service `redis.authentik.svc.cluster.local:6379`) |
| **Replicas** | 1 |
| **Persistence** | Operator-managed PVC |
| **Metrics** | ServiceMonitor for Prometheus + Grafana dashboard |

The CRD is intentionally named `redis` so existing applications can connect without configuration changes.

## Deployment

### Operator

The Dragonfly Operator is deployed via the ArgoCD Helm application `dragonfly-operator-helm.yaml`. Values are defined in `storage/dragonfly/operator/values.yaml`.

### Dragonfly instance

The Dragonfly CRD is deployed via the ArgoCD Kustomize application `dragonfly-operator-resources.yaml` pointing at `storage/dragonfly/resources/`.

Sync order: `dragonfly-operator-helm` (`-397`) → `dragonfly-operator-resources` (`-396`) → `authentik-helm` (`-395`)

### Verify

```bash
kubectl get pods -n dragonfly-operator-system
kubectl get dragonfly -n authentik
kubectl get pods -n authentik -l app=dragonfly
kubectl get svc redis -n authentik
```

### Testing connectivity

```bash
kubectl exec -n authentik deploy/authentik-server -c server -- redis-cli -h redis PING
```

### Scaling

```bash
kubectl patch dragonfly redis -n authentik --type merge -p '{"spec":{"replicas":3}}'
```

Or update `storage/dragonfly/resources/dragonfly.yaml` and let ArgoCD sync.

## Resources

- [DragonflyDB Documentation](https://dragonflydb.io/docs)
- [Dragonfly Operator Documentation](https://www.dragonflydb.io/docs/managing-dragonfly/operator/installation)
- [Dragonfly Operator GitHub](https://github.com/dragonflydb/dragonfly-operator)
