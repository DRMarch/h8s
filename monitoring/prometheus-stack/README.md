# Prometheus Stack

[prometheus-operator](https://github.com/prometheus-operator/prometheus-operator) and the kube-prometheus-stack Helm chart provide the cluster's observability backend. It ships Prometheus, Alertmanager, Grafana datasources, and a wide library of recording/alerting rules.

## Components

- **Prometheus**: scrapes pods annotated with `prometheus.io/scrape: "true"` and any `ServiceMonitor`/`PodMonitor` CRs.
- **Alertmanager**: routes alerts to the Discord webhook for cluster-level events (PVC filling, etcd issues, etc.).
- **Grafana**: separate chart; datasources auto-wired to the in-cluster Prometheus. See [monitoring/grafana/README.md](../grafana/README.md).

## Configuration

- `values.yaml`: kube-prometheus-stack Helm values (retention, resources, scrape intervals).
- `resources/kustomization.yaml`: overlays: extra `ServiceMonitor`s, custom rule files, `PrometheusRule` for CNPG.
- `resources/alertmanager-config.yaml`: `AlertmanagerConfig` for the Discord cluster webhook.
- `resources/discord-webhook-externalsecret.yaml`: pulls the webhook URL from Vault.
- `resources/cnpg-rules.yaml`: `PrometheusRule` for CloudNative-PG (replica lag, WAL size, etc.).
- `resources/hisgress.yaml`: Higress gateway metrics scrape target.

## Deployment

Deployed via ArgoCD. See `ci-cd/argo-cd/applications/bootstrap/prometheus-stack-helm.yaml`. Bump chart versions and config there.

Ordering dependencies:

1. `terraform/vault-secrets`: Discord webhook URL in Vault.
2. `terraform/templates`: ExternalSecret manifest.
3. `monitoring/grafana`: depends on the Prometheus service existing.
