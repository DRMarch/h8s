# Home Kubernetes Cluster Setup

A guide to building a highly available, three-node home Kubernetes cluster using kubeadm and kube-vip, running on Ubuntu Server 26.04. This setup focuses on simplicity, reliability, and security.

_Last updated: 2026-06-08

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [OS Setup](#os-setup)
- [Cluster Installation](#cluster-installation)
  - [1. Prepare Nodes](#1-prepare-nodes)
  - [2. Setup kube-vip](#2-setup-kube-vip)
  - [3. Initialize Control Plane](#3-initialize-control-plane)
  - [4. Configure kubeconfig](#4-configure-kubeconfig)
  - [5. Install CNI (Cilium)](#5-install-cni-cilium)
  - [6. Untaint Control Plane Nodes](#6-untaint-control-plane-nodes)
- [Future Considerations](#future-considerations)

## Overview

This repository documents the setup of a highly available, three-node Kubernetes cluster at home. It uses:

- [kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/) for automated cluster bootstrapping.
- [kube-vip](https://kube-vip.io/docs/installation/static/) as a metal load balancer for the control plane.
- [Cilium](https://cilium.io/) as the CNI for advanced networking.

## Prerequisites

- Three physical or virtual machines, each running [Ubuntu Server 26.04](https://releases.ubuntu.com/plucky/)
- Network switch
- Basic familiarity with Linux and Kubernetes

## OS Setup

- **Harden SSH:** Secure your SSH configuration before cluster setup.

## Cluster Installation

### 1. Prepare Nodes

#### Install containerd

```bash
sudo apt-get update
sudo apt-get install containerd -y
```

#### Configure sysctl parameters

```bash
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
```

#### Disable Swap

Kubernetes requires swap to be disabled:
```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
```

#### Configure containerd

```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
```

The default config uses the `cgroupfs` driver. On a systemd host the kubelet defaults to the `systemd` cgroup driver, so containerd must match — otherwise pods will fail with `OCI runtime create failed: expected cgroupsPath to be of format "slice:prefix:name" for systemd cgroups` (`FailedCreatePodSandBox` warning, with `burstable` / `besteffort` / `guaranteed` in the failing cgroup path). Flip the runc option to systemd and verify:

```bash
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

sudo grep -A2 'runtimes.runc.options' /etc/containerd/config.toml
# expect:
#   [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options]
#     SystemdCgroup = true
```

> **Note:** an `apt upgrade` of the `containerd` package regenerates `/etc/containerd/config.toml` from the package default and silently reverts this setting. Re-run the `sed` after any containerd upgrade, or pin the `containerd` package version.

#### Install kubeadm, kubelet, and kubectl

Follow the [official Kubernetes guide](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/).

### 2. Setup kube-vip

On the **first control plane node**:
```bash
KVVERSION=v1.1.2
INTERFACE=enp2s0 # Replace with your network interface
VIP=192.168.1.10 # Replace with your desired VIP

sudo ctr image pull ghcr.io/kube-vip/kube-vip:$KVVERSION
sudo ctr run --rm --net-host --env VIPCIDR=32 \
  ghcr.io/kube-vip/kube-vip:$KVVERSION vip /kube-vip manifest pod \
  --interface $INTERFACE \
  --address $VIP \
  --controlplane \
  --services \
  --arp \
  --vipSubnet 32 \
  --leaderElection | sudo tee /etc/kubernetes/manifests/kube-vip.yaml

# https://github.com/kube-vip/kube-vip/issues/684#issuecomment-1864855405
sudo sed -i 's#path: /etc/kubernetes/admin.conf#path: /etc/kubernetes/super-admin.conf#' /etc/kubernetes/manifests/kube-vip.yaml
```

On **other control plane nodes**, copy and adapt `/etc/kubernetes/manifests/kube-vip.yaml` as needed.

### 3. Setup Control Plane

On the first node:

```bash
VIP=192.168.1.10
sudo kubeadm init --control-plane-endpoint "$VIP:6443" --upload-certs

# https://github.com/kube-vip/kube-vip/issues/684#issuecomment-1864855405
sudo sed -i 's#path: /etc/kubernetes/super-admin.conf#path: /etc/kubernetes/admin.conf#' /etc/kubernetes/manifests/kube-vip.yaml
```

Verify the kubelet picked up the matching systemd cgroup driver (kubeadm
auto-detects this from the host on modern systemd / cgroup v2 systems, so it
should match the `SystemdCgroup = true` set in [Configure containerd](#configure-containerd)):

```bash
sudo grep cgroupDriver /var/lib/kubelet/config.yaml
# expect: cgroupDriver: systemd
```

Note down the command to join the control plane cluster command that will be given to you at the end.

On the second+ nodes run the command taken from above that looks like the one below:

```bash
VIP=192.168.1.10
sudo kubeadm join $VIP:6443 --token <token> \
	--discovery-token-ca-cert-hash <discover-token> \
	--control-plane --certificate-key <cet-key>

```
### 4. Configure kubeconfig

```bash
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 5. Setup kube/config

Next you will need to copy the contents of `$HOME/.kube/config` from the node where you `kubeadm init` and then copy this over to your local machine in the same path. This will allow you to access the cluster remotely with `kubectl`.

### 6. Install CNI (Cilium)

Cilium is the CNI for the cluster. It must be installed manually during initial setup
since ArgoCD cannot run without a working CNI. After ArgoCD is deployed, the `cilium-helm`
Application (managed via the App-of-Apps pattern at sync-wave -1000) adopts the release
and handles all future upgrades.

On your local machine run:

```bash
# Install helm
sudo snap install helm --classic

# Helm install cilium
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --version 1.20.0-pre.3 --namespace kube-system -f networking/cilium/helm/values.yaml
```

Once ArgoCD is running, deploy the Cilium resources:

```bash
kubectl apply -k networking/cilium/resources
```

Future Cilium version bumps are done by changing `targetRevision` in
`ci-cd/argo-cd/applications/bootstrap/cilium-helm.yaml`.

### 7. Untaint Control Plane Nodes

Allow scheduling pods on control plane nodes:
```bash
kubectl taint nodes <node-name> node-role.kubernetes.io/control-plane:NoSchedule-
```

Replace `<node-name>` with your actual node name.


### 8. Additional setup
Below we install any packages that are required by Longhorn.
```bash
# For longhorn we must have
sudo apt install open-iscsi nfs-common cryptsetup dmsetup -y
```

## Argocd
Next you can setup [argocd](./ci-cd/argo-cd/README.md) that will bootstrap all the other services in the cluster.

## Future Considerations
- **Migrate to TalosOS**.

## Vault Setup

You will need to setup Vault that can be found [here](./security/vault/README.md).

## Trusting Cluster Certificates

Your cluster uses a self-signed root CA (stored in Vault) to issue certificates for all services. To avoid browser warnings, you need to trust this CA on your local machine.

### Export the Root CA

```bash
kubectl exec -ti vault-0 -n vault -- vault read -field=certificate pki/cert/ca > ~/cluster-root-ca.pem
```

### Install on Ubuntu (System-Wide)

```bash
sudo cp ~/cluster-root-ca.pem /usr/local/share/ca-certificates/cluster-root-ca.crt
sudo update-ca-certificates
```

This makes Chrome, Edge, `curl`, `wget`, and other system tools trust the CA.

### Firefox Configuration

Firefox uses its own certificate store by default. To use the system CA store:

1. Open `about:config`
2. Set `security.enterprise_roots.enabled = true`

Alternatively, import the `.pem` file manually via **Settings > Privacy & Security > Certificates > View Certificates > Import**.

After completing these steps, browsers will trust `https://*.drmarchent.com` without warnings.

## Harbor Setup

If you would like to have the cluster be able to pull containers from harbor you will need to edit each node to resolve the dns to coredns. This can be done with:

```bash
sudo mkdir -p /etc/systemd/resolved.conf.d/

sudo mkdir -p /etc/systemd/resolved.conf.d/ && echo -e "[Resolve]\nDNS=192.168.1.11\nDomains=~drmarchent.com" | sudo tee /etc/systemd/resolved.conf.d/homelab.conf > /dev/null && sudo systemctl restart systemd-resolved

sudo systemctl restart systemd-resolved
```

Next you will need to get containerd to accept the cert of harbor

```bash

kubectl -n harbor get secret harbor-homelab-local-tls -o jsonpath='{.data.ca\.crt}' | base64 --decode > /tmp/ca.crt
sudo cp /tmp/ca.crt /usr/local/share/ca-certificates/harbor.crt && sudo update-ca-certificates

sudo systemctl restart containerd
```
