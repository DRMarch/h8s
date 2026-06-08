# Hashicorp Vault

## Helm

## Deployment Manual
```bash
helm repo add hashicorp https://helm.releases.hashicorp.com

helm install vault hashicorp/vault \
  --version 0.30.0 \
  --namespace vault \
  --create-namespace \
  --values helm/values.yaml
```

## Resources

### Deployment Manual

```bash
kubectl apply -k security/vault/resources
```

## First Time Installation

If installing for the first time, you will need to [initialise the vault](https://developer.hashicorp.com/vault/docs/commands/operator/init). Run:

```bash
kubectl exec -ti vault-0 -n vault -- vault operator init
```

***BE SURE TO SAVE THE OUTPUT SOMEWHERE SAFE!***

You will then need to unseal the server:

```bash
kubectl exec -ti vault-0 -n vault -- vault operator unseal
```

### Kubernetes Service Accounts

In order for ESO to use a service account to access Vault, run the following:

```bash
kubectl exec -ti vault-0 -n vault -- /bin/sh
vault login
vault auth enable kubernetes
vault secrets enable -path=kubernetes-homelab kv-v2
vault write auth/kubernetes/config \
    kubernetes_host=https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt 

vault policy write external-secrets-reader - <<EOF
path "kubernetes-homelab/data/*" {
  capabilities = ["create", "read", "update", "delete", "patch"]
}
path "kubernetes-homelab/metadata/*" {
  capabilities = ["list", "delete"]
}
EOF

vault write auth/kubernetes/role/external-secrets-vault-auth \
    bound_service_account_names=external-secrets-vault-auth \
    bound_service_account_namespaces=external-secrets \
    policies=external-secrets-reader \
    ttl=24h
```

### Cert Manager Root CA Service

Vault is setup to be the root CA service for [cert-manager](../../networking/cert-manager/README.md). Run the following (assuming you have run the above):

```bash
kubectl exec -ti vault-0 -n vault -- /bin/sh

DOMAIN="drmarchent.com"
ROLE_NAME=$(echo $DOMAIN | sed 's/\./\-dot\-/')
echo "Vault role name: $ROLE_NAME"

# Enable PKI secrets engine
vault secrets enable pki

# Increase TTL from 30 days -> 1 year
vault secrets tune -max-lease-ttl=8760h pki

# Create self-signed root CA 
vault write pki/root/generate/internal \
    common_name=$DOMAIN \
    ttl=8760h

# Update the CRL location and issuing certificates
vault write pki/config/urls \
    issuing_certificates="http://127.0.0.1:8200/v1/pki/ca" \
    crl_distribution_points="http://127.0.0.1:8200/v1/pki/crl"

# Configure a role that maps a name in Vault to a procedure for generating a certificate
vault write pki/roles/$ROLE_NAME \
    allowed_domains=$DOMAIN \
    allow_bare_domains=true \
    allow_subdomains=true \
    max_ttl=72h

# Create a policy to enable read access to the PKI secrets engine paths
vault policy write pki - <<EOF
path "pki*"                   { capabilities = ["read", "list"] }
path "pki/sign/$ROLE_NAME"    { capabilities = ["create", "update"] }
path "pki/issue/$ROLE_NAME"   { capabilities = ["create"] }
EOF

# Create role for a K8s service account to use
vault write auth/kubernetes/role/vault-issuer \
    bound_service_account_names=vault-issuer \
    bound_service_account_namespaces=cert-manager \
    policies=pki \
    ttl=20m
```

Read more here:
- https://developer.hashicorp.com/vault/docs/secrets/pki/setup
- https://developer.hashicorp.com/vault/tutorials/archive/kubernetes-cert-manager



### Vault Secrets

This cluster uses Vault to store secret API keys to avoid exposing them in manifests. The following API keys will need to be setup

First login to the vault

```bash
kubectl exec -ti vault-0 -n vault -- /bin/sh

vault login

```

Follow the next subsections for the expected API keys

#### GitHub App 

##### Argo Events
Argo Events uses a GitHub App private key to authenticate with your repository and trigger Argo Workflows based on repository events.

```bash
export ARGO_EVENTS_GITHUB_APP_PRIVATE_KEY="<INSERT_YOUR_GITHUB_APP_PRIVATE_KEY_HERE>"
vault kv put kubernetes-homelab/argo-events/github-app private-key="$ARGO_EVENTS_GITHUB_APP_PRIVATE_KEY"
```

##### Renovate

```bash
export RENOVATE_GITHUB_APP_PRIVATE_KEY="<INSERT_YOUR_GITHUB_APP_PRIVATE_KEY_HERE>"
vault kv put kubernetes-homelab/renovate/github-app private-key="$RENOVATE_GITHUB_APP_PRIVATE_KEY"
```

#### Cloudflared Tunnel

Cloudflared tunnel creates a secure, encrypted connection from Cloudflare's edge to your cluster, allowing you to expose services without opening firewall ports.

```bash
export CLOUDFLARE_TUNNEL_TOKEN="<INSERT_YOUR_CLOUDFLARE_TUNNEL_TOKEN_HERE>"
vault kv put kubernetes-homelab/cloudflare/tunnel private-key="$CLOUDFLARE_TUNNEL_TOKEN"
```

### Pod Rescheduling

Whenever the pod(s) for Vault are rescheduled, they will need to be [unsealed](https://developer.hashicorp.com/vault/docs/concepts/seal) again. Run:

```bash
kubectl exec -ti vault-0 -n vault -- vault operator unseal
```

Enter in 3 of the keys produced from the [first time installation](#first-time-installation).

