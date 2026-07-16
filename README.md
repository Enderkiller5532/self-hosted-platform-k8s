# Kubernetes Home Lab Repository

This repository is a growing collection of Kubernetes manifests, Helm values, and deployment notes for a personal home-lab and learning environment. It is intended for experimenting with cluster components, observability, CI/CD, storage, and platform services in a practical way.

## What this repository is for

This repo is designed to be a hands-on playground for:

- setting up core cluster infrastructure
- deploying observability tools
- testing CI/CD pipelines
- experimenting with platform services such as GitLab, Vault, and WordPress
- learning Kubernetes concepts through real examples

## Repository structure

- cluster-base: foundational cluster components such as storage provisioners, MetalLB, and ExternalDNS
- observability: monitoring and tracing stack with Prometheus, Grafana, Loki, Tempo, and Thanos
- pipelines: CI/CD examples for Jenkins and TeamCity
- gitlab: GitLab deployment example
- hashicorp-vault: Vault deployment example
- HPA: Horizontal Pod Autoscaler example
- VPA: Vertical Pod Autoscaler example
- wordpress: WordPress-related example resources

## Prerequisites

Before applying the manifests, make sure you have:

- a running Kubernetes cluster
- kubectl installed and configured
- Helm installed
- access to required container registries, storage backends, and DNS/infrastructure services

## How to use this repository

1. Review the relevant directory and README first.
2. Adjust values, hostnames, IP addresses, and secrets to match your environment.
3. Apply manifests or install Helm charts carefully and in the intended order.
4. Use the examples as a starting point for your own setup.

## Notes

- Some examples are intentionally minimal and meant for learning or lab use.
- Some components depend on external services such as ingress controllers, storage classes, NFS shares, or monitoring namespaces.
- Replace placeholder values with environment-specific settings before using anything outside a test setup.

## Planned future additions

This repository is expected to grow over time. Future additions may include:

- additional Kubernetes operators and addons
- more deployment examples for applications and services
- improved Helm values and production-ready templates
- more automation and bootstrap scripts

## Useful commands

```bash
kubectl get nodes
kubectl get pods -A
helm list -A
```
