# HashiCorp Vault

This directory contains an example for deploying HashiCorp Vault using Helm.

## Installation

```bash
helm install my-vault hashicorp/vault --version 0.34.0 -n vault --create-namespace -f values.yaml
```

```bash
kubectl exec -n vault my-vault-0 -- vault operator init > vault.txt
```
```bash
kubectl exec -n vault my-vault-0 -- vault operator unseal <key1>
kubectl exec -n vault my-vault-0 -- vault operator unseal <key2>
kubectl exec -n vault my-vault-0 -- vault operator unseal <key3>
```
## Notes

- Review the values file before deploying Vault.
- Store secrets securely and adjust the configuration to match your cluster environment.
