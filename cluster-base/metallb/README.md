# MetalLB

This directory contains instructions for installing MetalLB in a Kubernetes cluster and enabling Layer 2 or BGP support.

## Preparation

Enable strict ARP for kube-proxy so MetalLB can work correctly:

```bash
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl diff -f - -n kube-system
```

```bash
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl apply -f - -n kube-system
```

## Installation options

### FRR-K8s mode (recommended)

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.16.1/config/manifests/metallb-frr-k8s.yaml
```

### Native mode

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.16.1/config/manifests/metallb-native.yaml
```

### FRR mode (deprecated)

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.16.1/config/manifests/metallb-frr.yaml
```

## Notes

- Choose the mode that matches your networking requirements.
- Configure address pools after installation so MetalLB can assign IP addresses to services.
- Review the official MetalLB documentation for the latest recommended setup.
