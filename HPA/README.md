# Kubernetes Nginx HPA & NFS Storage Tutorial

This project demonstrates a production-ready Kubernetes setup using Nginx. It covers persistent storage via **NFS**, **Secrets** management, **Horizontal Pod Autoscaling (HPA)**, and **Ingress** configuration.

## 🚀 Project Overview
The goal of this lab is to deploy a scalable Nginx web server where the web content, configurations, and logs are stored on external NFS storage. The application automatically scales based on memory usage and is accessible via a custom domain.

## 📁 Directory Structure
```text
.
├── conf.d/                 # Nginx configuration files (nginxfix.conf)
├── sites/                  # Website configuration (default.conf)
├── www/                    # Static web content (index.html)
├── 0-secret.yaml           # Environment variables (Secret)
├── 1-persistentVolume.yaml # NFS Storage definitions (PV)
├── 2-persistentVolumeClaim.yaml # Storage requests (PVC)
├── 3-service.yaml          # Internal Load Balancer (ClusterIP)
├── 4-deployment.yaml       # Nginx Pod definition
├── 5-HPA.yaml               # Horizontal Pod Autoscaler
├── 6-ingress.yaml          # External access (Ingress)
└── 99-fullhouse.yaml        # All-in-one manifest for quick deployment
```

## 🛠 Components Explained

### 1. Storage (PV & PVC)
The setup uses **NFS** for persistent storage. This ensures that even if a Pod restarts or scales, the files remain intact:
*   **web-site**: Mounts to `/var/www/html/` (Public content).
*   **configs**: Mounts to `/etc/nginx/conf.d/` (Nginx configurations).
*   **sites**: Mounts to `/etc/nginx/sites-enabled/` (Virtual host configs).
*   **logs**: Mounts to `/var/log/nginx/` (Application logs).

### 2. Secret Management
A Kubernetes Secret named `testforenv` is used to inject environment variables into the container without hardcoding them in the deployment file.

### 3. Deployment & Scaling (HPA)
*   **Deployment**: Runs the `nginx:stable-bookworm` image.
*   **Resources**: Defines CPU and Memory requests/limits.
*   **HPA**: Automatically scales the number of pods from **1 to 3** based on an average memory utilization of **60%**.

### 4. Networking
*   **Service**: A `ClusterIP` service provides a stable internal IP/Port for the pods.
*   **Ingress**: Exposes the service to the internet using the hostname `icant.use.it` via an Nginx Ingress Controller.

## 🚀 Getting Started

### Prerequisites
* A running Kubernetes cluster (Minikube, Kind, or a cloud provider).
* `kubectl` installed.
* An Nginx Ingress Controller installed in your cluster.
* An active NFS server (configured at `IP_PLACEHOLDER` in this manifest).

### Deployment Steps

**Preperation Phase**\
Prepare `metric server`
```
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```
### Chek if it installed via command.
```
kubectl top nodes
```

**Option A: Step-by-Step (Recommended for learning)**
Apply the files in order:
```bash
kubectl apply -f 0-secret.yaml
kubectl apply -f 1-persistentVolume.yaml
kubectl apply -f 2-persistentVolumeClaim.yaml
kubectl apply -f 3-service.yaml
kubectl apply -f 4-deployment.yaml
kubectl apply -f 5-HPA.yaml
kubectl apply -f 6-ingress.yaml
```

**Option B: Full Deployment**
```bash
kubectl apply -f 99-fullhouse.yaml
```

## 🔍 Verification
1.  **Check Pods**: `kubectl get pods`
2.  **Check Scaling**: `kubectl get hpa`
3.  **Check Services**: `kubectl get svc`
4.  **Test Access**: Visit `http://icant.use.it` in your browser (Ensure your local `/etc/hosts` points the domain to your Ingress IP).