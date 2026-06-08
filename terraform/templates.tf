
resource "local_file" "setup" {
    filename = "${path.module}/${local.project_root}/SETUP.md"
    content = templatefile("${path.module}/templates/SETUP.md.tftpl", {
        last_updated = local.last_updated
        kube_vip_ip  = var.kube_vip_ip
    })
}

##################
## Cert Manager ##
##################
# Certificates
resource "local_file" "certificates_argocd" {
    filename = "${path.module}/${local.project_root}/networking/cert-manager/resources/certificates/argocd-homelab-local.yaml"
    content = templatefile("${path.module}/templates/networking/cert-manager/resources/certificates/argocd-homelab-local.yaml.tftpl", {
        kubernetes_domain = var.kubernetes_domain
    })
}

resource "local_file" "certificates_garage" {
    filename = "${path.module}/${local.project_root}/networking/cert-manager/resources/certificates/garage-homelab-local.yaml"
    content = templatefile("${path.module}/templates/networking/cert-manager/resources/certificates/garage-homelab-local.yaml.tftpl", {
        kubernetes_domain = var.kubernetes_domain
    })
}

resource "local_file" "certificates_grafana" {
    filename = "${path.module}/${local.project_root}/networking/cert-manager/resources/certificates/grafana-homelab-local.yaml"
    content = templatefile("${path.module}/templates/networking/cert-manager/resources/certificates/grafana-homelab-local.yaml.tftpl", {
        kubernetes_domain = var.kubernetes_domain
    })
}

resource "local_file" "certificates_harbor" {
    filename = "${path.module}/${local.project_root}/networking/cert-manager/resources/certificates/harbor-homelab-local.yaml"
    content = templatefile("${path.module}/templates/networking/cert-manager/resources/certificates/harbor-homelab-local.yaml.tftpl", {
        kubernetes_domain = var.kubernetes_domain
    })
}

resource "local_file" "certificates_authentik" {
    filename = "${path.module}/${local.project_root}/networking/cert-manager/resources/certificates/authentik-homelab-local.yaml"
    content = templatefile("${path.module}/templates/networking/cert-manager/resources/certificates/authentik-homelab-local.yaml.tftpl", {
        kubernetes_domain = var.kubernetes_domain
    })
}

resource "local_file" "certificates_endurain" {
    filename = "${path.module}/${local.project_root}/networking/cert-manager/resources/certificates/endurain-homelab-local.yaml"
    content = templatefile("${path.module}/templates/networking/cert-manager/resources/certificates/endurain-homelab-local.yaml.tftpl", {
        kubernetes_domain = var.kubernetes_domain
    })
}

resource "local_file" "certificates_hello_world" {
    filename = "${path.module}/${local.project_root}/networking/cert-manager/resources/certificates/hello-world-homelab-local.yaml"
    content = templatefile("${path.module}/templates/networking/cert-manager/resources/certificates/hello-world-homelab-local.yaml.tftpl", {
        kubernetes_domain = var.kubernetes_domain
    })
}

resource "local_file" "certificates_renovate" {
    filename = "${path.module}/${local.project_root}/networking/cert-manager/resources/certificates/renovate-homelab-local.yaml"
    content = templatefile("${path.module}/templates/networking/cert-manager/resources/certificates/renovate-homelab-local.yaml.tftpl", {
        kubernetes_domain = var.kubernetes_domain
    })
}

resource "local_file" "certificates_hubble" {
    filename = "${path.module}/${local.project_root}/networking/cert-manager/resources/certificates/hubble-homelab-local.yaml"
    content = templatefile("${path.module}/templates/networking/cert-manager/resources/certificates/hubble-homelab-local.yaml.tftpl", {
        kubernetes_domain = var.kubernetes_domain
    })
}



############
## Cilium ##
############

resource "local_file" "coredns_lan_pool" {
    filename = "${path.module}/${local.project_root}/networking/cilium/resources/coredns-lan-pool.yaml"
    content = templatefile("${path.module}/templates/networking/cilium/resources/coredns-lan-pool.yaml.tftpl", {
        coredns_ip  = var.coredns_ip
    })
}

resource "local_file" "gateway_lan_pool" {
    filename = "${path.module}/${local.project_root}/networking/cilium/resources/gateway-lan-pool.yaml"
    content = templatefile("${path.module}/templates/networking/cilium/resources/gateway-lan-pool.yaml.tftpl", {
        gateway_lan_ip  = var.gateway_lan_ip
    })
}

#############
## CoreDNS ##
#############

resource "local_file" "coredfile_coredns_lan" {
    filename = "${path.module}/${local.project_root}/networking/coredns/corefile-configmap.yaml"
    content = templatefile("${path.module}/templates/networking/coredns/corefile-configmap.yaml.tftpl", {
        gateway_lan_ip  = var.gateway_lan_ip
        kubernetes_domain = var.kubernetes_domain
        kubernetes_domain_escaped = local.kubernetes_domain_escaped
    })
}

#############
## Gateway ##
#############
# Gateways
resource "local_file" "gateway_default" {
    filename = "${path.module}/${local.project_root}/networking/gateway/resources/gateways/lan.yaml"
    content = templatefile("${path.module}/templates/networking/gateway/resources/gateways/lan.yaml.tftpl", {
        gateway_lan_ip  = var.gateway_lan_ip
        kubernetes_domain = var.kubernetes_domain
    })
}

# HTTP Routes
resource "local_file" "http_route_argocd" {
    filename = "${path.module}/${local.project_root}/networking/gateway/resources/http-routes/argocd.yaml"
    content = templatefile("${path.module}/templates/networking/gateway/resources/http-routes/argocd.yaml.tftpl", {
        kubernetes_domain = var.kubernetes_domain
    })
}

resource "local_file" "http_route_garage" {
    filename = "${path.module}/${local.project_root}/networking/gateway/resources/http-routes/garage.yaml"
    content = templatefile("${path.module}/templates/networking/gateway/resources/http-routes/garage.yaml.tftpl", {
        kubernetes_domain = var.kubernetes_domain
    })
}

resource "local_file" "http_route_grafana" {
    filename = "${path.module}/${local.project_root}/networking/gateway/resources/http-routes/grafana.yaml"
    content = templatefile("${path.module}/templates/networking/gateway/resources/http-routes/grafana.yaml.tftpl", {
        kubernetes_domain = var.kubernetes_domain
    })
}

resource "local_file" "http_route_harbor" {
    filename = "${path.module}/${local.project_root}/networking/gateway/resources/http-routes/harbor.yaml"
    content = templatefile("${path.module}/templates/networking/gateway/resources/http-routes/harbor.yaml.tftpl", {
        kubernetes_domain = var.kubernetes_domain
    })
}

resource "local_file" "http_route_authentik" {
    filename = "${path.module}/${local.project_root}/networking/gateway/resources/http-routes/authentik.yaml"
    content = templatefile("${path.module}/templates/networking/gateway/resources/http-routes/authentik.yaml.tftpl", {
        kubernetes_domain = var.kubernetes_domain
    })
}

resource "local_file" "http_route_endurain" {
    filename = "${path.module}/${local.project_root}/networking/gateway/resources/http-routes/endurain.yaml"
    content = templatefile("${path.module}/templates/networking/gateway/resources/http-routes/endurain.yaml.tftpl", {
        kubernetes_domain = var.kubernetes_domain
    })
}

resource "local_file" "http_route_hello_world" {
    filename = "${path.module}/${local.project_root}/networking/gateway/resources/http-routes/hello-world.yaml"
    content = templatefile("${path.module}/templates/networking/gateway/resources/http-routes/hello-world.yaml.tftpl", {
        kubernetes_domain = var.kubernetes_domain
    })
}

resource "local_file" "http_route_renovate" {
    filename = "${path.module}/${local.project_root}/networking/gateway/resources/http-routes/renovate.yaml"
    content = templatefile("${path.module}/templates/networking/gateway/resources/http-routes/renovate.yaml.tftpl", {
        kubernetes_domain = var.kubernetes_domain
    })
}

resource "local_file" "http_route_hubble" {
    filename = "${path.module}/${local.project_root}/networking/gateway/resources/http-routes/hubble.yaml"
    content = templatefile("${path.module}/templates/networking/gateway/resources/http-routes/hubble.yaml.tftpl", {
        kubernetes_domain = var.kubernetes_domain
    })
}

resource "local_file" "http_route_http_to_https_redirect" {
    filename = "${path.module}/${local.project_root}/networking/gateway/resources/http-routes/http-to-https-redirect.yaml"
    content = templatefile("${path.module}/templates/networking/gateway/resources/http-routes/http-to-https-redirect.yaml.tftpl", {
    })
}

############
## Garage ##
############

resource "local_file" "garage_kustomization" {
    filename = "${path.module}/${local.project_root}/storage/garage/resources/kustomization.yaml"
    content = templatefile("${path.module}/templates/storage/garage/kustomization.yaml.tftpl", {
        bucket_names = var.s3_bucket_names
    })
}

## Buckets
resource "local_file" "garage_bucket_kustomization" {
    for_each = toset(var.s3_bucket_names)
    filename = "${path.module}/${local.project_root}/storage/garage/resources/buckets/${each.value}/kustomization.yaml"
    content = templatefile("${path.module}/templates/storage/garage/bucket/kustomization.yaml.tftpl", {
    })
}

resource "local_file" "garage_bucket_bucket" {
    for_each = toset(var.s3_bucket_names)
    filename = "${path.module}/${local.project_root}/storage/garage/resources/buckets/${each.value}/bucket.yaml"
    content = templatefile("${path.module}/templates/storage/garage/bucket/bucket.yaml.tftpl", {
        bucket_name = each.value
    })
}

resource "local_file" "garage_bucket_key" {
    for_each = toset(var.s3_bucket_names)
    filename = "${path.module}/${local.project_root}/storage/garage/resources/buckets/${each.value}/key.yaml"
    content = templatefile("${path.module}/templates/storage/garage/bucket/key.yaml.tftpl", {
        bucket_name = each.value
    })
}

