# Garage

## Overview

[Garage](https://garagehq.deuxfleurs.fr/) is a lightweight, easy-to-operate, open-source object storage solution with a focus on simplicity and resilience. It's S3-compatible, making it a drop-in replacement for AWS S3 for local storage needs.

### What it does in this cluster

Garage provides distributed object storage across the homelab, allowing applications to store and retrieve files using S3-compatible APIs. In this cluster, it:

- Serves as the primary object storage backend for applications that need blob storage
- Provides S3-compatible APIs
- Handles bucket management, access keys, and authentication
- Integrates with Kubernetes via the Garage Operator for simplified deployment and lifecycle management

## Architecture

This deployment consists of two main components:

### Operator

The `operator/` directory contains the Garage Operator Helm chart configuration. The operator is a Kubernetes controller that manages Garage cluster deployments and resources declaratively. It automates cluster provisioning, configuration, and updates.

- **Chart**: `ghcr.io/rajsinghtech/garage-operator`
- **Documentation**: [garage-operator GitHub](https://github.com/rajsinghtech/garage-operator)

### Resources

The `resources/` directory contains the actual Garage cluster configuration:

- **`cluster.yaml`**: Defines the Garage cluster topology and configuration
- **`admin-token.yaml`** & **`admin-key.yaml`**: Administrative credentials for cluster access
- **`buckets/`**: Bucket definitions (default bucket included)

## Deployment

### Installation

1. **Install the Garage Operator first** (handled by ArgoCD bootstrap):
   ```bash
   # This is typically deployed via the ArgoCD bootstrap process
   # Reference: argocd/applications/bootstrap/garage-operator-helm.yaml
   ```

2. **Apply the Garage cluster and resources**:
   ```bash
   kubectl apply -k storage/garage/resources
   ```

3. **Verify deployment**:
   ```bash
   kubectl get garage -n garage
   kubectl get pods -n garage
   kubectl logs -n garage -l app.kubernetes.io/name=garage --tail=50
   ```

## Usage

### Retrieve Credentials

Get the AWS credentials for accessing the S3 endpoint:

```bash
export AWS_DEFAULT_REGION="eu-west-2"
export AWS_ACCESS_KEY_ID=$(kubectl get secret default-bucket-key -n garage -o jsonpath='{.data.access-key-id}' | base64 -d)
export AWS_SECRET_ACCESS_KEY=$(kubectl get secret default-bucket-key -n garage -o jsonpath='{.data.secret-access-key}' | base64 -d)

```

### Test S3 Upload

Upload a test file to the default bucket:

```bash
echo "Hello from the Homelab" > test.txt
aws s3 cp test.txt s3://default/test.txt --endpoint-url https://s3.homelab.local --no-verify-ssl
aws s3 ls s3://default/ --endpoint-url https://s3.homelab.local --no-verify-ssl
```

### SSL Certificate Setup (Optional)

To avoid using `--no-verify-ssl`, extract and install the TLS certificates locally:

```bash
# Extract certificates from the Kubernetes secret
kubectl -n garage get secret garage-homelab-local-tls -o jsonpath='{.data.ca\.crt}' | base64 -d > /tmp/garage-ca.crt
kubectl -n garage get secret garage-homelab-local-tls -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/garage-service.crt
kubectl -n garage get secret garage-homelab-local-tls -o jsonpath='{.data.tls\.key}' | base64 -d > /tmp/garage-service.key

# Install certificates system-wide
sudo cp /tmp/garage-ca.crt /usr/local/share/ca-certificates/
sudo cp /tmp/garage-service.crt /etc/ssl/certs/
sudo cp /tmp/garage-service.key /etc/ssl/private/
sudo chmod 600 /etc/ssl/private/garage-service.key

# Update certificate index
sudo update-ca-certificates

# Now you can use S3 without --no-verify-ssl
aws s3 ls s3://default/ --endpoint-url https://s3.homelab.local
```
## Resources

- [Garage Official Documentation](https://garagehq.deuxfleurs.fr/)
- [Garage Operator GitHub Repository](https://github.com/rajsinghtech/garage-operator)
- [S3 API Compatibility](https://garagehq.deuxfleurs.fr/documentation/api-s3/)
