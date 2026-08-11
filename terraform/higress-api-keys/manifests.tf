# Renders the Higress manifests for API keys needed

locals {
  higress_resources_dir = abspath("${path.root}/../../networking/higress/resources")
  external_consumers    = distinct(sort(var.higress_external_api_consumers))
  internal_consumers    = distinct(sort(var.higress_internal_api_consumers))
}

resource "local_file" "api_key_externalsecret" {
  filename = "${local.higress_resources_dir}/api-key-externalsecret.yaml"
  content = templatefile("${path.module}/templates/api-key-externalsecret.yaml.tftpl", {
    consumers = local.all_consumers
  })
}

resource "local_file" "key_auth_wasmplugin" {
  filename = "${local.higress_resources_dir}/wasmplugins/key-auth.yaml"
  content = templatefile("${path.module}/templates/key-auth.yaml.tftpl", {
    external_consumers = local.external_consumers
    internal_consumers = local.internal_consumers
  })
}
