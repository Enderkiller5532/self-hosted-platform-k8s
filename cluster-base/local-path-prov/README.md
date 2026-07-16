# Local Path Provisioner

This directory contains a simple setup for installing the Rancher Local Path Provisioner, which provides a default storage class for local development and test clusters.

## Installation

Apply the provisioner manifest:

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.36/deploy/local-path-storage.yaml
```

Make it the default storage class for the cluster:

```bash
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

## Example PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-path-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 128Mi
```

## Notes

- This provisioner is best suited for local or development clusters.
- For production workloads, consider a more robust shared storage solution.
