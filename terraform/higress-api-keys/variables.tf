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

variable "higress_external_api_consumers" {
  description = "key-auth consumer names allowed on the EXTERNAL (public) domain, e.g. llm.drmarchent.com (lowercase DNS labels). Each name gets a generated key (sk- + 128 random chars) pushed to Vault at kubernetes-homelab/higress/api-keys/<name>; the ExternalSecret and key-auth WasmPlugin manifests are rendered from these lists. Names are not secret — they appear in the manifests."
  type        = list(string)
  default     = ["domain-admin", "opencode"]
}

variable "higress_internal_api_consumers" {
  description = "key-auth consumer names allowed on the INTERNAL domain (higress-internal.higress-system.svc.cluster.local), used by in-cluster apps such as Open WebUI and model-watch. Same key generation/Vault semantics as higress_external_api_consumers; the two lists scope each key to its own domain."
  type        = list(string)
  default     = ["open-webui", "model-watch"]
}
