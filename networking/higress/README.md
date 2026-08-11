# Higress

This directory contains the Higress configuration that exposes OpenCode Go through an OpenAI-compatible API on the LAN. Cilium provides the external gateway and TLS termination; Higress forwards requests to OpenCode Go and manages provider-token selection and failover.

```text
LAN client
  -> Cilium lan-gateway (`llm.drmarchent.com`)
  -> Higress gateway Service
  -> model-router (provider header + model rewrite)
  -> provider Ingress (header match `higress.io/exact-match-header-...`)
       -> McpBridge DNS registry (`opencode-{go,zen}.dns`)
  -> Higress AI Proxy (rewrites to `https://opencode.ai/zen/{go,}v1`)
  -> OpenCode Go (`https://opencode.ai`)
```

Provider routing uses Ingresses whose backend is the McpBridge resource and
whose `higress.io/destination` points at the DNS-registry ServiceEntries
(`opencode-go.dns` / `opencode-zen.dns`), so the ai-proxy rewrite is sent
straight to the provider over TLS — no loopback through the gateway. (Gateway
API `Hostname` backends are not resolvable by the Higress 2.2.3 controller.)
```

## Provider credentials

Two OpenCode Go credentials are supplied through Vault and synchronized with ESO. Higress references the resulting Kubernetes Secret without storing the raw values in Git.

```text
Vault path: kubernetes-homelab/higress/opencode-go

Fields:
  api-token-1
  api-token-2
```

The credentials are configured through the Terraform variables `opencode_go_api_key_1` and `opencode_go_api_key_2` in the ignored `terraform/vault-secrets/secrets.auto.tfvars` file. Both values must be supplied before the Higress resources synchronize.

Higress selects between the credentials and temporarily removes a credential from rotation after authentication failures, quota responses (`429`) or configured upstream failures. OpenCode Go usage limits are documented at https://opencode.ai/docs/go/.

## Deployment

Run the `terraform/vault-secrets` workspace after setting both provider credentials. Argo CD then deploys the `higress-helm` and `higress-resources` Applications in order. The resources include the Higress gateway, OpenCode Go provider bridge, LAN route, ExternalSecret and AI Proxy WasmPlugin.


## API

List available OpenCode Go/Zen models (the `x-api-key` header is required on every request):

```bash
curl https://llm.drmarchent.com/v1/models \
  -H 'x-api-key: <your-api-key>'
```

Send a Chat Completions request:

```bash
curl https://llm.drmarchent.com/v1/chat/completions \
  -H 'x-api-key: <your-api-key>' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "go/deepseek-v4-flash",
    "messages": [{"role": "user", "content": "Say hello in one sentence."}],
    "stream": false
  }'
```
