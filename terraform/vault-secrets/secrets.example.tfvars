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
# Create at: https://github.com/settings/personal-access-tokens
# Required permissions: Contents (read & write), Pull requests (read & write),
# Metadata (read-only). Set repository access to your h8s repo.
github_pat_token = "github_pat_xxxxxxxxxxxxxxxxxxxx"
