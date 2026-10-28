# Trivy Operator

[Trivy Operator](https://aquasecurity.github.io/trivy-operator/) scans the cluster for vulnerabilities, exposed secrets and misconfiguration using [Trivy](https://trivy.dev/). Scans trigger automatically when workloads change, and results are stored as Kubernetes custom resources you can query with `kubectl`.

## Reports

- `VulnerabilityReport`: CVEs in workload images
- `ConfigAuditReport`: workload configuration against built-in policies
- `ExposedSecretReport`: secrets embedded in workloads
- `RbacAssessmentReport`: RBAC misconfigurations
- `InfraAssessmentReport`: core components (etcd, apiserver, kubelet), collected by node-collector
- `ClusterComplianceReport`: CIS benchmark, NSA hardening guidance and Pod Security Standards, refreshed every 6h
- `SbomReport`: software bill of materials per image

## Configuration

- `helm/values.yaml`: trivy-operator Helm chart values.
- `resources/namespace.yaml`: the `trivy-system` namespace. It carries `pod-security.kubernetes.io/*: privileged` labels because node-collector jobs need `hostPID` and read-only hostPath mounts.

## Deployment

Deployed via ArgoCD. See `ci-cd/argo-cd/applications/bootstrap/trivy-operator-resources.yaml` and `trivy-operator-helm.yaml`.

Ordering dependencies:

1. `trivy-operator-resources.yaml` (sync-wave 1) creates the namespace first.
2. `trivy-operator-helm.yaml` (sync-wave 2) runs after `prometheus-stack` (wave 0), which provides the `ServiceMonitor` CRD.

## Metrics and dashboards

The chart exposes a `ServiceMonitor` that prometheus-stack scrapes automatically. Two Grafana dashboards live in `monitoring/grafana/resources/dashboards/trivy-operator/`:

- [Trivy Operator](https://grafana.com/grafana/dashboards/17813) (grafana.com 17813)
- [k8s-addons-trivy-operator](https://github.com/dotdc/grafana-dashboards-kubernetes) (dotdc)

## Viewing reports

```bash
kubectl get vulnerabilityreports -A
kubectl get configauditreports -A
kubectl get exposedsecretreports -A
kubectl get compliancereports
```

## Notes

- Scan jobs are throttled for the N100 nodes: `scanJobsConcurrentLimit: 2`, `scanJobTimeout: 15m`, Trivy CPU capped at 250m.
- Reports are stored in etcd and expire after 24h (`operator.scannerReportTTL`).
- Private registry images are scanned using the workload's own `imagePullSecrets`, or cluster-wide via `operator.privateRegistryScanSecretsNames` in `helm/values.yaml`. Not configured yet since Harbor is unused.
- Uninstalling the chart leaves the CRDs behind, and deleting the CRDs deletes all reports. See the [upstream docs](https://aquasecurity.github.io/trivy-operator/latest/getting-started/installation/helm/#uninstall).
