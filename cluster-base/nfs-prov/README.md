# NFS Subdir External Provisioner

This directory contains the Helm installation steps for the NFS subdir external provisioner, which can dynamically provision persistent volumes for Kubernetes workloads.

## Installation

Add the Helm repository and install the chart:

```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner -f values.yaml -n nfs --create-namespace
```

## Notes

- Ensure that the target NFS server is reachable from your cluster nodes.
- Review the values file before deployment and adjust storage settings as needed.
- Verify that the storage class is created successfully after installation.
