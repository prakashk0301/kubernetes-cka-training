# 📘 Kubernetes Installation Guide on Ubuntu 24.04

This guide walks you through setting up a Kubernetes cluster on Ubuntu 24.04 with one master node and two worker nodes using **containerd** as the container runtime.

---

## 🛠️ Prerequisites

- 3 Ubuntu 24.04 machines:
  - 1 Control Plane (Master) node
  - 2 Worker nodes
- Each machine should have:
  - **2 vCPUs minimum**
  - **4 GB RAM minimum** (2 GB is insufficient for modern Kubernetes)
  - **20 GB free disk space**
- SSH access with sudo privileges
- Internet connectivity
- **Unique hostname** for each node
- **Unique MAC address** for each node

---

## 🖥️ Cluster Layout

| Hostname           | Role           | Private IP      |
|--------------------|----------------|------------------|
| `k8s-master-node`  | Control Plane  | `10.168.253.4`   |
| `k8s-worker-node-1`| Worker         | `10.168.253.29`  |
| `k8s-worker-node-2`| Worker         | `10.168.253.10`  |

---

## ⚙️ Installation Steps

### 1. Update System and Set Hostnames (on All Nodes)

Update the system packages:
```bash
sudo apt-get update && sudo apt-get upgrade -y
```

Set unique hostnames (run on respective nodes):
```bash
# On master node:
sudo hostnamectl set-hostname k8s-master-node

# On worker node 1:
sudo hostnamectl set-hostname k8s-worker-node-1

# On worker node 2:
sudo hostnamectl set-hostname k8s-worker-node-2
```

Add hosts entries (on all nodes):
```bash
sudo tee -a /etc/hosts <<EOF
10.168.253.4   k8s-master-node
10.168.253.29  k8s-worker-node-1
10.168.253.10  k8s-worker-node-2
EOF
```

---

### 2. Disable Swap (on All Nodes)

Kubernetes requires swap to be disabled:
```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
```

Verify swap is disabled:
```bash
free -h
```

---

### 3. Load Required Kernel Modules (on All Nodes)

Load kernel modules immediately:
```bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

Configure modules to load at boot:
```bash
sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
```

Configure required sysctl params:
```bash
sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
```

Apply sysctl params without reboot:
```bash
sudo sysctl --system
```

---

### 4. Install and Configure containerd (on All Nodes)

Install containerd:
```bash
sudo apt-get update
sudo apt-get install -y containerd
```

Configure containerd:
```bash
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
```

Enable SystemdCgroup driver:
```bash
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
```

Restart and enable containerd:
```bash
sudo systemctl restart containerd
sudo systemctl enable containerd
```

Verify containerd is running:
```bash
sudo systemctl status containerd
```

---

### 5. Install Kubernetes Components (on All Nodes)

Install required packages:
```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
```

Download and add Kubernetes GPG key:
```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

Add Kubernetes repository:
```bash
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

Install Kubernetes components:
```bash
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

Enable kubelet service:
```bash
sudo systemctl enable kubelet
```

---

### 6. Initialize Control Plane (Master Node Only)

Initialize the cluster with containerd as container runtime:
```bash
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --cri-socket=unix:///var/run/containerd/containerd.sock \
  --apiserver-advertise-address=10.168.253.4
```

**⚠️ Important**: Save the `kubeadm join` command output - you'll need it for worker nodes!

Set up kubectl config for regular user:
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Verify control plane is running:
```bash
kubectl get nodes
kubectl get pods -n kube-system
```

---

### 7. Deploy Calico Network Plugin (Master Node Only)

Install Calico CNI:
```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml
```

Download and apply Calico custom resources:
```bash
curl https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml -O
```

Edit the CIDR if needed (should match --pod-network-cidr):
```bash
kubectl apply -f custom-resources.yaml
```

Wait for Calico pods to be ready:
```bash
kubectl get pods -n calico-system
```

Remove taint from control plane (optional - for single node testing):
```bash
# Only run this if you want to schedule pods on the control plane
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

---

### 8. Join Worker Nodes (Each Worker Node)

**On each worker node**, run the join command you saved from step 6. It will look like:

```bash
sudo kubeadm join 10.168.253.4:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --cri-socket=unix:///var/run/containerd/containerd.sock
```

> **Note**: Replace `<token>` and `<hash>` with the actual values from your master node initialization.

If you lost the join command, generate a new one on the control plane:
```bash
kubeadm token create --print-join-command
```

---

### 9. Verify Cluster Status (Master Node)

Check all nodes are ready:
```bash
kubectl get nodes -o wide
```

Expected output (may take a few minutes for all nodes to become Ready):
```
NAME                STATUS   ROLES           AGE     VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
k8s-master-node     Ready    control-plane   15m     v1.32.0   10.168.253.4     <none>        Ubuntu 24.04.1 LTS   6.8.0-31-generic    containerd://1.7.12
k8s-worker-node-1   Ready    <none>          8m      v1.32.0   10.168.253.29    <none>        Ubuntu 24.04.1 LTS   6.8.0-31-generic    containerd://1.7.12
k8s-worker-node-2   Ready    <none>          8m      v1.32.0   10.168.253.10    <none>        Ubuntu 24.04.1 LTS   6.8.0-31-generic    containerd://1.7.12
```

Check system pods:
```bash
kubectl get pods -n kube-system
```

Check Calico pods:
```bash
kubectl get pods -n calico-system
```

---

## 🧪 Test Your Cluster

Deploy a test application:
```bash
kubectl create deployment nginx-test --image=nginx:1.25
kubectl expose deployment nginx-test --port=80 --type=NodePort
kubectl get pods,svc
```

---

## 🔧 Troubleshooting

### Common Issues:

1. **Nodes not joining**: 
   - Check firewall settings
   - Ensure all nodes can reach the control plane on port 6443
   - Verify containerd is running: `sudo systemctl status containerd`

2. **Pods stuck in Pending**:
   - Check if CNI is properly installed: `kubectl get pods -n calico-system`
   - Verify nodes are Ready: `kubectl get nodes`

3. **kubelet not starting**:
   ```bash
   sudo systemctl status kubelet
   sudo journalctl -xeu kubelet
   ```

4. **Reset cluster** (if needed):
   ```bash
   sudo kubeadm reset
   sudo systemctl stop kubelet
   sudo systemctl stop containerd
   sudo rm -rf /etc/cni/net.d
   sudo systemctl start containerd
   sudo systemctl start kubelet
   ```

---

## 🔒 Security Considerations

1. **Firewall Rules** (configure as needed):
   ```bash
   # Control plane
   sudo ufw allow 6443/tcp    # Kubernetes API
   sudo ufw allow 2379:2380/tcp  # etcd
   sudo ufw allow 10250/tcp   # kubelet API
   sudo ufw allow 10251/tcp   # kube-scheduler
   sudo ufw allow 10252/tcp   # kube-controller-manager
   
   # Worker nodes
   sudo ufw allow 10250/tcp   # kubelet API
   sudo ufw allow 30000:32767/tcp  # NodePort Services
   ```

2. **Regular Updates**:
   ```bash
   sudo apt update && sudo apt upgrade
   kubectl version --client
   ```

---

## ✅ Success

🎉 **Congratulations!** You now have a fully functional Kubernetes 1.32 cluster on Ubuntu 24.04 with:

- ✅ **containerd** as container runtime (CRI-compliant)
- ✅ **Calico** CNI for pod networking
- ✅ **1 control plane** node and **2 worker** nodes
- ✅ **Secure** cluster configuration
- ✅ **Production-ready** setup

---

## 📚 What's Next?

1. **Learn kubectl basics**: `kubectl get pods --all-namespaces`
2. **Deploy applications**: Try the manifests in other directories of this repo
3. **Monitor your cluster**: Consider installing metrics-server
4. **Backup etcd**: Set up regular etcd backups for production

---

## 📖 Additional Resources

- [Kubernetes Official Documentation](https://kubernetes.io/docs/)
- [CKA Exam Curriculum](https://github.com/cncf/curriculum)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Calico Documentation](https://docs.projectcalico.org/)

---

## 🛠️ Helper Scripts

This directory includes helper scripts to assist with your installation:

### 🔍 Verification Script
Run this script to verify your Kubernetes installation:
```bash
chmod +x verify-installation.sh
./verify-installation.sh
```

### 🧹 Reset Script
If something goes wrong and you need to start over:
```bash
chmod +x reset-cluster.sh
./reset-cluster.sh
```

---

**Last Updated**: December 2024  
**Kubernetes Version**: 1.32+  
**Ubuntu Version**: 24.04 LTS  
**Container Runtime**: containerd

