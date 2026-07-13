# Cloudflared Tunnel

[Cloudflared Tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/) creates a secure, encrypted connection from Cloudflare's edge to your cluster, allowing you to expose services without opening firewall ports or managing complex networking.

## Setup

1. **Create a Tunnel**:
   - Log in to the Cloudflare dashboard and go to Zero Trust > Networks > Connectors > Cloudflare Tunnels.
   - Create a tunnel and save the token (you'll need it in the next step).
   - Note the tunnel ID.
   - Open the tunnel's **Public Hostname** tab and add a route:
     - **Subdomain**: leave empty to match the wildcard, or set the specific subdomain (e.g. `helloworld`)
     - **Domain**: `your-domain.com` (replace with your domain)
     - **Service**: `https://cilium-gateway-cloudflare-gateway.cloudflare.svc.cluster.local:443`
   - Under **Additional application settings** → **TLS**:
     - Enable **No TLS Verify** (the gateway uses a cert signed by the internal Vault PKI, which cloudflared does not trust)
     - Enable **Match SNI to Host** (cloudflared defaults to using the service URL as the SNI, which does not match any of the Cilium gateway listener hostnames; this makes cloudflared use the incoming request's `Host` header — e.g. `helloworld.drmarchent.com` — as the SNI so the gateway can route by SNI and present the correct certificate)
   - Under **Additional application settings** → **HTTP Settings**:
     - Leave **HTTP Host header** blank to preserve the original `Host` header
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
