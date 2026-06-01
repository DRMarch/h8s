# Cloudflared Tunnel

[Cloudflared Tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/) creates a secure, encrypted connection from Cloudflare's edge to your cluster, allowing you to expose services without opening firewall ports or managing complex networking.

## Setup

1. **Create a Tunnel**: Follow the instructions [here](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/create-remote-tunnel/) to create a tunnel in Cloudflare and get your token.

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
