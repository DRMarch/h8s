# Home Kubernetes Cluster Setup

A guide to building a highly available, three-node home Kubernetes cluster using kubeadm and kube-vip, running on Ubuntu Server 25.04. This setup focuses on simplicity, reliability, and security for home environments where WiFi networking is required.

_Last updated: June 29, 2025_

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

> **Note:** TalosOS was considered for its security and immutability, but is currently not supported due to WiFi driver limitations. Future migration to TalosOS is under review.

## Prerequisites

- Three physical or virtual machines, each running [Ubuntu Server 25.04](https://releases.ubuntu.com/plucky/)
- WiFi network connectivity (due to router access limitations)
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

Ensure the following is set in `/etc/containerd/config.toml`:
```toml
[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options]
SystemdCgroup = true
```

#### Install kubeadm, kubelet, and kubectl

Follow the [official Kubernetes guide](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/).

### 2. Setup kube-vip

On the **first control plane node**:
```bash
KVVERSION=v0.9.2
INTERFACE=wlp3s0 # Replace with your network interface
VIP=192.168.178.10 # Replace with your desired VIP

sudo ctr image pull ghcr.io/kube-vip/kube-vip:$KVVERSION
sudo ctr run --rm --net-host --env VIPCIDR=32 \
  ghcr.io/kube-vip/kube-vip:$KVVERSION vip /kube-vip manifest pod \
  --interface $INTERFACE \
  --vip $VIP \
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
VIP=192.168.178.10
sudo kubeadm init --control-plane-endpoint "$VIP:6443" --upload-certs

# https://github.com/kube-vip/kube-vip/issues/684#issuecomment-1864855405
sudo sed -i 's#path: /etc/kubernetes/super-admin.conf#path: /etc/kubernetes/admin.conf#' /etc/kubernetes/manifests/kube-vip.yaml
```

Note down the command to join the control plane cluster command that will be given to you at the end.

On the second+ nodes run the command taken from above that looks like the one below:

```bash
VIP=192.168.178.10
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

### 5. Install CNI (Cilium)

Install only on the node where you ran `kubeadm init`:
```bash
sudo snap install helm --classic

helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --version 1.17.5 --namespace kube-system
```

### 6. Untaint Control Plane Nodes

Allow scheduling pods on control plane nodes:
```bash
kubectl taint nodes <node-name> node-role.kubernetes.io/control-plane:NoSchedule-
```

Replace `<node-name>` with your actual node name.


### 7. Additional setup
Below we install any packages that are required by Longhorn.
```bash
# For longhorn we must have
sudo apt install open-iscsi nfs-common cryptsetup dmsetup -y
```

## Kube-VIP-Cloud-Controller

https://kube-vip.io/docs/usage/cloud-provider/


## Future Considerations
- **Migrate to TalosOS** when WiFi support becomes available for improved security and manageability.
- **Switch kube-vip to DaemonSet** for higher reliability and easier management.
