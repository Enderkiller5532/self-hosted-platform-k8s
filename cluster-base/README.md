# Cluster Base

This directory contains foundational Kubernetes components for the cluster environment, including storage provisioners, load balancing, and DNS integration.

## Included components

- ExternalDNS for DNS record management
- Local Path Provisioner for local storage support
- MetalLB for service exposure with load balancer IPs
- NFS Subdir External Provisioner for dynamic NFS-backed volumes

## Notes

- Review each subdirectory before applying manifests in a real environment.
- Some components depend on existing cluster features such as ingress controllers or external networking services.
- Replace placeholder values and endpoints with environment-specific settings.
