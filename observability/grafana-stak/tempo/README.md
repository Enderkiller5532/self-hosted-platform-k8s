# Tempo

This directory contains an example for deploying Tempo together with the observability stack.

## Create secrets

```bash
# Example only: replace these placeholders with your real credentials
kubectl create secret generic tempo-minio \
  -n monitoring \
  --from-literal=access-key='YOUR_ACCESS_KEY' \
  --from-literal=secret-key='YOUR_SECRET_KEY'
```

## Install OpenTelemetry collector

```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

helm install otel-collector open-telemetry/opentelemetry-collector \
  -n monitoring -f values.yaml
```

## Notes

- Review the secret values before deploying them in a real environment.
- Adjust the values file to match your storage backend and trace collection settings.

