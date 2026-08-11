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

variable "vault_token" {
  description = "Vault root token. Set this OR vault_token_file. Takes precedence over vault_token_file."
  type        = string
  default     = ""
  sensitive   = true
}

variable "higress_api_consumers" {
  description = "key-auth consumer names (lowercase DNS labels). Each name gets a generated key (sk- + 128 random chars) pushed to Vault at kubernetes-homelab/higress/api-keys/<name>; the ExternalSecret and WasmPlugin manifests are rendered from this list. Names are not secret — they appear in the manifests."
  type        = list(string)
  default     = ["domain-admin"]
}
