variable "kube_vip_ip" {
  description = "LAN fixed IP for the cluster"
  type        = string
  default     = "192.168.1.10"
}


variable "coredns_ip" {
  description = "LAN fixed IP for the coredns"
  type        = string
  default     = "192.168.1.11"
}

variable "gateway_lan_ip" {
  description = "LAN fixed IP for ingress traffic into the cluster services"
  type        = string
  default     = "192.168.1.12"
}


variable "gateway_cloudflare_ip" {
  description = "Fixed IP for the cloudflare tunnel gateway service"
  type        = string
  default     = "20.0.0.0"
}


variable "kubernetes_domain" {
  description = "The domain name for ingress traffic into the cluster services"
  type        = string
  default     = "drmarchent.com"
}


variable "s3_bucket_names" {
  description = "Names of S3 buckets to template out for garage resources"
  type        = list(string)
  default     = ["default"]
}
