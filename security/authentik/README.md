# Authentik

Authentik is the SSO provider for the cluster, deployed at `auth.drmarchent.com`.

## Architecture

A single ArgoCD Application (`authentik-helm`, sync-wave `-395`) deploys everything using multi-source:
- **Source 1:** Helm chart from `https://charts.goauthentik.io`
- **Source 2:** Values from `security/authentik/helm/values.yaml`
- **Source 3:** Raw manifests from `security/authentik/helm/resources/`

Raw manifests include the secret key, ExternalSecret for Google OAuth credentials, and blueprint ConfigMaps.

Blueprint ConfigMaps listed in `blueprints.configMaps` (`values.yaml` line 23-25) are mounted into the worker pod at:

```
/blueprints/mounted/cm-<configmap-name>/<key>.yaml
```

Example: `/blueprints/mounted/cm-authentik-google-blueprint/google-source.yaml`

## Blueprints

Blueprints automate Authentik configuration declaratively via YAML. The worker discovers and applies mounted blueprints within 60 minutes of deployment.

### Manual trigger

```bash
kubectl -n authentik exec deploy/authentik-worker -- ak apply_blueprint \
  /blueprints/mounted/cm-<configmap-name>/<key>.yaml
```

To see available blueprints inside the pod:

```bash
kubectl -n authentik exec deploy/authentik-worker -- ls -R /blueprints/
```

## Google OAuth Setup

### Phase 1: Google Cloud Console (one-time)

1. Log in to the [Google Developer Console](https://console.developers.google.com/).
2. Click **Select a project** → **New Project**, give it a name, and click **Create**.
3. Navigate to **APIs & Services** → **OAuth consent screen**:
   - **User Type**: External
   - **App Name**: `Authentik`
   - **User Support Email**: your email
   - **Authorized Domains**: `drmarchent.com`
   - **Developer Contact Info**: your email
   - Click **Save and Continue** through the remaining screens.
4. Navigate to **Credentials** → **Create Credentials** → **OAuth Client ID**:
   - **Application Type**: Web Application
   - **Name**: `Authentik`
   - **Authorized redirect URIs**: `https://auth.drmarchent.com/source/oauth/callback/google/`
   - Click **Create**.
5. Note the **Client ID** and **Client Secret**.

### Phase 2: Store credentials in Vault

```bash
kubectl exec -ti vault-0 -n vault -- /bin/sh
vault login
vault kv put kubernetes-homelab/authentik/google-oauth \
  client_id="YOUR_CLIENT_ID.apps.googleusercontent.com" \
  client_secret="YOUR_CLIENT_SECRET"
```

The [External Secrets Operator](../external-secrets/) syncs these into a Kubernetes Secret (`authentik-google-oauth-credentials`) in the `authentik` namespace automatically via the `vault-cluster-secretstore` ClusterSecretStore.

### Phase 3: Verify ESO sync

```bash
kubectl -n authentik get secret authentik-google-oauth-credentials
```

### Phase 4: Apply the blueprint

```bash
kubectl apply -f security/authentik/helm/resources/google-blueprint-configmap.yaml
kubectl -n authentik rollout restart deploy/authentik-worker
kubectl -n authentik rollout status deploy/authentik-worker
kubectl -n authentik exec deploy/authentik-worker -- ak apply_blueprint \
  /blueprints/mounted/cm-authentik-google-blueprint/google-source.yaml
```

The blueprint creates:
- A Google OAuth source (slug: `google`) with placeholder credentials
- Binds it to the default authentication identification stage ("Login with Google" button)
- An expression policy to auto-set the username from the Google email address

### Phase 5: Retrieve credentials from ESO-managed secret

```bash
kubectl -n authentik get secret authentik-google-oauth-credentials \
  -o jsonpath='{.data.client_id}' | base64 -d

kubectl -n authentik get secret authentik-google-oauth-credentials \
  -o jsonpath='{.data.client_secret}' | base64 -d
```

### Phase 6: Paste credentials into Authentik UI

1. Navigate to `https://auth.drmarchent.com/if/admin/#/core/sources`
2. Click **Federation & Social Login** → **Google**
3. Paste the **Consumer Key** (Client ID) and **Consumer Secret** (Client Secret) from Phase 5
4. Click **Update**

### Why `state: created` instead of `state: present`

The OAuth source entry uses `state: created` — this means the blueprint only creates the source once and never overwrites it on subsequent ArgoCD syncs. If `state: present` were used, every ArgoCD reconciliation would reset the credentials back to `PLACEHOLDER`.

### Verifying

1. Log out of Authentik
2. Visit `https://auth.drmarchent.com`
3. Verify that a **Login with Google** button appears
4. Click it and complete the Google OAuth flow

## Adding New Blueprints

### Option A: Add a key to the existing ConfigMap

Edit `security/authentik/helm/resources/google-blueprint-configmap.yaml` and add a new data key:

```yaml
data:
  google-source.yaml: |
    ...existing content...
  users.yaml: |
    version: 1
    entries:
      - model: authentik_core.group
        state: present
        identifiers:
          name: developers
        attrs:
          is_superuser: false
      - model: authentik_core.user
        state: present
        identifiers:
          username: test-user
        attrs:
          email: test@example.com
          name: Test User
          is_active: true
          groups:
            - !Find [authentik_core.group, [name, developers]]
```

### Option B: Create a new ConfigMap

1. Create a new ConfigMap file in `security/authentik/helm/resources/`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: authentik-users-blueprint
  namespace: authentik
data:
  users.yaml: |
    version: 1
    entries:
      ...
```

2. Add the ConfigMap name to `blueprints.configMaps` in `values.yaml`:

```yaml
blueprints:
  configMaps:
    - authentik-google-blueprint
    - authentik-users-blueprint
```

3. Apply, restart the worker, and trigger the blueprint:

```bash
kubectl apply -f security/authentik/helm/resources/
kubectl -n authentik rollout restart deploy/authentik-worker
kubectl -n authentik exec deploy/authentik-worker -- ak apply_blueprint \
  /blueprints/mounted/cm-authentik-users-blueprint/users.yaml
```
