# Prometheus Stack

This directory contains the Helm installation steps for the Prometheus Operator stack used for monitoring in the cluster.

## Add repository

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
```

## Install chart

```bash
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f values.yaml
```

## Notes

- Create the monitoring namespace before installing the stack if it does not exist.
- Review the values file before deployment and adjust it for your environment.

