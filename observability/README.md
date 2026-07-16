# Observability

This directory contains the monitoring and observability stack for the Kubernetes environment.

## Included components

- Prometheus Stack for metrics collection and alerting
- Thanos for long-term metric storage and query aggregation
- Loki for log aggregation
- Tempo for distributed tracing

## Notes

- Create the monitoring namespace before installing these components.
- Review the Helm values and secrets before deployment.
- Adjust storage sizes and endpoint settings to fit your infrastructure.
