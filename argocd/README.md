# Argo CD

## What is Argo CD?

**Argo CD** is a Kubernetes-native continuous delivery (CD) tool that follows GitOps principles to automate the deployment and lifecycle management of applications. It continuously monitors your Git repositories for changes to declarative application definitions and ensures that your Kubernetes clusters are synchronised to the desired state specified in Git. This approach provides a reliable, auditable, and easy-to-manage deployment process, enabling teams to deliver applications faster and with greater confidence.

Key features include:
- Automated synchronisation of Kubernetes manifests from Git.
- Support for multiple configuration management tools such as Helm, Kustomize, and plain YAML.
- A user-friendly web UI and CLI for managing applications.
- Multi-cluster deployment capabilities.
- Role-based access control (RBAC) for secure multi-team collaboration.

## Deployment
The following steps demonstrate how to deploy Argo CD into your Kubernetes cluster using the official Helm chart. 
This method allows you to customize your deployment via Helm values and ensures your Argo CD installation is reproducible and version-controlled.
```bash
export ARGOCD_HELM_VER=8.1.3 # Jul 2025

helm repo add argo https://argoproj.github.io/argo-helm && helm repo update

helm upgrade argocd argo/argo-cd \
    --install \
    --namespace argocd \
    --create-namespace \
    --version ${ARGOCD_HELM_VER} \
    -f ./values.yaml
```

## App of Apps Pattern

The **App of Apps** pattern allows you to manage multiple Argo CD applications as a single parent application. This is useful for bootstrapping complex environments.

To bootstrap your applications using the App of Apps pattern:

```bash
kubectl apply -f applications/app-of-apps-bootstrap.yaml
```

## Accessing the Argo CD UI

After installation, you can access the Argo CD web UI by port-forwarding the service:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then open [https://localhost:8080](https://localhost:8080) in your browser.

You can get the password with:
```bash

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 
```