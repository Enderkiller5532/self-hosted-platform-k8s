# Vertical Pod Autoscaler

This directory contains a simple setup for installing the Vertical Pod Autoscaler (VPA) in a Kubernetes cluster.

## Prepare metrics server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Verify that it is available:

```bash
kubectl top nodes
```

## Install VPA

```bash
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler
./hack/vpa-up.sh
```

Verify that the API resources are available:

```bash
kubectl api-resources | grep vpa
kubectl get pods -n kube-system | grep vpa
```

## Notes

- VPA is useful for tuning resource requests and limits automatically.
- Review the deployment manifests in this directory before applying them to your cluster.
