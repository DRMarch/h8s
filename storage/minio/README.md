# MinIO on Kubernetes

MinIO provides an **S3-compatible high-performance object storage** solution that can be deployed within your Kubernetes cluster. This allows applications running inside the cluster to have scalable and resilient object storage similar to AWS S3.

## Architecture Overview

When deploying MinIO on Kubernetes, the system is split into two distinct components:

- **MinIO Operator:**  
  This is a Kubernetes-native controller responsible for managing the lifecycle of MinIO Tenants. The Operator automates tasks like deploying, upgrading, scaling, and maintaining MinIO clusters (known as Tenants) within the Kubernetes environment. It extends the Kubernetes API with Custom Resource Definitions (CRDs) to handle MinIO-specific configurations.

- **MinIO Tenant:**  
  A Tenant represents a fully functional, independent MinIO object storage cluster running inside its own Kubernetes namespace. Each Tenant consists of multiple MinIO server pods and persistent storage volumes, configured to provide distributed, erasure-coded object storage. Tenants can be configured with different resource sizes, capacities, and security settings, allowing multi-tenancy on a single Kubernetes cluster.

## Key Concepts

- **Operator Namespace:**  
  The MinIO Operator runs in its dedicated namespace and watches for Tenant resources across the cluster.

- **Tenant Namespace:**  
  Each MinIO Tenant must be deployed into its own Kubernetes namespace to isolate resources and configuration.

- **Pods and Containers in Tenant:**  
  Each Tenant pod runs:  
  - The main MinIO server container handling storage operations.  
  - An InitContainer for initialization tasks such as secret management.  
  - A Sidecar container responsible for tenant-specific configuration and startup validation.

- **Persistent Volumes:**  
  Tenants use Persistent Volume Claims (PVCs) to mount storage into MinIO pods, ensuring data durability beyond pod lifecycles.

## Benefits of Using the MinIO Operator

- Simplifies deployment of complex distributed MinIO clusters.
- Automates upgrades and configuration changes without downtime.
- Manages multiple independent Tenants with separate configurations on the same Kubernetes cluster.
- Supports scaling and expanding Tenant capacity through configuration changes.
