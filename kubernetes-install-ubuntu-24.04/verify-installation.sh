#!/bin/bash

# 🔍 Kubernetes Cluster Verification Script
# This script helps verify your Kubernetes installation on Ubuntu 24.04

echo "🔍 Kubernetes Cluster Verification Script"
echo "========================================"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check status
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ PASS${NC}"
    else
        echo -e "${RED}❌ FAIL${NC}"
    fi
}

# Check if script is run as regular user
echo "👤 Checking user permissions..."
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}❌ Please run this script as a regular user (not root/sudo)${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Running as regular user${NC}"
fi
echo

# Check swap status
echo "💾 Checking swap status..."
if [ $(swapon --show | wc -l) -eq 0 ]; then
    echo -e "${GREEN}✅ Swap is disabled${NC}"
else
    echo -e "${RED}❌ Swap is still enabled - please disable it${NC}"
fi
echo

# Check kernel modules
echo "🔧 Checking kernel modules..."
echo -n "overlay module: "
lsmod | grep overlay > /dev/null
check_status

echo -n "br_netfilter module: "
lsmod | grep br_netfilter > /dev/null
check_status
echo

# Check sysctl settings
echo "⚙️  Checking sysctl settings..."
echo -n "net.bridge.bridge-nf-call-iptables: "
if [ $(sysctl -n net.bridge.bridge-nf-call-iptables) -eq 1 ]; then
    echo -e "${GREEN}✅ PASS${NC}"
else
    echo -e "${RED}❌ FAIL${NC}"
fi

echo -n "net.ipv4.ip_forward: "
if [ $(sysctl -n net.ipv4.ip_forward) -eq 1 ]; then
    echo -e "${GREEN}✅ PASS${NC}"
else
    echo -e "${RED}❌ FAIL${NC}"
fi
echo

# Check containerd
echo "📦 Checking containerd..."
echo -n "containerd service status: "
systemctl is-active containerd > /dev/null
check_status

echo -n "containerd socket: "
if [ -S /var/run/containerd/containerd.sock ]; then
    echo -e "${GREEN}✅ PASS${NC}"
else
    echo -e "${RED}❌ FAIL${NC}"
fi
echo

# Check Kubernetes components
echo "☸️  Checking Kubernetes components..."
echo -n "kubelet service: "
systemctl is-active kubelet > /dev/null
check_status

echo -n "kubectl command: "
which kubectl > /dev/null
check_status

echo -n "kubeadm command: "
which kubeadm > /dev/null
check_status
echo

# Check cluster status (only if kubectl is configured)
if [ -f ~/.kube/config ]; then
    echo "🌐 Checking cluster status..."
    
    echo -n "API server connectivity: "
    kubectl cluster-info > /dev/null 2>&1
    check_status
    
    echo -n "Nodes status: "
    kubectl get nodes --no-headers 2>/dev/null | grep -v "NotReady" > /dev/null
    check_status
    
    echo -n "System pods running: "
    SYSTEM_PODS_NOT_RUNNING=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l)
    if [ $SYSTEM_PODS_NOT_RUNNING -eq 0 ]; then
        echo -e "${GREEN}✅ PASS${NC}"
    else
        echo -e "${YELLOW}⚠️  Some system pods are not running${NC}"
    fi
    
    echo -n "CNI pods status: "
    CNI_PODS_NOT_RUNNING=$(kubectl get pods -n calico-system --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l)
    if [ $CNI_PODS_NOT_RUNNING -eq 0 ]; then
        echo -e "${GREEN}✅ PASS${NC}"
    else
        echo -e "${YELLOW}⚠️  Some CNI pods are not running${NC}"
    fi
    
    echo
    echo "📊 Cluster Information:"
    echo "----------------------"
    kubectl get nodes -o wide 2>/dev/null || echo "Cannot retrieve node information"
    
else
    echo -e "${YELLOW}⚠️  kubectl not configured for this user${NC}"
    echo "If this is a worker node, this is expected."
    echo "If this is the control plane, run:"
    echo "  mkdir -p \$HOME/.kube"
    echo "  sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config"
    echo "  sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"
fi

echo
echo "🏁 Verification complete!"
echo "========================"
echo

# Provide recommendations
echo "💡 Recommendations:"
echo "-------------------"
echo "1. If any checks failed, review the installation guide"
echo "2. Check system logs: sudo journalctl -u kubelet"
echo "3. Verify firewall settings if nodes can't join"
echo "4. Ensure all nodes have unique hostnames and MAC addresses"
echo
echo "📚 For troubleshooting, see the installation guide or run:"
echo "   kubectl get events --sort-by=.metadata.creationTimestamp"
echo
