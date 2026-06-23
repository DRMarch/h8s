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
