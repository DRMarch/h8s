# =============================================================================
# Homelab Secrets — copy to secrets.auto.tfvars and fill in your values
# =============================================================================
# This file is auto-loaded by Terraform (no -var flags needed).
# secrets.auto.tfvars is gitignored — never commit real values.
# =============================================================================

# Vault root token — from `vault operator init` output
# This takes precedence over the legacy vault_token_file variable.
vault_token = "hvs.xxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# GitHub fine-grained PAT for Renovate
# ===================================
# Renovate needs to:
#   1. Clone the repo              → Contents: Read
#   2. Push branches with bumps    → Contents: Write
#   3. Open pull requests          → Pull requests: Write
#
# A read-only PAT will cause Renovate to authenticate successfully but fail
# when pushing, with this error in the Renovate pod logs:
#   "remote: Permission to DRMarch/h8s.git denied to DRMarch."
#   "fatal: unable to access 'https://github.com/DRMarch/h8s.git/': 403"
#
# To create the PAT:
#   1. Go to https://github.com/settings/personal-access-tokens
#   2. Click "Generate new token" → "Fine-grained token"
#   3. Token name: e.g. "renovate-h8s"
#   4. Resource owner: select your account
#   5. Expiration: pick one (rotate before it expires)
#   6. Repository access: "Only select repositories" → pick DRMarch/h8s
#   7. Permissions → Repository permissions:
#        - Contents:        Read and write
#        - Pull requests:   Read and write
#        - Metadata:        Read-only (auto-set, but verify)
#      Leave everything else as "No access".
#   8. Click "Generate token" and copy the value (github_pat_...)
#   9. Paste the token below
github_pat_token = "github_pat_xxxxxxxxxxxxxxxxxxxx"

# Discord webhook URL for Alertmanager cluster alerts
# ====================================================
# Alertmanager sends cluster alerts (node down, pod crashes, disk full, etc.)
# to a Discord channel via webhook.
#
# To create the webhook:
#   1. In Discord: Server Settings → Integrations → Webhooks → New Webhook
#   2. Name: "h8s-alerts"
#   3. Choose the target channel
#   4. Click "Copy Webhook URL"
#   5. Paste the URL below
discord_webhook_url = "https://discord.com/api/webhooks/XXXXXXXXXX/YYYYYYYYYYYYYYYYYYYY"

# Discord webhook URL for model-watch (model add/remove notifications)
model_watch_webhook_url = "https://discord.com/api/webhooks/XXXXXXXXXX/YYYYYYYYYYYYYYYYYYYY"

# OpenCode Go keys for the initial Higress provider pilot.
# These must belong to separate OpenCode Go usage quotas. Both are written to
# kubernetes-homelab/higress/opencode-go and consumed through ESO; never put
# the real values in Git.
opencode_go_api_key_1 = "sk-opencode-go-key-1"
opencode_go_api_key_2 = "sk-opencode-go-key-2"

# OpenRouter API key for the Higress provider bridge. Written to
# kubernetes-homelab/higress/openrouter (field: api-key) and consumed through
# ESO; never put the real value in Git. Leave empty to skip Vault provisioning.
openrouter_api_key = "sk-or-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
