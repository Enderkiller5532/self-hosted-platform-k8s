# Thanos

This directory contains installation instructions for deploying Thanos in the monitoring stack.

## Add repository

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
```

## Install chart

```bash
helm install thanos oci://ghcr.io/thanos-community/helm-charts/thanos --namespace monitoring --values values.yaml
```

## Notes

- Ensure that the monitoring namespace exists before installation.
- Review the configuration values to match your storage and endpoint settings.
