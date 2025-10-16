locals {
  last_updated = formatdate("YYYY-MM-DD", plantimestamp())
  project_root = ".."
  kubernetes_domain_escaped = replace(var.kubernetes_domain, ".", "\\.")
}