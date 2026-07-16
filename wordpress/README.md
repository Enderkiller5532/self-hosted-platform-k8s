# WordPress

This directory is intended for WordPress deployment examples in the Kubernetes environment.

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
```
```bash
helm install wordpress bitnami/wordpress --version 32.1.12 -n --create-namespace
```


## Notes
- First repace CHANGEME in values.
- Review the manifests and values before applying them to a cluster.
- Ensure that supporting services such as databases, ingress, and storage are available.
- Replace any example credentials or domain names with values appropriate for your environment.
