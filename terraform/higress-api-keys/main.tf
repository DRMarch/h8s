# Generates an sk- prefixed API key (sk- + 128 random chars) per consumer in
# higress_api_consumers and pushes it to Vault:
#
#   kubernetes-homelab/higress/api-keys/<consumer>  (field: api-key)
#
# The ExternalSecret and key-auth WasmPlugin that consume the keys are
# rendered from the same list in manifests.tf. Keys are recoverable from
# `terraform output -json api_keys` or from Vault.

locals {
  vault_token_cmd = var.vault_token != "" ? "echo '${var.vault_token}'" : "jq -r '.root_token' ${var.vault_token_file}"

  # Full key = "sk-" + the generated random part.
  api_keys = {
    for name in var.higress_api_consumers : name => "sk-${random_password.api_key[name].result}"
  }
}

resource "random_password" "api_key" {
  for_each = toset(var.higress_api_consumers)
  length   = 128
  special  = false
}

resource "null_resource" "vault_higress_api_key" {
  for_each = toset(var.higress_api_consumers)

  triggers = {
    key_sha256 = sha256(local.api_keys[each.key])
  }

  lifecycle {
    precondition {
      condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", each.key))
      error_message = "Consumer name '${each.key}' must be a lowercase DNS label (e.g. drmarchent): it is used as a Vault path segment, a Kubernetes Secret key, and the key-auth consumer name."
    }
  }

  provisioner "local-exec" {
    environment = {
      HIGRESS_API_KEY = local.api_keys[each.key]
    }

    command = <<-EOT
      set -eu
      TMP_JSON=$(mktemp)
      trap 'rm -f "$TMP_JSON"' EXIT

      # jq escapes the key so it never becomes a shell argument.
      jq -n --arg key "$HIGRESS_API_KEY" '{"api-key":$key}' > "$TMP_JSON"

      # Pipe the payload to a temp file inside the Vault pod.
      kubectl exec -i ${var.vault_pod} -n ${var.vault_namespace} -- \
        /bin/sh -c 'cat > /tmp/higress-api-key.json' < "$TMP_JSON"

      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c \
        'export VAULT_TOKEN="$1"; vault kv put ${var.vault_kv_mount}/higress/api-keys/${each.key} @/tmp/higress-api-key.json; rm -f /tmp/higress-api-key.json' \
        /bin/sh "$VAULT_TOKEN"
    EOT
  }
}

output "api_keys" {
  description = "Generated API key per consumer (sensitive). Retrieve with `terraform output -json api_keys`."
  value = {
    for name in sort(var.higress_api_consumers) : name => local.api_keys[name]
  }
  sensitive = true
}
