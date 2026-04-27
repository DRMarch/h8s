
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

resource "local_file" "certificates_hello_world" {
    filename = "${path.module}/${local.project_root}/networking/cert-manager/resources/certificates/hello-world-homelab-local.yaml"
    content = templatefile("${path.module}/templates/networking/cert-manager/resources/certificates/hello-world-homelab-local.yaml.tftpl", {
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
    filename = "${path.module}/${local.project_root}/networking/gateway/resources/gateways/default.yaml"
    content = templatefile("${path.module}/templates/networking/gateway/resources/gateways/default.yaml.tftpl", {
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

resource "local_file" "http_route_hello_world" {
    filename = "${path.module}/${local.project_root}/networking/gateway/resources/http-routes/hello-world.yaml"
    content = templatefile("${path.module}/templates/networking/gateway/resources/http-routes/hello-world.yaml.tftpl", {
        kubernetes_domain = var.kubernetes_domain
    })
}