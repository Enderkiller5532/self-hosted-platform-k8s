# Install Kubernetes with containerd

This guide describes a practical way to install a Kubernetes cluster with containerd on Ubuntu-based nodes. It is intended as a reusable setup guide for a home lab or test environment.

> This document is a working example and should be adapted to your environment, OS version, networking setup, and security requirements.

## 1. Prerequisites

Make sure each node meets the following requirements:

- Ubuntu 22.04/24.04 or another compatible Linux distribution
- root or sudo access
- internet access to download Kubernetes and containerd packages
- a working hostname resolution setup
- a bridge network configuration suitable for Kubernetes
- enough CPU, RAM, and disk space for the control plane and worker nodes

## 2. Prepare the system

Run these commands on all nodes.

### 2.1 Disable swap

```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
```

### 2.2 Load required kernel modules

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
```

### 2.3 Enable kernel networking settings

```bash
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
```

### 2.4 Install required packages

```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
```

## 3. Install containerd

### 3.1 Install containerd and dependencies

```bash
sudo apt-get update
sudo apt-get install -y containerd
```

### 3.2 Configure containerd

```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
```

### 3.3 Restart containerd

```bash
sudo systemctl enable containerd
sudo systemctl restart containerd
sudo systemctl status containerd --no-pager
```

## 4. Install Kubernetes components

### 4.1 Add Kubernetes apt repository

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

### 4.2 Install kubeadm, kubelet, kubectl

```bash
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo systemctl enable kubelet
```

## 5. Initialize the control plane

Run this only on the control plane node.

### 5.1 Choose a pod network plugin

If you want to use Cilium, initialize Kubernetes with a pod CIDR that matches your Cilium setup.

```bash
sudo kubeadm init --pod-network-cidr=IP_PLACEHOLDER/16
```

> If you plan to use Cilium, do not install Calico afterward. The CNI must be consistent across the cluster.

If the command fails because the container runtime is not ready, check:

```bash
sudo systemctl status containerd --no-pager
sudo journalctl -u kubelet -n 100 --no-pager
```

### 5.2 Configure kubectl for the current user

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 5.3 Install Cilium

Install Cilium after the control plane is ready:

```bash
curl -fsSL https://raw.githubusercontent.com/cilium/cilium-cli/main/install.sh | bash
cilium install
```

If you prefer to use a specific Cilium version, you can pin it explicitly:

```bash
CILIUM_CLI_VERSION=v0.16.23
curl -fsSL https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz | sudo tar -xz -C /usr/local/bin
```

### 5.4 Verify Cilium

```bash
cilium status
kubectl get pods -A
```

## 6. Join worker nodes

After the control plane is initialized, kubeadm will print a join command. Example:

```bash
kubeadm token create --print-join-command
```

Run the printed command on each worker node.

## 7. Verify the cluster

```bash
kubectl get nodes
kubectl get pods -A
```

You should see the control plane node and worker nodes in Ready state.

## 8. Optional: install a single-node local cluster

If you want a very simple local setup for testing, you can use the following approach on a single machine:

```bash
sudo kubeadm init --pod-network-cidr=IP_PLACEHOLDER/16 --apiserver-advertise-address=IP_PLACEHOLDER
```

Then follow the same pod network install steps.

## 9. One-line install with curl

If you want to bootstrap the installation from a script, you can download and run a helper script from a URL.

Example pattern:

```bash
curl -fsSL https://example.com/install-k8s.sh -o /tmp/install-k8s.sh
bash /tmp/install-k8s.sh
```

> Replace the example URL with your own script or internal storage location.

## 10. Notes

- Kubernetes versions and package repository URLs can change, so verify that the versions you use are still current.
- For production environments, use a supported Kubernetes version and review hardening guidance.
- Replace example hostnames, IPs, and credentials with values that match your environment.


### TL;DR

```bash
# For control plane
 curl -fsSL https://example.com/install.sh | bash -- --control-plane
```
```bash
# For worker
 curl -fsSL https://example.com/install.sh | bash -- --worker --join-command 'kubeadm join ...'

```