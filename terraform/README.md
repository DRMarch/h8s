# Terraform

This Terraform module is responsible for templating Kubernetes manifests and generating related documentation for your homelab cluster.

## Variables

To customize the configuration, edit the input variables defined in [`variables.tf`](./variables.tf). Below is a summary of the available variables:

| Variable Name        | Description                                                   | Type   | Default Value     |
|----------------------|---------------------------------------------------------------|--------|-------------------|
| `kube_vip_ip`        | LAN fixed IP for the Kubernetes cluster                       | string | `192.168.1.10`    |
| `coredns_ip`         | LAN fixed IP for CoreDNS                                      | string | `192.168.1.11`    |
| `gateway_lan_ip`     | LAN IP used for ingress traffic into cluster services         | string | `192.168.1.12`    |
| `kubernetes_domain`  | Domain name used for ingress into cluster services            | string | `homelab.local`   |

## Usage

After setting the desired variable values, follow the steps below to initialize and apply the configuration:

```bash
devbox shell

cd terraform

terraform init

terraform apply
```

This will render the necessary Kubernetes manifests and outputs based on your configuration.
