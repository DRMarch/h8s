# Cloudflared Tunnel

[Cloudflared Tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/) creates a secure, encrypted connection from Cloudflare's edge to your cluster, allowing you to expose services without opening firewall ports or managing complex networking.

## Setup

1. **Create a Tunnel**:
   - Log in to the Cloudflare dashboard and go to Zero Trust > Networks > Connectors > Cloudflare Tunnels.
   - Create a tunnel and save the token (you'll need it in the next step).
   - Note the tunnel ID.
   - Open the tunnel's **Published application routes** and add a route:
     - **Domain**: `*.your-domain.com` (replace with your domain)
     - **Service**: `cilium-gateway-cloudflare-gateway.cloudflare.svc.cluster.local:80`
   - Configure a CNAME DNS record:
     - **Host**: `*`
     - **Target**: `<TUNNEL_ID>.cfargotunnel.com` (replace `<TUNNEL_ID>` with your tunnel ID)

2. **Store the Token**: Add the token to Vault for secure storage:
   ```bash
   export CLOUDFLARE_TUNNEL_TOKEN="<your-token>"
   vault kv put kubernetes-homelab/cloudflare/tunnel private-key="$CLOUDFLARE_TUNNEL_TOKEN"
   ```

3. **Deploy**: Apply the manifests to your cluster:
   ```bash
   kubectl apply -k networking/cloudflared
   ```

## Resources

- **deployment.yaml**: DaemonSet that runs cloudflared on every node with metrics exposed on port 2000
- **service.yaml**: Headless Service exposing the metrics endpoint
- **service-monitor.yaml**: ServiceMonitor for Prometheus scraping cloudflared tunnel metrics
- **token-secret.yaml**: ExternalSecret that pulls the token from Vault
