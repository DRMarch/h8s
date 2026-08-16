# ============================================================
# Harbor — internal secrets (generated fresh)
# ============================================================
# Harbor's Helm chart generates its internal secrets with Helm `lookup` plus
# `randAlphaNum` / `htpasswd`. Under ArgoCD the chart is rendered with
# `helm template`, where `lookup` always returns empty, so every sync mints
# new values and rolls the Deployments via their checksum/* pod annotations.
#
# We generate every value here instead, store them in Vault, and point the
# chart at a single `harbor-internal-secrets` Secret (see
# storage/harbor/helm/harbor-internal-secrets.yaml). This assumes a FRESH
# Harbor install — regenerating `secretKey` invalidates any previously stored
# Harbor data, so only run this against a wiped cluster.
#
#   kubernetes-homelab/harbor/internal-secrets
#     secret               (16)   core inter-component secret
#     CSRF_KEY             (32)   core CSRF key
#     secretKey            (16)   Harbor encryption key
#     tls.key / tls.crt           token signing key + self-signed cert
#     JOBSERVICE_SECRET    (16)   core<->jobservice secret
#     REGISTRY_HTTP_SECRET (16)   core<->registry secret
#     REGISTRY_PASSWD             internal registry password (plaintext)
#     REGISTRY_HTPASSWD           "harbor_registry_user:<bcrypt>" auth line
# ============================================================

resource "random_password" "harbor_core_secret" {
  length  = 16
  special = false
}

resource "random_password" "harbor_csrf_key" {
  length  = 32
  special = false
}

resource "random_password" "harbor_secret_key" {
  length  = 16
  special = false
}

resource "random_password" "harbor_jobservice_secret" {
  length  = 16
  special = false
}

resource "random_password" "harbor_registry_http_secret" {
  length  = 16
  special = false
}

resource "random_password" "harbor_registry_password" {
  length  = 32
  special = false
}

resource "tls_private_key" "harbor_token" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "harbor_token" {
  private_key_pem = tls_private_key.harbor_token.private_key_pem

  validity_period_hours = 87600 # 10 years

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
  ]

  is_ca_certificate = true

  subject {
    common_name = "harbor-token-ca"
  }
}

resource "null_resource" "vault_harbor_internal_secrets" {
  triggers = {
    secret               = random_password.harbor_core_secret.result
    csrf_key             = random_password.harbor_csrf_key.result
    secret_key           = random_password.harbor_secret_key.result
    jobservice_secret    = random_password.harbor_jobservice_secret.result
    registry_http_secret = random_password.harbor_registry_http_secret.result
    registry_password    = random_password.harbor_registry_password.result
    tls_key              = tls_private_key.harbor_token.private_key_pem
    tls_crt              = tls_self_signed_cert.harbor_token.cert_pem
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      HTPASSWD="$(docker run --rm httpd:2.4 htpasswd -nbB -C 10 harbor_registry_user '${random_password.harbor_registry_password.result}')"
      TMP_JSON="$(mktemp)"
      jq -n \
        --arg secret '${random_password.harbor_core_secret.result}' \
        --arg csrf '${random_password.harbor_csrf_key.result}' \
        --arg secretkey '${random_password.harbor_secret_key.result}' \
        --arg jobservice '${random_password.harbor_jobservice_secret.result}' \
        --arg registryhttp '${random_password.harbor_registry_http_secret.result}' \
        --arg regpasswd '${random_password.harbor_registry_password.result}' \
        --arg htpasswd "$HTPASSWD" \
        --arg tlskey '${tls_private_key.harbor_token.private_key_pem}' \
        --arg tlscrt '${tls_self_signed_cert.harbor_token.cert_pem}' \
        '{"secret":$secret,"CSRF_KEY":$csrf,"secretKey":$secretkey,"JOBSERVICE_SECRET":$jobservice,"REGISTRY_HTTP_SECRET":$registryhttp,"REGISTRY_PASSWD":$regpasswd,"REGISTRY_HTPASSWD":$htpasswd,"tls.key":$tlskey,"tls.crt":$tlscrt}' \
        > "$TMP_JSON"
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -i -- /bin/sh -c 'cat > /tmp/harbor-internal-secrets.json' < "$TMP_JSON"
      VAULT_TOKEN=$(${local.vault_token_cmd})
      kubectl exec ${var.vault_pod} -n ${var.vault_namespace} -- /bin/sh -c "
        export VAULT_TOKEN='$VAULT_TOKEN'
        vault kv put ${var.vault_kv_mount}/harbor/internal-secrets @/tmp/harbor-internal-secrets.json
        rm -f /tmp/harbor-internal-secrets.json
      "
      rm -f "$TMP_JSON"
    EOT
  }
}
