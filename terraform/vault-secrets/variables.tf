variable "vault_namespace" {
  description = "Kubernetes namespace where Vault is deployed"
  type        = string
  default     = "vault"
}

variable "vault_pod" {
  description = "Name of the Vault pod to exec into"
  type        = string
  default     = "vault-0"
}

variable "vault_kv_mount" {
  description = "Vault KV v2 secrets engine mount path"
  type        = string
  default     = "kubernetes-homelab"
}

variable "vault_token_file" {
  description = "Path to file containing the Vault root token (JSON with .root_token key). Omit if vault_token is set via secrets.auto.tfvars."
  type        = string
  default     = ""
}

variable "authelia_docker_image" {
  description = "Authelia Docker image used for crypto hash generation"
  type        = string
  default     = "ghcr.io/authelia/authelia:latest"
}

# ---- Bring-Your-Own Secrets (populated via secrets.auto.tfvars) ----

variable "vault_token" {
  description = "Vault root token. Set this OR vault_token_file. Takes precedence over vault_token_file."
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_pat_token" {
  description = "GitHub fine-grained PAT for Renovate (Contents r/w, Pull requests r/w, Metadata r/o)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "discord_webhook_url" {
  description = "Discord webhook URL for Alertmanager cluster alerts"
  type        = string
  default     = ""
  sensitive   = true
}

variable "model_watch_webhook_url" {
  description = "Discord webhook URL for model-watch model change notifications. Written to kubernetes-homelab/model-watch/webhook-url (field: url) and consumed by the model-watch CronJob via ESO."
  type        = string
  default     = ""
  sensitive   = true
}

variable "opencode_go_api_key_1" {
  description = "First OpenCode Go API key. Both OpenCode Go keys are written to the same Vault path for Higress token failover."
  type        = string
  default     = ""
  sensitive   = true
}

variable "opencode_go_api_key_2" {
  description = "Second OpenCode Go API key. Both keys should belong to independent usage quotas."
  type        = string
  default     = ""
  sensitive   = true
}
