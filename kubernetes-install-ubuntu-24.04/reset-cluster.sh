#!/bin/bash

# 🧹 Kubernetes Cluster Reset Script
# Use this script to completely reset a Kubernetes node

echo "🧹 Kubernetes Cluster Reset Script"
echo "=================================="
echo
echo "⚠️  WARNING: This will completely remove Kubernetes from this node!"
echo "This script will:"
echo "  - Reset kubeadm configuration"
echo "  - Stop all services"
echo "  - Clean up containers and images"
echo "  - Remove configuration files"
echo
read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo
echo "🛑 Stopping services..."

# Reset kubeadm
if command -v kubeadm &> /dev/null; then
    echo "Resetting kubeadm..."
    sudo kubeadm reset -f
fi

# Stop services
echo "Stopping kubelet..."
sudo systemctl stop kubelet 2>/dev/null || true

echo "Stopping containerd..."
sudo systemctl stop containerd 2>/dev/null || true

# Remove containers and images
echo "🗑️  Cleaning up containers..."
if command -v crictl &> /dev/null; then
    sudo crictl rm --all 2>/dev/null || true
    sudo crictl rmi --all 2>/dev/null || true
fi

# Clean up configuration files
echo "🧽 Removing configuration files..."
sudo rm -rf /etc/kubernetes/
sudo rm -rf /var/lib/kubelet/
sudo rm -rf /var/lib/etcd/
sudo rm -rf /etc/cni/net.d/
sudo rm -rf ~/.kube/

# Clean up iptables rules
echo "🔥 Cleaning iptables rules..."
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X

# Remove holds on packages (optional)
echo "📦 Removing package holds..."
sudo apt-mark unhold kubelet kubeadm kubectl 2>/dev/null || true

# Restart services
echo "🔄 Restarting services..."
sudo systemctl start containerd
sudo systemctl restart systemd-resolved

echo
echo "✅ Reset complete!"
echo
echo "📝 Next steps:"
echo "  1. If you want to reinstall, follow the installation guide"
echo "  2. If this was a worker node, you can now join it to a cluster"
echo "  3. If this was a control plane, you can now run 'kubeadm init' again"
echo
echo "💡 Note: You may need to reboot the system to ensure all changes take effect"
