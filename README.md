# h8s

A repository for my home Kubernetes lab setup.

## Overview

This repo documents the configuration and management of my personal Kubernetes homelab, designed for high availability and efficient resource use. The cluster consists of three nodes, each serving as a control plane node with stacked etcd, and also functioning as worker nodes due to hardware constraints. All nodes are TRIGKEY N100 mini-PCs, each equipped with 16GB RAM and 512GB storage.

**Key Features:**

- **High Availability:** All three nodes act as control plane nodes with stacked etcd for resilience.
- **Resource Efficiency:** Control plane nodes are also schedulable for workloads.
- **Hardware:**  
  - 3× TRIGKEY N100  
  - 16GB RAM per node  
  - 512GB storage per node

## Documentation

For detailed setup instructions, configuration steps, and operational notes, see [SETUP.md](./SETUP.md).


## TODO list

- Setup terraform to template out files. Ideally for kube-vip.
