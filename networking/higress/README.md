# Higress

This directory contains the Higress configuration that exposes OpenCode Go and OpenRouter (free models only) through an OpenAI-compatible API on the LAN. Cilium provides the external gateway and TLS termination; Higress forwards requests to the providers and manages provider-token selection and failover.

```text
LAN client
  -> Cilium lan-gateway (`llm.drmarchent.com`)
  -> Higress gateway Service
  -> model-router (provider header + model rewrite)
  -> transformer (maps session header -> `x-opencode-session` for OpenCode backends)
  -> provider Ingress (header match `higress.io/exact-match-header-...`)
       -> McpBridge DNS registry (`opencode-{go,zen}.dns` / `openrouter.dns`)
  -> Higress AI Proxy (rewrites to `https://opencode.ai/zen/{go,}v1` / `https://openrouter.ai/api/v1`)
  -> OpenCode Go (`https://opencode.ai`) / OpenRouter (`https://openrouter.ai`)
```

Provider routing uses Ingresses whose backend is the McpBridge resource and
whose `higress.io/destination` points at the DNS-registry ServiceEntries (`opencode-go.dns` / `opencode-zen.dns` / `openrouter.dns`), so the ai-proxy rewrite is sent straight to the provider over TLS — no loopback through the gateway. (Gateway API `Hostname` backends are not resolvable by the Higress 2.2.3 controller.)

## Provider credentials

Two OpenCode Go credentials are supplied through Vault and synchronized with ESO. Higress references the resulting Kubernetes Secret without storing the raw values in Git.

```text
Vault path: kubernetes-homelab/higress/opencode-go

Fields:
  api-token-1
  api-token-2
```

The credentials are configured through the Terraform variables `opencode_go_api_key_1` and `opencode_go_api_key_2` in the ignored `terraform/vault-secrets/secrets.auto.tfvars` file. Both values must be supplied before the Higress resources synchronize.

Higress rotates between the credentials and pulls one out of rotation on auth failures, `429`s or configured upstream failures.

### OpenRouter (free models)

A single OpenRouter credential is supplied through Vault and synchronized with ESO:

```text
Vault path: kubernetes-homelab/higress/openrouter

Fields:
  api-key
```

Configured through the Terraform variable `openrouter_api_key` in the ignored `terraform/vault-secrets/secrets.auto.tfvars` file. Set it before the Higress resources synchronize.

OpenRouter models are exposed with the `or/` prefix and filtered by the model-aggregator to only list models whose id ends in `:free` (e.g. `or/meta-llama/llama-3.3-70b-instruct:free`). The filter only affects the `/v1/models` listing — a client that already knows a paid `or/<model>` id can still route to it.

## Session headers & affinity

OpenCode Go/Zen require a per-conversation `x-opencode-session` header — native OpenCode clients send it, and OpenCode Go returns `503` without it. OpenRouter uses the same concept natively as `x-session-id` for sticky routing and session grouping in its Logs view.

The gateway unifies both on the client-facing `X-Session-Id` header:

- [`transformer-session-header.yaml`](./resources/wasmplugins/transformer-session-header.yaml) maps `X-Session-Id` (and OpenCode's native `x-session-affinity`) onto `x-opencode-session` for the `opencode-go.dns` / `opencode-zen.dns` backends only. OpenRouter traffic passes through untouched — OpenRouter reads `x-session-id` directly.
- Open WebUI sends `X-Session-Id: <chat-uuid>` on every request via the `OPENAI_API_CONFIGS` connection header (see [`applications/open-webui/helm/values.yaml`](../../applications/open-webui/helm/values.yaml)). The chat id is stable for the life of a conversation (a new chat gets a new id), so Go/Zen sees one consistent session and OpenRouter groups the whole chat under it.
- ai-statistics keys its telemetry on `x-session-id`, so the same value drives the dashboards.

The session value is client-created and opaque; the gateway only relays or maps it and never generates one.

### Account affinity (deferred)

OpenCode Go cached reads are ~30x cheaper than cold input. However this setup uses two `apiTokens` from separate accounts, so Higress picks one at random per request and nothing pins a session to a single credential. Consecutive requests often land on different credentials with cold caches, so you pay the full input rate more often than you should.

Provider-level session affinity is not in Higress yet, but it's on the way: [3840](https://github.com/higress-group/higress/issues/3840) (open; PRs [3921](https://github.com/higress-group/higress/pull/3921) and [4128](https://github.com/higress-group/higress/pull/4128) also relevant). Once available, the two apiTokens can be pinned per session (e.g. hash on `x-opencode-session`) so a conversation stays on one warm account.

## Deployment

Run the `terraform/vault-secrets` workspace after setting the provider credentials. Argo CD then deploys the `higress-helm` and `higress-resources` Applications in order. The resources include the Higress gateway, OpenCode Go and OpenRouter provider bridges, LAN route, ExternalSecrets and AI Proxy WasmPlugins.


## API

The gateway accepts either header for authentication (`x-api-key` matches the `domain-admin` consumer; `Authorization: Bearer <key>` matches the `domain-admin-bearer` consumer in [`resources/wasmplugins/key-auth.yaml`](./resources/wasmplugins/key-auth.yaml)):

```bash
curl https://llm.drmarchent.com/v1/models \
  -H "Authorization: Bearer $HIGRESS_API_KEY"
```

Send a Chat Completions request:

```bash
curl https://llm.drmarchent.com/v1/chat/completions \
  -H "Authorization: Bearer $HIGRESS_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "go/deepseek-v4-flash",
    "messages": [{"role": "user", "content": "Say hello in one sentence."}],
    "stream": false
  }'
```

## OpenCode client

Point [OpenCode](https://opencode.ai) at this gateway by registering Higress as a custom OpenAI-compatible provider. The [`opencode-models-discovery`](https://github.com/yuhp/opencode-models-discovery) plugin queries `/v1/models` at startup and merges the live list into the model picker, so the `models` block does not need to be maintained by hand.

Export the key once per shell (or stash it in your secrets manager):

```bash
echo 'export HIGRESS_API_KEY=<your-api-key>' >> ~/.bashrc
source ~/.bashrc
```

Add the provider and plugin to `~/.config/opencode/opencode.jsonc`:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",

  "plugin": ["opencode-models-discovery@latest"],

  "provider": {
    "higress": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Higress (homelab)",
      "options": {
        "baseURL": "https://llm.drmarchent.com/v1",
        "apiKey": "{env:HIGRESS_API_KEY}",
        "modelsDiscovery": {
          "enabled": true
        }
      }
    }
  },

  "mcp": {
    "higress": {
      "type": "remote",
      "url": "https://llm.drmarchent.com/mcp",
      "headers": { "Authorization": "Bearer {env:HIGRESS_API_KEY}" },
      "oauth": false,
      "enabled": true
    }
  }
}
```

## MCP portal

`https://llm.drmarchent.com/mcp` is a unified Model Context Protocol endpoint, served entirely by Higress wasm plugins (no separate backend):

- `mcp-server` (composed/`toolSet`, on `/mcp`) answers `tools/list` with the merged catalog; tools are exposed as `<server>___<tool>` (e.g. `searxng___searxng_web_search`).
- `mcp-router` (on `/mcp`) rewrites `tools/call` to `/mcp/servers/<server>`, where a second `mcp-server` rule acts as an `mcp-proxy` to the upstream server.
- Auth reuses the domain-level `key-auth` (the `opencode` consumer). Protocol: legacy for OpenCode; searxng-mcp also supports modern.

```text
OpenCode -> llm.drmarchent.com/mcp (Bearer key)
  -> Higress gateway (key-auth FAIL_CLOSE; LLM plugins no-op on MCP JSON-RPC)
  -> wasm mcp-server toolSet answers tools/list; mcp-router forwards tools/call
  -> Ingress /mcp/servers/searxng -> McpBridge dns registry (`searxng-mcp.dns`)
       -> searxng-mcp (http://searxng-mcp.searxng.svc.cluster.local:3000/mcp)
```

The searxng backend is reached through a `McpBridge` dns registry (`searxng-mcp.dns`)
rather than an ExternalName Service: Higress 2.2.x no longer builds Envoy clusters
for `ExternalName` backends, so a direct ExternalName Ingress backend fails with
`503 cluster_not_found`. Registry-backed clusters are always pushed to the gateway,
even with `PILOT_FILTER_GATEWAY_CLUSTER_CONFIG` enabled.

`matchRules.ingress` must contain the Envoy route name. For Ingresses in the
Higress system namespace (as here), the route name is the bare Ingress name
(`mcp-unified`, `mcp-servers-searxng`) — the `namespace/name` form only applies
to Ingresses outside the system namespace.

Adding a backend = one `McpBridge` registry + one `mcp-server` proxy matchRule + one `mcp-router` entry + declared `tools:` metadata (the catalog is static, not auto-discovered).
