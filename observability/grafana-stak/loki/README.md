# Loki

This directory contains installation steps for deploying Loki and Promtail together using the Loki stack Helm chart.

## Add repository

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

## Install Loki and Promtail

```bash
helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=10Gi
```

## Notes

- Make sure the monitoring namespace exists.
- Adjust persistence settings and resource requests according to your environment.
