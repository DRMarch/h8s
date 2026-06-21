# ============================================================
# Vault Secrets Provisioning — Authelia + CNPG
# ============================================================
# Provisions secret values in Vault for Authelia (encryption key,
# session secret, HMAC secret, admin password, OIDC client secrets)
# and CNPG (database credentials).
#
# Generated secrets:
#   - authelia/encryption-key        -> encryption-key
#   - authelia/session-secret        -> session-secret
#   - authelia/hmac-secret           -> hmac-secret
#   - authelia/admin-password        -> hash (argon2)
#   - authelia/grafana-oidc          -> client-secret-hash (pbkdf2)
#                                      client-secret-plaintext
#   - cnpg/authelia-user-credentials -> username, password
#
# Requires:
#   - Vault initialised and unsealed
#   - kubectl access to the cluster
#   - VAULT_TOKEN available (or vault_token_file variable set)
# ============================================================

# ---- Random Password Generators ----

resource "random_password" "authelia_encryption_key" {
  length  = 64
  special = false
}

resource "random_password" "authelia_session_secret" {
  length  = 64
  special = false
}

resource "random_password" "authelia_hmac_secret" {
  length  = 64
  special = false
}

resource "random_password" "authelia_admin_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "authelia_grafana_oidc_plaintext" {
  length  = 64
  special = false
}

resource "random_password" "cnpg_authelia_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

# ---- Vault Push: Encryption Key ----

resource "null_resource" "vault_authelia_encryption_key" {
  triggers = {
    value = random_password.authelia_encryption_key.result
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      VAULT_TOKEN=$(jq -r '.root_token' ${var.vault_token_file})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/authelia/encryption-key \
          encryption-key='${random_password.authelia_encryption_key.result}'
      "
    EOT
  }
}

# ---- Vault Push: Session Secret ----

resource "null_resource" "vault_authelia_session_secret" {
  triggers = {
    value = random_password.authelia_session_secret.result
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      VAULT_TOKEN=$(jq -r '.root_token' ${var.vault_token_file})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/authelia/session-secret \
          session-secret='${random_password.authelia_session_secret.result}'
      "
    EOT
  }
}

# ---- Vault Push: HMAC Secret ----

resource "null_resource" "vault_authelia_hmac_secret" {
  triggers = {
    value = random_password.authelia_hmac_secret.result
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      VAULT_TOKEN=$(jq -r '.root_token' ${var.vault_token_file})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/authelia/hmac-secret \
          hmac-secret='${random_password.authelia_hmac_secret.result}'
      "
    EOT
  }
}

# ---- Vault Push: Admin Password (argon2 hashed) ----

resource "null_resource" "vault_authelia_admin_password" {
  triggers = {
    password = random_password.authelia_admin_password.result
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      # Authelia 4.39+ requires authentication_backend.file to be configured
      # for the `crypto hash generate` subcommand. Mount a minimal stub config
      # so the CLI loads; the file path is unused by hash generation itself.
      TMP_CONFIG=$(mktemp)
      trap 'rm -f "$TMP_CONFIG"' EXIT
      cat > "$TMP_CONFIG" <<EOF
      authentication_backend:
        file:
          path: /dev/null
      EOF

      if ! RAW=$(docker run --rm \
          -v "$TMP_CONFIG:/config/configuration.yml:ro" \
          ${var.authelia_docker_image} \
          authelia crypto hash generate argon2 \
          --password '${random_password.authelia_admin_password.result}' \
          --no-confirm 2>&1); then
        echo "ERROR: authelia crypto hash generate (argon2) failed. Output:" >&2
        echo "$RAW" >&2
        exit 1
      fi
      HASH=$(echo "$RAW" | sed -n 's/^Digest: //p' | tr -d '\r\n ')

      case "$HASH" in
        '$'*) ;;
        *) echo "ERROR: authelia admin password hash invalid. Raw output:" >&2
           echo "$RAW" >&2
           echo "Extracted hash: '$HASH'" >&2
           exit 1 ;;
      esac
      if echo "$HASH" | grep -q ' '; then
        echo "ERROR: authelia admin password hash contains whitespace: $HASH" >&2
        exit 1
      fi

      VAULT_TOKEN=$(jq -r '.root_token' ${var.vault_token_file})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/authelia/admin-password \
          hash='$HASH'
      "
    EOT
  }
}

# ---- Vault Push: Grafana OIDC (pbkdf2 hash + plaintext) ----

resource "null_resource" "vault_authelia_grafana_oidc" {
  triggers = {
    plaintext = random_password.authelia_grafana_oidc_plaintext.result
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      # Authelia 4.39+ requires authentication_backend.file to be configured
      # for the `crypto hash generate` subcommand. Mount a minimal stub config
      # so the CLI loads; the file path is unused by hash generation itself.
      TMP_CONFIG=$(mktemp)
      trap 'rm -f "$TMP_CONFIG"' EXIT
      cat > "$TMP_CONFIG" <<EOF
      authentication_backend:
        file:
          path: /dev/null
      EOF

      if ! RAW=$(docker run --rm \
          -v "$TMP_CONFIG:/config/configuration.yml:ro" \
          ${var.authelia_docker_image} \
          authelia crypto hash generate pbkdf2 \
          --password '${random_password.authelia_grafana_oidc_plaintext.result}' \
          --no-confirm 2>&1); then
        echo "ERROR: authelia crypto hash generate (pbkdf2) failed. Output:" >&2
        echo "$RAW" >&2
        exit 1
      fi
      HASH=$(echo "$RAW" | sed -n 's/^Digest: //p' | tr -d '\r\n ')

      case "$HASH" in
        '$'*) ;;
        *) echo "ERROR: grafana OIDC client secret hash invalid. Raw output:" >&2
           echo "$RAW" >&2
           echo "Extracted hash: '$HASH'" >&2
           exit 1 ;;
      esac
      if echo "$HASH" | grep -q ' '; then
        echo "ERROR: grafana OIDC client secret hash contains whitespace: $HASH" >&2
        exit 1
      fi

      VAULT_TOKEN=$(jq -r '.root_token' ${var.vault_token_file})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/authelia/grafana-oidc \
          client-secret-hash='$HASH' \
          client-secret-plaintext='${random_password.authelia_grafana_oidc_plaintext.result}'
      "
    EOT
  }
}

# ---- Vault Push: CNPG Authelia Credentials ----

resource "null_resource" "vault_cnpg_authelia_credentials" {
  triggers = {
    password = random_password.cnpg_authelia_password.result
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      VAULT_TOKEN=$(jq -r '.root_token' ${var.vault_token_file})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/cnpg/authelia-user-credentials \
          username=authelia \
          password='${random_password.cnpg_authelia_password.result}'
      "
    EOT
  }
}

# ---- Outputs (plaintext values for reference) ----

output "authelia_admin_password" {
  value     = random_password.authelia_admin_password.result
  sensitive = true
}

output "grafana_oidc_client_secret" {
  value     = random_password.authelia_grafana_oidc_plaintext.result
  sensitive = true
}

output "cnpg_authelia_password" {
  value     = random_password.cnpg_authelia_password.result
  sensitive = true
}
