# MCP Memory Service

Self-hosted memory backend ([doobidoo/mcp-memory-service](https://github.com/doobidoo/mcp-memory-service), Apache-2.0). One process serves the dashboard, REST API and MCP endpoint on port 8000.

## Access

| Path | Auth |
|---|---|
| `https://memory.drmarchent.com/` (dashboard + REST API) | Authelia forward-auth, `group:admins` only |
| `https://llm.drmarchent.com/mcp/servers/memory-service` (MCP) | Higress `key-auth` |

Agents with a Higress key read and write the same memories the dashboard shows.

## Usage

```bash
# Health
kubectl -n memory-service exec deploy/memory-service -- \
  curl -sf http://localhost:8000/api/health

# Logs / status
kubectl -n memory-service logs deploy/memory-service -f
kubectl -n memory-service get pods

# MCP tool discovery through Higress
curl -s -X POST https://llm.drmarchent.com/mcp/servers/memory-service \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <higress-key>" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
```

## Configuration

- Embeddings: local ONNX `all-MiniLM-L6-v2` (384 dims), english only.
