# Excalidraw

Self-hosted virtual whiteboard (the React SPA from [excalidraw/excalidraw](https://github.com/excalidraw/excalidraw)), served as a static SPA from the official `nginx:stable-alpine-slim` container image.

- **Image source:** `docker.io/excalidraw/excalidraw:latest`, pinned by multi-arch manifest digest. No pull-through cache; the kubelet pulls direct from Docker Hub.
- **State:** local-first. Drawings are saved in the browser's IndexedDB (`idb-keyval`) by the SPA. There is no PVC, no DB, no server-side persistence.
- **SSO:** none in the app itself. The HTTPRoute applies `type: ExternalAuth` -> Authelia, so the URL is gated by the existing `one_factor` rule for `*.drmarchent.com` (see `security/authelia/helm/values.yaml:243-247`).
- **Prometheus:** the app exposes no metrics. Scrape with `kube-state-metrics` and ingress-nginx's built-in per-route metrics if you want to chart it.
- **Collab server:** not deployed. Share via the SPA's built-in "Shareable links" (end-to-end encrypted, no server). If real-time multi-user editing is ever needed, deploy [`excalidraw/excalidraw-room`](https://github.com/excalidraw/excalidraw-room) as a sibling Deployment and rebuild the image with `VITE_APP_COLLAB_URL` set.

## Deployment

ArgoCD manages this app. The `excalidraw` namespace is created automatically by ArgoCD on first sync via the `CreateNamespace=true` sync option on the Application at `ci-cd/argo-cd/applications/bootstrap/excalidraw.yaml`.

The Kustomize directory only contains the workload (Deployment + Service). The HTTP route, ReferenceGrants, and TLS Certificate are deployed by separate ArgoCD Applications:

| Resource kind | Owning Application |
|---|---|
| `Deployment`, `Service` | `excalidraw` (this app, sync wave `0`) |
| `HTTPRoute`, `ReferenceGrant` (TLS), `ReferenceGrant` (ext-auth) | `gateway-resources` (sync wave `-49`) |
| `Certificate` | `cert-manager-resources` (sync wave `-299`) |

```bash
# 1. Commit and push — the app-of-apps Application auto-detects
#    the new file and creates the excalidraw Application.
git add ci-cd/argo-cd/applications/bootstrap/excalidraw.yaml \
        applications/excalidraw/ \
        networking/gateway/resources/http-routes/excalidraw.yaml \
        networking/gateway/resources/reference-grants/lan-gateway-excalidraw-tls.yaml \
        networking/gateway/resources/reference-grants/excalidraw-external-auth-authelia.yaml \
        networking/gateway/resources/kustomization.yaml \
        networking/gateway/resources/gateways/lan.yaml \
        networking/cert-manager/resources/certificates/excalidraw-homelab-local.yaml \
        networking/cert-manager/resources/kustomization.yaml
git commit -m "Add excalidraw"
git push

# 2. Watch ArgoCD reconcile everything
kubectl get application excalidraw -n argocd -w
argocd app sync excalidraw                # force-sync if you don't want to wait
argocd app sync gateway-resources         # HTTPRoute re-applies once the namespace exists

# 3. Verify
kubectl get pods,svc -n excalidraw
kubectl get certificate excalidraw-homelab-local -n excalidraw
kubectl get httproute excalidraw -n excalidraw
kubectl get referencegrant -A | grep excalidraw
```

Browse https://excalidraw.drmarchent.com — first request should redirect to https://auth.drmarchent.com, then land on the canvas after the admin user authenticates.

## Updating the image

The Excalidraw project only publishes a `latest` tag, so this deployment pins to the multi-arch manifest digest of whatever `latest` is at install time. To pick up a newer upstream build:

```bash
docker buildx imagetools inspect excalidraw/excalidraw:latest
```

Update the `image:` line in `deployment.yaml` with the new digest and re-apply:

```bash
kubectl apply -k applications/excalidraw/
kubectl rollout restart deployment/excalidraw -n excalidraw
```

(If Renovate's regex `docker` manager is enabled for this repo, it will open PRs for digest bumps automatically — see [Renovate docs](https://docs.renovatebot.com/docker/).)