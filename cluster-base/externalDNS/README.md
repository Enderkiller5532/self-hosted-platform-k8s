# ExternalDNS

This directory contains resources for installing and configuring ExternalDNS in a Kubernetes cluster.

## Installation

Add the Helm repository:

```bash
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
```

## Notes

- Review the values and manifests before applying them to production.
- Make sure your cluster has the required permissions for ExternalDNS to manage DNS records.
- Replace any placeholder domain or provider settings with values that match your environment.
