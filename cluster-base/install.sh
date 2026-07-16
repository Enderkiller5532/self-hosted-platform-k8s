#!/usr/bin/env bash
set -euo pipefail

# Kubernetes bootstrap script for Ubuntu with containerd and Cilium
# Usage:
#   curl -fsSL https://example.com/install.sh | bash
#
# # control plane
# curl -fsSL https://example.com/install.sh | bash -- --control-plane

# # worker
# curl -fsSL https://example.com/install.sh | bash -- --worker --join-command 'kubeadm join ...'

# This script is intended for a single-node or multi-node lab setup.
# It installs containerd, kubeadm, kubelet, kubectl, initializes the cluster,
# and installs Cilium as the CNI.

export DEBIAN_FRONTEND=noninteractive

MODE="control-plane"
POD_CIDR="IP_PLACEHOLDER/16"
JOIN_COMMAND=""
KUBECONFIG_PATH=""
KUBERNETES_VERSION="v1.31"
CILIUM_CLI_VERSION="v0.16.23"
KUBECONFIG_TARGET=""

print_help() {
  cat <<EOF
Usage: install.sh [options]

Options:
  --control-plane        Install as Kubernetes control plane
  --worker               Install as Kubernetes worker node
  --pod-cidr CIDR        Set pod network CIDR (default: IP_PLACEHOLDER/16)
  --join-command CMD     Join command for worker nodes
  --kubeconfig PATH      Path to kubeconfig file for cluster operations
  --kubernetes-version X Set Kubernetes version (default: v1.31)
  --cilium-cli-version X Set Cilium CLI version (default: v0.16.23)
  --help                 Show this help message

Examples:
  Short form:
    curl -fsSL https://example.com/install.sh | bash -- --control-plane

  Full form:
    curl -fsSL https://example.com/install.sh | bash -- \
      --control-plane \
      --pod-cidr IP_PLACEHOLDER/16 \
      --kubernetes-version v1.32

  Worker node:
    curl -fsSL https://example.com/install.sh | bash -- \
      --worker \
      --join-command 'kubeadm join IP_PLACEHOLDER:6443 --token ... --discovery-token-ca-cert-hash sha256:...' \
      --kubeconfig /root/.kube/config

Multiple options can be combined in one command.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --worker)
      MODE="worker"
      ;;
    --control-plane)
      MODE="control-plane"
      ;;
    --pod-cidr)
      POD_CIDR="$2"
      shift
      ;;
    --join-command)
      JOIN_COMMAND="$2"
      shift
      ;;
    --kubeconfig)
      KUBECONFIG_PATH="$2"
      shift
      ;;
    --kubernetes-version)
      KUBERNETES_VERSION="$2"
      shift
      ;;
    --cilium-cli-version)
      CILIUM_CLI_VERSION="$2"
      shift
      ;;
    --help)
      print_help
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

log() {
  echo "[k8s-install] $*"
}

fail() {
  echo "[k8s-install] ERROR: $*" >&2
  exit 1
}

require_root() {
  if [[ $(id -u) -ne 0 ]]; then
    fail "Run this script as root or with sudo"
  fi
}

validate_versions() {
  if [[ ! "$KUBERNETES_VERSION" =~ ^v[0-9]+\.[0-9]+$ ]]; then
    fail "Kubernetes version must match the format vX.Y (for example: v1.31)"
  fi

  if [[ ! "$CILIUM_CLI_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    fail "Cilium CLI version must match the format vX.Y.Z (for example: v0.16.23)"
  fi
}

check_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    case "$ID" in
      ubuntu|debian|raspbian)
        DISTRO="$ID"
        PKG_MANAGER="apt"
        ;;
      rocky|centos|rhel|almalinux|ol)
        DISTRO="$ID"
        PKG_MANAGER="yum"
        ;;
      *)
        fail "Unsupported distro: $ID. This script currently supports Debian/Ubuntu/Raspbian and RHEL-like systems."
        ;;
    esac
  else
    fail "Unable to detect OS distribution"
  fi

  if [[ "$PKG_MANAGER" == "apt" ]]; then
    if ! command -v apt-get >/dev/null 2>&1; then
      fail "apt-get not found. This script requires a Debian/Ubuntu-based system"
    fi
  elif [[ "$PKG_MANAGER" == "yum" ]]; then
    if ! command -v yum >/dev/null 2>&1 && ! command -v dnf >/dev/null 2>&1; then
      fail "Neither yum nor dnf found. This script requires an RHEL-like system"
    fi
  fi
}

configure_rhel_security() {
  if [[ "$PKG_MANAGER" != "yum" ]]; then
    return
  fi

  if command -v setenforce >/dev/null 2>&1 && selinuxenabled; then
    log "Setting SELinux to permissive mode"
    setenforce 0 || true
    if [[ -f /etc/selinux/config ]]; then
      sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
    fi
  fi

  if command -v firewall-cmd >/dev/null 2>&1; then
    if firewall-cmd --state >/dev/null 2>&1; then
      log "Disabling firewalld to simplify lab networking"
      systemctl disable --now firewalld || true
    fi
  fi
}

install_prereqs() {
  log "Installing prerequisites for $DISTRO"
  if [[ "$PKG_MANAGER" == "apt" ]]; then
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
  else
    if command -v dnf >/dev/null 2>&1; then
      dnf install -y curl wget git gnupg2 ca-certificates
    else
      yum install -y curl wget git gnupg2 ca-certificates
    fi
  fi
}

configure_kernel() {
  log "Configuring kernel modules and sysctl settings"
  cat <<'EOF' >/etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

  modprobe overlay || true
  modprobe br_netfilter || true

  cat <<'EOF' >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

  sysctl --system >/dev/null 2>&1 || true
}

install_containerd() {
  log "Installing containerd"
  if [[ "$PKG_MANAGER" == "apt" ]]; then
    apt-get install -y containerd
  else
    if command -v dnf >/dev/null 2>&1; then
      dnf install -y containerd
    else
      yum install -y containerd
    fi
  fi

  mkdir -p /etc/containerd
  containerd config default > /etc/containerd/config.toml
  sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
  systemctl enable containerd --now
  systemctl restart containerd
}

install_kubernetes_tools() {
  log "Installing Kubernetes tools"
  if [[ "$PKG_MANAGER" == "apt" ]]; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
    apt-get update
    apt-get install -y kubelet kubeadm kubectl
  else
    cat <<EOF >/etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/repodata/repomd.xml.key
EOF
    if command -v dnf >/dev/null 2>&1; then
      dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
    else
      yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
    fi
  fi

  systemctl enable kubelet --now
}

disable_swap() {
  log "Disabling swap"
  swapoff -a || true
  sed -i '/ swap / s/^/#/' /etc/fstab || true
}

resolve_kubeconfig_target() {
  if [[ -n "$KUBECONFIG_PATH" ]]; then
    KUBECONFIG_TARGET="$KUBECONFIG_PATH"
  else
    KUBECONFIG_TARGET="$HOME/.kube/config"
  fi
  mkdir -p "$(dirname "$KUBECONFIG_TARGET")"
}

init_cluster() {
  if [[ "$MODE" == "worker" ]]; then
    if [[ -z "$JOIN_COMMAND" ]]; then
      fail "--join-command is required when using --worker"
    fi
    log "Joining Kubernetes worker node"
    bash -c "$JOIN_COMMAND"
    return
  fi

  log "Initializing Kubernetes control plane"
  if [[ -f /etc/kubernetes/admin.conf ]]; then
    log "Cluster already initialized"
    return
  fi

  kubeadm init --pod-network-cidr="$POD_CIDR"

  resolve_kubeconfig_target
  cp -i /etc/kubernetes/admin.conf "$KUBECONFIG_TARGET"
  chown "$(id -u)":"$(id -g)" "$KUBECONFIG_TARGET"
  export KUBECONFIG="$KUBECONFIG_TARGET"
}

install_cilium_cli() {
  local arch
  local asset

  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64)
      asset="cilium-linux-amd64.tar.gz"
      ;;
    aarch64|arm64)
      asset="cilium-linux-arm64.tar.gz"
      ;;
    *)
      fail "Unsupported architecture for Cilium CLI: $arch"
      ;;
  esac

  curl -fsSL -o /tmp/cilium.tar.gz "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/${asset}"
  mkdir -p /usr/local/bin
  tar -C /usr/local/bin -xzf /tmp/cilium.tar.gz
  chmod +x /usr/local/bin/cilium
  rm -f /tmp/cilium.tar.gz
}

install_cilium() {
  if [[ "$MODE" == "worker" ]]; then
    log "Skipping Cilium installation on worker node"
    return
  fi
  log "Installing Cilium"
  if ! command -v cilium >/dev/null 2>&1; then
    install_cilium_cli
  fi

  resolve_kubeconfig_target
  export KUBECONFIG="$KUBECONFIG_TARGET"
  kubectl wait --for=condition=Ready node --all --timeout=300s || true
  cilium install --set ipam.mode=kubernetes --set clusterPoolIPv4PodCIDRList="$POD_CIDR"
  cilium status --wait
}

save_cluster_info() {
  local info_file="/tmp/AllClusterInfoCMfromSkript.txt"
  local kubeconfig_arg=()

  resolve_kubeconfig_target
  if [[ -n "$KUBECONFIG_TARGET" ]]; then
    kubeconfig_arg=(--kubeconfig="$KUBECONFIG_TARGET")
  fi

  {
    echo "mode: $MODE"
    echo "distro: $DISTRO"
    echo "pkg_manager: $PKG_MANAGER"
    echo "pod_cidr: $POD_CIDR"
    echo "hostname: $(hostname)"
    echo "kernel: $(uname -r)"
    echo "timestamp: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    echo "join_command: ${JOIN_COMMAND:-not-provided}"
    echo ""
    echo "cluster_info:"
    if command -v kubectl >/dev/null 2>&1; then
      if kubectl "${kubeconfig_arg[@]}" cluster-info >/dev/null 2>&1; then
        kubectl "${kubeconfig_arg[@]}" cluster-info 2>/dev/null | sed 's/^/  /'
        echo ""
        echo "nodes:"
        kubectl "${kubeconfig_arg[@]}" get nodes -o wide 2>/dev/null | sed 's/^/  /'
      else
        echo "  unavailable"
      fi
    else
      echo "  unavailable"
    fi
  } > "$info_file"

  echo "=== Cluster info ==="
  cat "$info_file"
  echo "===================="

  if command -v kubectl >/dev/null 2>&1; then
    if kubectl "${kubeconfig_arg[@]}" cluster-info >/dev/null 2>&1; then
      kubectl "${kubeconfig_arg[@]}" create configmap AllClusterInfoCMfromSkript --from-file=summary="$info_file" -n kube-system --dry-run=client -o yaml | kubectl "${kubeconfig_arg[@]}" apply -f -
      log "Saved cluster info to ConfigMap AllClusterInfoCMfromSkript in namespace kube-system"
    else
      log "kubectl is available but cluster is not reachable; ConfigMap was not created"
    fi
  else
    log "kubectl is not available; ConfigMap was not created"
  fi
}

main() {
  require_root
  check_os
  validate_versions
  disable_swap
  install_prereqs
  configure_rhel_security
  configure_kernel
  install_containerd
  install_kubernetes_tools
  init_cluster
  install_cilium
  save_cluster_info

  if [[ "$MODE" == "control-plane" ]]; then
    log "Installation finished"
    log "Run: kubectl get nodes"
  else
    log "Worker node joined successfully"
  fi
}

main "$@"
