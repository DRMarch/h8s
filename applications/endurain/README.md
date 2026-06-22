# Endurain

Self-hosted fitness tracker ([endurain-project/endurain](https://codeberg.org/endurain-project/endurain)).
Served at `https://endurain.drmarchent.com` via the Cilium Gateway.

## Deployment

```bash
kubectl apply -k applications/endurain
```

Stateful: PostgreSQL via CloudNative-PG (see `storage/cloudnative-pg/resources/clusters/endurain/`).

## OIDC / Authelia SSO

Endurain's database holds the OIDC client config (issuer URL, client ID,
client secret, scopes, slug). The Authelia side holds the counterpart
OIDC client definition.

| Component | Path | Role |
|---|---|---|
| Authelia OIDC client | `security/authelia/helm/values.yaml` (`identity_providers.oidc.clients[].client_id: 'endurain'`) | Issues ID tokens to Endurain |
| Vault secret (pbkdf2 hash + plaintext) | `authelia/endurain-oidc` in Vault, written by `terraform/vault-secrets/main.tf` | Source of truth for the client secret |
| ESO pulls hash into K8s | `security/authelia/helm/resources/endurain-client-secret-externalsecret.yaml` | Mounted into Authelia pod as a file |
| Endurain-side IdP row | Created in `endurain` Postgres DB via the Endurain UI | Endurain's view of the same client |

The callback URL is `https://endurain.drmarchent.com/api/v1/public/idp/callback/authelia`.
The `authelia` path segment is the **slug** (user-chosen, must match on
both sides).

### UI setup (one-time, after Authelia redeploys with the new OIDC client)

```bash
# 1. Confirm Authelia is up with the new OIDC client
kubectl rollout status deploy/authelia -n authelia

# 2. Retrieve the plaintext client secret (you'll paste it into the UI)
cd terraform/vault-secrets
terraform output -raw endurain_oidc_client_secret
# Copy the output to your clipboard

# 3. Register the IdP in Endurain via the UI
```

Then in the browser:

1. Log into `https://endurain.drmarchent.com` as the local admin user
   (default credentials are `admin` / `admin` per the
   [Endurain docs](https://docs.endurain.com/getting-started/advanced-started/) —
   **change this before exposing the service**).
2. Navigate to **Settings → Identity Providers**.
3. Click **Add Identity Provider** → select **Authelia** (it's a built-in
   template per the [Endurain SSO docs](https://docs.endurain.com/features/single-sign-on/)).
4. Fill in the fields:
   - **Provider Name**: `Authelia` (the display name on the login button)
   - **Slug**: `authelia` (must match the path segment in the Authelia
     `redirect_uris` configured in `security/authelia/helm/values.yaml`)
   - **Provider Type**: `OIDC`
   - **Issuer URL**: `https://auth.drmarchent.com` (no trailing slash)
   - **Client ID**: `endurain` (must match Authelia's `client_id`)
   - **Client Secret**: paste the plaintext from step 2
   - **Scopes**: `openid profile email`
5. Click **Save**.

The login page will now show a "Sign in with Authelia" button.

To verify the whole flow end-to-end:

1. Log out of Endurain (or use an incognito window).
2. Visit `https://endurain.drmarchent.com` — expect a "Sign in with
   Authelia" button on the login page.
3. Click it → expect a 302 redirect to `https://auth.drmarchent.com`.
4. Log in with the local Authelia admin password.
5. Expect to land in the Endurain UI, authenticated.

### How the flow works (Authorization Code + PKCE)

1. User clicks **Sign in with Authelia** on the Endurain login page.
2. Browser hits `GET /api/v1/public/idp/login/authelia?code_challenge=...&code_challenge_method=S256`.
3. Endurain 307-redirects to `https://auth.drmarchent.com/api/oidc/authorization?...`.
4. User authenticates against Authelia (1FA for now — the single admin user).
5. Authelia 307-redirects back to `https://endurain.drmarchent.com/api/v1/public/idp/callback/authelia?code=...&state=...`.
6. Endurain POSTs to Authelia's token endpoint with the client secret,
   then GETs `/api/oidc/userinfo` for the email.
7. Endurain finds/creates the local user, creates a session, and
   307-redirects the browser to `/login?sso=success&session_id=...`.
8. The frontend POSTs `/api/v1/public/idp/session/{session_id}/tokens`
   with the PKCE `code_verifier` to mint the Endurain JWT (15-min) +
   refresh cookie (7-day).

## Operational notes

- **`FRONTEND_PROTOCOL=https`** is not currently set in the deployment
  env, which means the refresh-token cookie will be issued without the
  `Secure` flag (default `http`). Recommended to add:
  ```yaml
  - name: FRONTEND_PROTOCOL
    value: https
  ```
  to the `env:` block in `deployment.yaml`. This is orthogonal to the
  OIDC setup; the OIDC flow itself works either way.

- **Default credentials**: the fresh-install admin user is `admin` /
  `admin` and lives only in the `endurain` database. Change it before
  exposing the service.

- **OIDC button visibility**: the button only appears if the IdP row is
  `enabled: true` AND the row exists. The list rendered on the login
  page is `GET /api/v1/public/idp`, which filters to enabled providers
  only. To re-disable without deleting, toggle the provider off in
  **Settings → Identity Providers** in the Endurain UI.

- **Rotating the client secret** (see `security/authelia/README.md:64-69`
  for the canonical rotation procedure): rotate the Vault entry (pbkdf2
  hash + plaintext together), restart Authelia, then re-open the IdP in
  the Endurain UI and paste the new plaintext. All existing Endurain
  sessions that authenticated via the old client secret remain valid
  until they expire (15 min access, 7 day refresh).

- **Authelia access_control rules**: the existing `*.drmarchent.com`
  `one_factor` rule in `security/authelia/helm/values.yaml` covers
  `endurain.drmarchent.com` and is what enforces "must be
  authenticated" for the OIDC callback exchange. No IdP-specific rule
  is required.

- **Common UI issues** (from the [Endurain SSO troubleshooting
  section](https://docs.endurain.com/features/single-sign-on/#troubleshooting)):
  - **"Invalid redirect URI"** — the Slug in the Endurain UI must produce
    a callback URL of `https://endurain.drmarchent.com/api/v1/public/idp/callback/authelia`
    exactly. Re-check that the Slug field matches the path segment
    registered in `security/authelia/helm/values.yaml`.
  - **"Email address mismatch creates duplicate account"** — the
    Endurain local admin user must have an email matching the one
    Authelia returns, or SSO will create a new (admin-less) user.
    Update the local user's email in **Settings → Profile** first if
    needed.
  - **"SSO button doesn't appear"** — re-check that the IdP is enabled
    (toggle in **Settings → Identity Providers**) and that the local
    admin user can still log in with the password (the button is only
    rendered for visitors who are not already signed in).

## Strava Integration

Endurain syncs activities and gear from Strava per-user. Each user
supplies their own Strava API client ID and secret; the resulting
access/refresh tokens are stored encrypted in the Endurain database.

| Component | Path / URL | Role |
|---|---|---|
| Strava API app | https://www.strava.com/settings/api | User-owned API app (client_id + client_secret + callback domain) |
| Endurain env var | `ENDURAIN_HOST` in `deployment.yaml` | Base URL Endurain uses to build the Strava `redirect_uri` |
| Encrypted tokens | `endurain` Postgres DB (`users_integrations` table) | Strava access + refresh tokens, Fernet-encrypted at rest |

`ENDURAIN_HOST` is **required** for Strava and **must use HTTPS** (per
the [Endurain env vars
docs](https://docs.endurain.com/getting-started/advanced-started/)).
It is currently set to `https://endurain.drmarchent.com` in
`deployment.yaml:90`.

### Strava app setup (one-time, per user)

1. Log in to Strava.
2. Go to https://www.strava.com/settings/api → **Create App** (or open
   an existing one).
3. Fill in:
   - **Application Name** / **Category** / **Club** — anything
     descriptive, not security-relevant.
   - **Website**: `https://endurain.drmarchent.com`
   - **Authorization Callback Domain**: `endurain.drmarchent.com`
     - **Just the host** — no scheme, no path, no trailing slash. The
       value MUST match the host in `ENDURAIN_HOST` exactly. Strava
       validates the host; any path underneath it is allowed
       automatically.
4. Click **Update** / **Create**.
5. Note the **Client ID** and **Client Secret** — you'll paste them
   into Endurain in the next step.

### Link Strava from the Endurain UI (per user)

1. Log into `https://endurain.drmarchent.com`.
2. Navigate to **Settings → Integrations** (or **Settings → Strava**,
   depending on the Endurain version).
3. Enter the **Client ID** and **Client Secret** from the Strava app.
4. Click **Link Strava** → Strava prompts for authorisation → on
   approval, Strava redirects back to Endurain, which exchanges the
   code for tokens and stores them encrypted in the DB.

Once linked, Endurain's background worker checks for new activities on
startup and once per hour (per the [Endurain Strava
docs](https://docs.endurain.com/integrations/3rd-party-services/)).

### Operational notes

- **Each user must set up their own Strava app.** Endurain does not
  ship a shared client_id/client_secret. The Callback Domain must be
  configured on the *individual* Strava app of the *individual* user
  who is linking.

- **`ENDURAIN_HOST` changes require a pod restart.** The pod reads
  the env var at startup; it is not hot-reloaded. After editing
  `deployment.yaml`, run `kubectl rollout restart deploy/endurain
  -n endurain`.

- **Rotating the client secret** is straightforward: generate a new
  secret in the Strava API settings page, then in the Endurain UI
  open the Strava integration and re-paste the new Client ID +
  Secret. Endurain will re-run the OAuth handshake on next link.

- **Unlinking** removes the access/refresh tokens from the DB and,
  per the [Strava API
  agreement](https://www.strava.com/legal/api), deletes all
  activities and gear previously imported from Strava.

### Troubleshooting

- **`{"message":"Bad Request","errors":[{"resource":"Application","field":"redirect_uri","code":"invalid"}]}`**
  — The `redirect_uri` Endurain sent to Strava's `/oauth/token`
  endpoint doesn't match the Callback Domain registered on the
  Strava app. **Fix**: set the **Authorization Callback Domain** on
  https://www.strava.com/settings/api to `endurain.drmarchent.com`
  (just the host, no `https://`, no path, no trailing slash). The
  value must match the host in `ENDURAIN_HOST` exactly. See
  [Strava's auth docs](https://developers.strava.com/docs/authentication/)
  for the rules.

- **`ENDURAIN_HOST` set to `http://...`** — Strava requires HTTPS for
  the redirect_uri (except `localhost` / `127.0.0.1`). The current
  `deployment.yaml:90` uses `https://`, which is correct. If you copy
  this config to a new environment, keep the `https://` scheme.

- **Trailing slash in `ENDURAIN_HOST`** — values like
  `https://endurain.drmarchent.com/` (with trailing slash) cause
  Endurain to build a malformed `redirect_uri` and Strava will reject
  it. The current value (`https://endurain.drmarchent.com`, no
  trailing slash) is correct.

- **Link button errors immediately on click** — usually means
  `ENDURAIN_HOST` is unset or not reachable from the internet. Check
  the Endurain pod logs: `kubectl logs -n endurain deploy/endurain |
  grep -i strava`.

- **Upstream caveat**: the [Endurain 3rd-party-services
  page](https://docs.endurain.com/integrations/3rd-party-services/)
  warns that *"Due to recent Strava API changes, expect changes in the
  Strava integration in a following release."* If `redirect_uri
  invalid` persists after fixing the Callback Domain, check open
  issues on [Codeberg](https://codeberg.org/endurain-project/endurain/issues)
  (the GitHub mirror is read-only).

## Source files

| File | Role |
|---|---|
| `deployment.yaml` | Endurain Deployment + init containers (handles the upstream chown workaround) |
| `service.yaml` | ClusterIP `endurain:8080` |
| `pvc.yaml` | 10Gi Longhorn volume for `/app/backend/data` and `/app/backend/logs` |
| `secret-key.yaml` | Mittwald secret-generator annotation for `SECRET_KEY` |
| `fernet-key.yaml` | Mittwald secret-generator annotation for `FERNET_KEY` |
| `kustomization.yaml` | Bundles the above |
| `README.md` | This file |
