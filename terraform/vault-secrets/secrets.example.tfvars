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
