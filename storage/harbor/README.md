# Harbor 

This repository provides Kubernetes manifests for deploying [Harbor](https://goharbor.io/) — an open source, cloud-native artifact registry.

Harbor enhances a Docker registry with key features such as:

- Role-based access control
- Image vulnerability scanning
- Content signing and verification
- Image replication between registries
- A powerful web-based UI

## Deployment

Harbor will be deployed by argocd, and depends on [cloudnative-pg](../cloudnative-pg/) to be deployed first as it uses a [postgres backend](https://goharbor.io/docs/2.13.0/install-config/).

## Login WebUI

### WebUI
To access the WebUI for harbor you can navigate to [`harbor.homelab.local`](https://harbor.homelab.local/) if you have a local DNS setup in your home network as specified in [CoreDNS](../../networking/coredns/README.md). Or you can port forward locally with:
```bash
kubectl port-forward svc/harbor -n harbor 8080:80
```

Then navigate to the Web UI with [localhost:8080](http://localhost:8080)

You can get the admin password from
```bash
kubectl -n harbor get secret harbor-admin-credentials -o jsonpath="{.data.HARBOR_ADMIN_PASSWORD}" | base64 -d
```

### Docker

First you will need to get the crts from the cluster:

```bash
# Get the certificate from the cluster for harbor
kubectl -n cilium-secrets get secret harbor-harbor-homelab-local-tls -o jsonpath='{.data.ca\.crt}' | base64 --decode > /tmp/ca.crt

# Copy the certificate to your docker crts
sudo mkdir -p /etc/docker/certs.d/harbor.homelab.local
sudo cp /tmp/ca.crt /etc/docker/certs.d/harbor.homelab.local/

# Restart docker
sudo systemctl restart docker
```
You can get docker to login with:

```bash
export HARBOR_URL="https://harbor.homelab.local/"
echo $(kubectl -n harbor get secret harbor-admin-credentials -o jsonpath="{.data.HARBOR_ADMIN_PASSWORD}" | base64 -d) | docker login ${HARBOR_URL} -u admin --password-stdin
```

#### Test it Works!

Create an example project in harbor:
```bash
curl -u admin:$(kubectl -n harbor get secret harbor-admin-credentials -o jsonpath="{.data.HARBOR_ADMIN_PASSWORD}" | base64 -d) \
  -X POST "https://harbor.homelab.local/api/v2.0/projects" \
  -H "Content-Type: application/json" \
  -d '{
    "project_name": "myproject",
    "public": false
  }'

```

Next you can test uploading a docker image:
```bash
export HARBOR_URL="harbor.homelab.local"
export PROJECT="myproject"
export IMAGE_NAME="myapp"
export IMAGE_TAG=1.0
docker build -t ${HARBOR_URL}/${PROJECT}/${IMAGE_NAME}:${IMAGE_TAG} .

docker push ${HARBOR_URL}/${PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}
```
