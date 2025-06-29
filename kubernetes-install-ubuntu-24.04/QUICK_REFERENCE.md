# 📋 Kubernetes Installation Quick Reference

## 🚀 Essential Commands

### Pre-Installation Check
```bash
# Check system requirements
free -h                    # Check memory (need 4GB+)
nproc                      # Check CPU cores (need 2+)
df -h                      # Check disk space (need 20GB+)
```

### Installation Verification
```bash
# Check service status
sudo systemctl status containerd
sudo systemctl status kubelet

# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces
kubectl cluster-info
```

### Troubleshooting Commands
```bash
# Check kubelet logs
sudo journalctl -xeu kubelet

# Check containerd logs
sudo journalctl -xeu containerd

# Check cluster events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check node conditions
kubectl describe node <node-name>
```

### Cluster Management
```bash
# Generate new join token
kubeadm token create --print-join-command

# Check certificates expiration
kubeadm certs check-expiration

# Drain a node (for maintenance)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Uncordon a node
kubectl uncordon <node-name>
```

## 🔧 Configuration Files

### Important Paths
```
/etc/kubernetes/admin.conf          # Kubectl config
/etc/containerd/config.toml         # Containerd config
/etc/systemd/system/kubelet.service # Kubelet service
/var/lib/kubelet/config.yaml        # Kubelet config
/etc/cni/net.d/                     # CNI config
```

### Log Locations
```
/var/log/pods/                      # Pod logs
sudo journalctl -u kubelet          # Kubelet logs
sudo journalctl -u containerd       # Containerd logs
```

## 🌐 Network Configuration

### Required Ports (Control Plane)
- `6443` - Kubernetes API server
- `2379-2380` - etcd server client API
- `10250` - kubelet API
- `10251` - kube-scheduler
- `10252` - kube-controller-manager

### Required Ports (Worker Nodes)
- `10250` - kubelet API
- `30000-32767` - NodePort Services

### Firewall Commands (if needed)
```bash
# Control plane
sudo ufw allow 6443/tcp
sudo ufw allow 2379:2380/tcp
sudo ufw allow 10250/tcp
sudo ufw allow 10251/tcp
sudo ufw allow 10252/tcp

# Worker nodes
sudo ufw allow 10250/tcp
sudo ufw allow 30000:32767/tcp
```

## 🔄 Common Issues & Solutions

### 1. kubelet won't start
```bash
# Check the status
sudo systemctl status kubelet

# Reset and restart
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

### 2. Nodes stuck in NotReady
```bash
# Check CNI installation
kubectl get pods -n calico-system

# Restart CNI
kubectl delete pods -n calico-system --all
```

### 3. Pods stuck in Pending
```bash
# Check node resources
kubectl describe nodes

# Check events
kubectl get events --field-selector type=Warning
```

### 4. Container runtime errors
```bash
# Restart containerd
sudo systemctl restart containerd

# Check containerd config
sudo containerd config default
```

## 📦 Package Management

### Hold/Unhold Kubernetes packages
```bash
# Hold packages (prevent updates)
sudo apt-mark hold kubelet kubeadm kubectl

# Unhold packages
sudo apt-mark unhold kubelet kubeadm kubectl

# Check held packages
apt-mark showhold
```

### Update Kubernetes (patch version)
```bash
# Update to latest patch version
sudo apt update
sudo apt-cache madison kubeadm
sudo apt-get install -y kubeadm=1.32.x-1.1

# Update cluster
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.32.x
```

## 🎯 Testing Your Cluster

### Deploy test workloads
```bash
# Create a test deployment
kubectl create deployment nginx-test --image=nginx:1.25
kubectl scale deployment nginx-test --replicas=3
kubectl expose deployment nginx-test --port=80 --type=NodePort

# Check the deployment
kubectl get pods -o wide
kubectl get svc nginx-test
```

### Check cluster health
```bash
# Component status
kubectl get componentstatuses

# API server health
kubectl get --raw='/healthz'

# Node conditions
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,REASON:.status.conditions[-1].reason
```

---

**Quick Reference Card - Kubernetes 1.32 on Ubuntu 24.04**
