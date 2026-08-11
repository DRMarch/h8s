# ============================================================
# Vault Secrets Provisioning — Authelia + CNPG + Renovate + Bytestash + SearXNG + MLflow
# ============================================================
# Provisions secret values in Vault for Authelia (encryption key,
# session secret, HMAC secret, admin password, OIDC client secrets),
# CNPG (database credentials), the Renovate GitHub App, ByteStash
# (JWT secret, OIDC client secret), SearXNG (secret key, metrics),
# and MLflow (OIDC client secret, session key).
#
# Generated secrets:
#   - authelia/encryption-key        -> encryption-key
#   - authelia/session-secret        -> session-secret
#   - authelia/hmac-secret           -> hmac-secret
#   - authelia/admin-password        -> hash (argon2)
#   - authelia/grafana-oidc          -> client-secret-hash (pbkdf2)
#                                      client-secret-plaintext
#   - authelia/endurain-oidc         -> client-secret-hash (pbkdf2)
#                                      client-secret-plaintext
#   - authelia/bytestash-oidc        -> client-secret-hash (pbkdf2)
#                                      client-secret-plaintext
#   - authelia/argocd-oidc           -> client-secret-hash (pbkdf2)
#                                      client-secret-plaintext
#   - authelia/mlflow-oidc           -> client-secret-hash (pbkdf2)
#                                      client-secret-plaintext
#   - authelia/openwebui-oidc        -> client-secret-hash (pbkdf2)
#                                      client-secret-plaintext
#   - openwebui/secret-key           -> secret-key
#   - mlflow/oidc                    -> secret-key
#   - garage/mlflow-garage-credentials -> access-key-id
#                                        secret-access-key
#   - cnpg/authelia-user-credentials -> username, password
#   - endurain/fernet-key            -> fernet_key  (url-safe base64, 44 chars)
#   - endurain/secret-key            -> secret_key  (url-safe base64, 44 chars)
#   - endurain/admin-credentials     -> username, password
#   - bytestash/jwt                  -> secret, token-expiry
#   - bytestash/oidc                 -> client-secret-plaintext
#   - renovate/github                -> token (GitHub fine-grained PAT)
#   - searxng/searxng-secret         -> SECRET, METRICS_PASSWORD, METRICS_USERNAME
#
# Bring-your-own secrets (via secrets.auto.tfvars):
#   - vault_token, github_pat_token
#
# Requires:
#   - Vault initialised and unsealed
#   - kubectl access to the cluster
#   - secrets.auto.tfvars (or vault_token_file + -var flags)
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

resource "random_password" "authelia_guest_password" {
  length  = 12
  special = false
}

resource "random_password" "authelia_grafana_oidc_plaintext" {
  length  = 64
  special = false
}

resource "random_password" "authelia_endurain_oidc_plaintext" {
  length  = 64
  special = false
}

resource "random_password" "authelia_bytestash_oidc_plaintext" {
  length  = 64
  special = false
}

resource "random_password" "authelia_argocd_oidc_plaintext" {
  length  = 64
  special = false
}

resource "random_password" "bytestash_jwt_secret" {
  length  = 64
  special = false
}

resource "random_password" "searxng_secret_key" {
  length  = 64
  special = false
}

resource "random_password" "searxng_metrics_password" {
  length  = 32
  special = false
}

resource "random_password" "mlflow_oidc_secret_key" {
  length  = 64
  special = false
}

resource "random_password" "authelia_mlflow_oidc_plaintext" {
  length  = 64
  special = false
}

resource "random_password" "authelia_openwebui_oidc_plaintext" {
  length  = 64
  special = false
}

resource "random_password" "openwebui_secret_key" {
  length  = 64
  special = false
}

resource "random_password" "cnpg_authelia_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

resource "random_password" "endurain_admin_password" {
  length           = 32
  special          = true
  override_special = "!#%&*()-_=+[]{}<>?"
}

# Endurain application secrets. The previous setup used the
# `kubernetes-secret-generator` annotation on the Secret manifest, but
# that chart only generates a fixed-length random string and has no
# per-key type awareness — it produced a 40-char random string for
# `fernet_key` which Fernet rejects (`ValueError: Fernet key must be 32
# url-safe base64-encoded bytes`). These resources generate the
# correct format: 32 random bytes, base64url-encoded (= 44 chars with
# the `=` padding, which Fernet accepts).
resource "random_bytes" "endurain_fernet_key" {
  length = 32
}

resource "random_bytes" "endurain_secret_key" {
  length = 32
}

locals {
  # `random_bytes` exposes `.base64` directly (standard base64 with
  # '+', '/' and '='). Fernet requires the url-safe alphabet, so swap
  # '+' -> '-' and '/' -> '_'. The trailing '=' padding is preserved
  # and accepted by Fernet.
  endurain_fernet_key_b64 = replace(
    replace(
      random_bytes.endurain_fernet_key.base64,
      "+", "-",
    ),
    "/", "_",
  )
  endurain_secret_key_b64 = replace(
    replace(
      random_bytes.endurain_secret_key.base64,
      "+", "-",
    ),
    "/", "_",
  )

  # Resolve the Vault token — prefer direct vault_token, fall back to vault_token_file
  vault_token_cmd = var.vault_token != "" ? "echo '${var.vault_token}'" : "jq -r '.root_token' ${var.vault_token_file}"
}

# ---- Vault Push: Encryption Key ----

resource "null_resource" "vault_authelia_encryption_key" {
  triggers = {
    value = random_password.authelia_encryption_key.result
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      VAULT_TOKEN=$(${local.vault_token_cmd})
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
      VAULT_TOKEN=$(${local.vault_token_cmd})
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
      VAULT_TOKEN=$(${local.vault_token_cmd})
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

      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/authelia/admin-password \
          hash='$HASH'
      "
    EOT
  }
}

# ---- Vault Push: Guest Password (argon2 hashed) ----

resource "null_resource" "vault_authelia_guest_password" {
  triggers = {
    password = random_password.authelia_guest_password.result
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
          --password '${random_password.authelia_guest_password.result}' \
          --no-confirm 2>&1); then
        echo "ERROR: authelia crypto hash generate (argon2) for guest failed. Output:" >&2
        echo "$RAW" >&2
        exit 1
      fi
      HASH=$(echo "$RAW" | sed -n 's/^Digest: //p' | tr -d '\r\n ')

      case "$HASH" in
        '$'*) ;;
        *) echo "ERROR: authelia guest password hash invalid. Raw output:" >&2
           echo "$RAW" >&2
           echo "Extracted hash: '$HASH'" >&2
           exit 1 ;;
      esac
      if echo "$HASH" | grep -q ' '; then
        echo "ERROR: authelia guest password hash contains whitespace: $HASH" >&2
        exit 1
      fi

      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/authelia/guest-password \
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

      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/authelia/grafana-oidc \
          client-secret-hash='$HASH' \
          client-secret-plaintext='${random_password.authelia_grafana_oidc_plaintext.result}'
      "
    EOT
  }
}

# ---- Vault Push: Endurain OIDC (pbkdf2 hash + plaintext) ----

resource "null_resource" "vault_authelia_endurain_oidc" {
  triggers = {
    plaintext = random_password.authelia_endurain_oidc_plaintext.result
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
          --password '${random_password.authelia_endurain_oidc_plaintext.result}' \
          --no-confirm 2>&1); then
        echo "ERROR: authelia crypto hash generate (pbkdf2) failed. Output:" >&2
        echo "$RAW" >&2
        exit 1
      fi
      HASH=$(echo "$RAW" | sed -n 's/^Digest: //p' | tr -d '\r\n ')

      case "$HASH" in
        '$'*) ;;
        *) echo "ERROR: endurain OIDC client secret hash invalid. Raw output:" >&2
           echo "$RAW" >&2
           echo "Extracted hash: '$HASH'" >&2
           exit 1 ;;
      esac
      if echo "$HASH" | grep -q ' '; then
        echo "ERROR: endurain OIDC client secret hash contains whitespace: $HASH" >&2
        exit 1
      fi

      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/authelia/endurain-oidc \
          client-secret-hash='$HASH' \
          client-secret-plaintext='${random_password.authelia_endurain_oidc_plaintext.result}'
      "
    EOT
  }
}

# ---- Vault Push: ByteStash OIDC (pbkdf2 hash + plaintext) ----

resource "null_resource" "vault_authelia_bytestash_oidc" {
  triggers = {
    plaintext = random_password.authelia_bytestash_oidc_plaintext.result
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
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
          --password '${random_password.authelia_bytestash_oidc_plaintext.result}' \
          --no-confirm 2>&1); then
        echo "ERROR: authelia crypto hash generate (pbkdf2) for bytestash failed. Output:" >&2
        echo "$RAW" >&2
        exit 1
      fi
      HASH=$(echo "$RAW" | sed -n 's/^Digest: //p' | tr -d '\r\n ')

      case "$HASH" in
        '$'*) ;;
        *) echo "ERROR: bytestash OIDC client secret hash invalid. Raw output:" >&2
           echo "$RAW" >&2
           echo "Extracted hash: '$HASH'" >&2
           exit 1 ;;
      esac
      if echo "$HASH" | grep -q ' '; then
        echo "ERROR: bytestash OIDC client secret hash contains whitespace: $HASH" >&2
        exit 1
      fi

      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/authelia/bytestash-oidc \
          client-secret-hash='$HASH' \
          client-secret-plaintext='${random_password.authelia_bytestash_oidc_plaintext.result}'
      "
    EOT
  }
}

# ---- Vault Push: ByteStash JWT Secret ----

resource "null_resource" "vault_bytestash_jwt" {
  triggers = {
    secret = random_password.bytestash_jwt_secret.result
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/bytestash/jwt \
          secret='${random_password.bytestash_jwt_secret.result}' \
          token-expiry=24h
      "
    EOT
  }
}

# ---- Vault Push: ByteStash OIDC Client Secret ----

resource "null_resource" "vault_bytestash_oidc" {
  triggers = {
    plaintext = random_password.authelia_bytestash_oidc_plaintext.result
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/bytestash/oidc \
          client-secret-plaintext='${random_password.authelia_bytestash_oidc_plaintext.result}'
      "
    EOT
  }
}

# ---- Vault Push: ArgoCD OIDC (pbkdf2 hash + plaintext) ----

resource "null_resource" "vault_authelia_argocd_oidc" {
  triggers = {
    plaintext = random_password.authelia_argocd_oidc_plaintext.result
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
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
          --password '${random_password.authelia_argocd_oidc_plaintext.result}' \
          --no-confirm 2>&1); then
        echo "ERROR: authelia crypto hash generate (pbkdf2) for argocd failed. Output:" >&2
        echo "$RAW" >&2
        exit 1
      fi
      HASH=$(echo "$RAW" | sed -n 's/^Digest: //p' | tr -d '\r\n ')

      case "$HASH" in
        '$'*) ;;
        *) echo "ERROR: argocd OIDC client secret hash invalid. Raw output:" >&2
           echo "$RAW" >&2
           echo "Extracted hash: '$HASH'" >&2
           exit 1 ;;
      esac
      if echo "$HASH" | grep -q ' '; then
        echo "ERROR: argocd OIDC client secret hash contains whitespace: $HASH" >&2
        exit 1
      fi

      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/authelia/argocd-oidc \
          client-secret-hash='$HASH' \
          client-secret-plaintext='${random_password.authelia_argocd_oidc_plaintext.result}'
      "
    EOT
  }
}

# ---- Vault Push: SearXNG Secret ----

resource "null_resource" "vault_searxng_secret" {
  triggers = {
    secret           = random_password.searxng_secret_key.result
    metrics_password = random_password.searxng_metrics_password.result
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/searxng/searxng-secret \
          SECRET='${random_password.searxng_secret_key.result}' \
          METRICS_PASSWORD='${random_password.searxng_metrics_password.result}' \
          METRICS_USERNAME='prometheus'
      "
    EOT
  }
}

# ---- Vault Push: MLflow OIDC Session Secret Key ----

resource "null_resource" "vault_mlflow_oidc_secret_key" {
  triggers = {
    value = random_password.mlflow_oidc_secret_key.result
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/mlflow/oidc \
          secret-key='${random_password.mlflow_oidc_secret_key.result}'
      "
    EOT
  }
}

# ---- Vault Push: MLflow Authelia OIDC (pbkdf2 hash + plaintext) ----

resource "null_resource" "vault_authelia_mlflow_oidc" {
  triggers = {
    plaintext = random_password.authelia_mlflow_oidc_plaintext.result
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
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
          --password '${random_password.authelia_mlflow_oidc_plaintext.result}' \
          --no-confirm 2>&1); then
        echo "ERROR: authelia crypto hash generate (pbkdf2) for mlflow failed. Output:" >&2
        echo "$RAW" >&2
        exit 1
      fi
      HASH=$(echo "$RAW" | sed -n 's/^Digest: //p' | tr -d '\r\n ')

      case "$HASH" in
        '$'*) ;;
        *) echo "ERROR: mlflow OIDC client secret hash invalid. Raw output:" >&2
           echo "$RAW" >&2
           echo "Extracted hash: '$HASH'" >&2
           exit 1 ;;
      esac
      if echo "$HASH" | grep -q ' '; then
        echo "ERROR: mlflow OIDC client secret hash contains whitespace: $HASH" >&2
        exit 1
      fi

      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/authelia/mlflow-oidc \
          client-secret-hash='$HASH' \
          client-secret-plaintext='${random_password.authelia_mlflow_oidc_plaintext.result}'
      "
    EOT
  }
}

# ---- Vault Push: Open WebUI Authelia OIDC (pbkdf2 hash + plaintext) ----

resource "null_resource" "vault_authelia_openwebui_oidc" {
  triggers = {
    plaintext = random_password.authelia_openwebui_oidc_plaintext.result
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
          --password '${random_password.authelia_openwebui_oidc_plaintext.result}' \
          --no-confirm 2>&1); then
        echo "ERROR: authelia crypto hash generate (pbkdf2) for open-webui failed. Output:" >&2
        echo "$RAW" >&2
        exit 1
      fi
      HASH=$(echo "$RAW" | sed -n 's/^Digest: //p' | tr -d '
 ')

      case "$HASH" in
        '$'*) ;;
        *) echo "ERROR: open-webui OIDC client secret hash invalid. Raw output:" >&2
           echo "$RAW" >&2
           echo "Extracted hash: '$HASH'" >&2
           exit 1 ;;
      esac
      if echo "$HASH" | grep -q ' '; then
        echo "ERROR: open-webui OIDC client secret hash contains whitespace: $HASH" >&2
        exit 1
      fi

      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/authelia/openwebui-oidc \
          client-secret-hash='$HASH' \
          client-secret-plaintext='${random_password.authelia_openwebui_oidc_plaintext.result}'
      "
    EOT
  }
}

# ---- Vault Push: Open WebUI WEBUI_SECRET_KEY ----

resource "null_resource" "vault_openwebui_secret_key" {
  triggers = {
    value = random_password.openwebui_secret_key.result
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/openwebui/secret-key \
          secret-key='${random_password.openwebui_secret_key.result}'
      "
    EOT
  }
}

resource "random_password" "garage_mlflow_access_key_id" {
  length  = 20
  special = false
}

resource "random_password" "garage_mlflow_secret_access_key" {
  length  = 64
  special = false
}

resource "null_resource" "vault_garage_mlflow_creds" {
  triggers = {
    access = random_password.garage_mlflow_access_key_id.result
    secret = random_password.garage_mlflow_secret_access_key.result
  }
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/garage/mlflow-garage-credentials \
          access-key-id='GK${random_password.garage_mlflow_access_key_id.result}' \
          secret-access-key='${random_password.garage_mlflow_secret_access_key.result}'
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
      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/cnpg/authelia-user-credentials \
          username=authelia \
          password='${random_password.cnpg_authelia_password.result}'
      "
    EOT
  }
}

# ---- Vault Push: Endurain Fernet Key ----

resource "null_resource" "vault_endurain_fernet_key" {
  triggers = {
    value = local.endurain_fernet_key_b64
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/endurain/fernet-key \
          fernet_key='${local.endurain_fernet_key_b64}'
      "
    EOT
  }
}

# ---- Vault Push: Endurain Session Secret Key ----

resource "null_resource" "vault_endurain_secret_key" {
  triggers = {
    value = local.endurain_secret_key_b64
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/endurain/secret-key \
          secret_key='${local.endurain_secret_key_b64}'
      "
    EOT
  }
}

# ---- Vault Push: Endurain Admin Credentials ----

resource "null_resource" "vault_endurain_admin_credentials" {
  triggers = {
    password = random_password.endurain_admin_password.result
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/endurain/admin-credentials \
          username='admin' \
          password='${random_password.endurain_admin_password.result}'
      "
    EOT
  }
}

# ---- Vault Push: Renovate GitHub PAT ----

resource "null_resource" "vault_github_pat" {
  triggers = {
    token = var.github_pat_token
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/renovate/github \
          token='${var.github_pat_token}'
      "
    EOT
  }
}

# ---- Vault Push: Alertmanager Discord Webhook ----

resource "null_resource" "vault_alertmanager_discord_webhook" {
  triggers = {
    url = var.discord_webhook_url
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/alertmanager/discord-webhook \
          url='${var.discord_webhook_url}'
      "
    EOT
  }
}

# ---- Vault Push: OpenCode Go API Keys for Higress ----
#
# These are intentionally supplied as bring-your-own variables rather than
# generated by Terraform. The Higress WasmPlugin references the resulting ESO
# Secret with ${secret.higress-system/higress-opencode-go.api-token-1} and
# ${secret.higress-system/higress-opencode-go.api-token-2}.
#
# Keep both keys in independent OpenCode Go usage quotas. If both variables
# are empty, this resource is skipped so the workspace remains usable before
# the provider is configured. A partially configured pair fails validation.
resource "null_resource" "vault_higress_opencode_go" {
  count = trimspace(var.opencode_go_api_key_1) == "" && trimspace(var.opencode_go_api_key_2) == "" ? 0 : 1

  # Do not persist the raw API keys in Terraform triggers/state. The hashes
  # only detect rotation; the values are passed through the provisioner's
  # environment and a temporary stdin payload instead.
  triggers = {
    api_token_1_sha256 = sha256(var.opencode_go_api_key_1)
    api_token_2_sha256 = sha256(var.opencode_go_api_key_2)
  }

  lifecycle {
    precondition {
      condition     = trimspace(var.opencode_go_api_key_1) != "" && trimspace(var.opencode_go_api_key_2) != ""
      error_message = "Set both opencode_go_api_key_1 and opencode_go_api_key_2, or leave both empty to skip Vault provisioning."
    }
  }

  provisioner "local-exec" {
    environment = {
      OPENCODE_GO_API_KEY_1 = var.opencode_go_api_key_1
      OPENCODE_GO_API_KEY_2 = var.opencode_go_api_key_2
    }

    command = <<-EOT
      set -eu
      TMP_JSON=$(mktemp)
      trap 'rm -f "$TMP_JSON"' EXIT

      # jq performs JSON escaping; keys never become shell command arguments.
      jq -n \
        --arg token1 "$OPENCODE_GO_API_KEY_1" \
        --arg token2 "$OPENCODE_GO_API_KEY_2" \
        '{"api-token-1":$token1,"api-token-2":$token2}' > "$TMP_JSON"

      # Send the payload over kubectl exec stdin, then let Vault read it from
      # a short-lived file inside the Vault pod. The raw keys are not present
      # in the kubectl command line or Terraform resource triggers.
      kubectl exec -i ${var.vault_pod} -n ${var.vault_namespace} -- \
        /bin/sh -c 'cat > /tmp/higress-opencode-go.json' < "$TMP_JSON"

      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c \
        'export VAULT_TOKEN="$1"; vault kv put ${var.vault_kv_mount}/higress/opencode-go @/tmp/higress-opencode-go.json; rm -f /tmp/higress-opencode-go.json' \
        /bin/sh "$VAULT_TOKEN"
    EOT
  }
}

# ---- Outputs (plaintext values for reference) ----

output "authelia_admin_password" {
  value     = random_password.authelia_admin_password.result
  sensitive = true
}

output "authelia_guest_password" {
  value     = random_password.authelia_guest_password.result
  sensitive = true
}

output "grafana_oidc_client_secret" {
  value     = random_password.authelia_grafana_oidc_plaintext.result
  sensitive = true
}

output "endurain_oidc_client_secret" {
  value     = random_password.authelia_endurain_oidc_plaintext.result
  sensitive = true
}

output "bytestash_oidc_client_secret" {
  value     = random_password.authelia_bytestash_oidc_plaintext.result
  sensitive = true
}

output "argocd_oidc_client_secret" {
  value     = random_password.authelia_argocd_oidc_plaintext.result
  sensitive = true
}

output "cnpg_authelia_password" {
  value     = random_password.cnpg_authelia_password.result
  sensitive = true
}

output "endurain_fernet_key" {
  value     = local.endurain_fernet_key_b64
  sensitive = true
}

output "endurain_secret_key" {
  value     = local.endurain_secret_key_b64
  sensitive = true
}

output "endurain_admin_password" {
  value     = random_password.endurain_admin_password.result
  sensitive = true
}

output "searxng_secret_key" {
  value     = random_password.searxng_secret_key.result
  sensitive = true
}

output "searxng_metrics_password" {
  value     = random_password.searxng_metrics_password.result
  sensitive = true
}

output "openwebui_oidc_client_secret" {
  value     = random_password.authelia_openwebui_oidc_plaintext.result
  sensitive = true
}

output "openwebui_secret_key" {
  value     = random_password.openwebui_secret_key.result
  sensitive = true
}
