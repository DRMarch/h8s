# Renders the Higress manifests for API keys needed

locals {
  higress_resources_dir = abspath("${path.root}/../../networking/higress/resources")
  consumer_names        = distinct(sort(var.higress_api_consumers))
}

resource "local_file" "api_key_externalsecret" {
  filename = "${local.higress_resources_dir}/api-key-externalsecret.yaml"
  content = templatefile("${path.module}/templates/api-key-externalsecret.yaml.tftpl", {
    consumers = local.consumer_names
  })
}

resource "local_file" "key_auth_wasmplugin" {
  filename = "${local.higress_resources_dir}/wasmplugins/key-auth.yaml"
  content = templatefile("${path.module}/templates/key-auth.yaml.tftpl", {
    consumers = local.consumer_names
  })
}
