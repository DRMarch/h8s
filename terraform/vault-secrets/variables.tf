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
  description = "Path to file containing the Vault root token (JSON with .root_token key)"
  type        = string
}

variable "authelia_docker_image" {
  description = "Authelia Docker image used for crypto hash generation"
  type        = string
  default     = "ghcr.io/authelia/authelia:latest"
}
