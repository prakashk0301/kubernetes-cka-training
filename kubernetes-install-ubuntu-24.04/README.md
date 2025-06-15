# 📘 Kubernetes Installation Guide on Ubuntu 24.04

This guide walks you through setting up a Kubernetes cluster on Ubuntu 24.04 with one master node and two worker nodes.

---

## 🛠️ Prerequisites

- 3 Ubuntu 24.04 machines:
  - 1 Master node
  - 2 Worker nodes
- Each machine should have:
  - 2 vCPUs
  - 2 GB RAM
  - 20 GB free disk space
- SSH access with sudo privileges
- Internet connectivity

---

## 🖥️ Cluster Layout

| Hostname           | Role        | Private IP      |
|--------------------|-------------|------------------|
| `k8s-master-node`  | Master      | `10.168.253.4`   |
| `k8s-worker-node-1`| Worker      | `10.168.253.29`  |
| `k8s-worker-node-2`| Worker      | `10.168.253.10`  |

---

## ⚙️ Installation Steps

### 1. Connect to all the nodes VMs.


---

### 2. Disable Swap (on All Nodes)

```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
```

---

### 3. Load Required Kernel Modules (on All Nodes)

```bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

```bash
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
```

```bash
sudo tee /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system
```

---

### 4. Install Docker (on All Nodes)

```bash
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker
```

---

### 5. Install Kubernetes Components (on All Nodes)

```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
```

```bash
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg \
  https://packages.cloud.google.com/apt/doc/apt-key.gpg
```

```bash
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] \
  https://apt.kubernetes.io/ kubernetes-xenial main" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list
```

```bash
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

---

### 6. Initialize Control Plane (Master Node Only)

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

Set up kubectl config:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

---

### 7. Deploy Calico Network Plugin (Master Node Only)

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

Check Calico status:

```bash
kubectl get pods --all-namespaces
```

---

### 8. Join Worker Nodes (Each Worker Node)

Use the command printed after `kubeadm init`. Example:

```bash
sudo kubeadm join 10.168.253.4:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

> Replace `<token>` and `<hash>` with your actual values from the master node.

---

### 9. Check Cluster Status (Master Node)

```bash
kubectl get nodes
```

Expected output:

```
NAME                STATUS   ROLES           AGE     VERSION
k8s-master-node     Ready    control-plane   10m     v1.30.0
k8s-worker-node-1   Ready    <none>          5m      v1.30.0
k8s-worker-node-2   Ready    <none>          5m      v1.30.0
```

---

## ✅ Success

You now have a working Kubernetes cluster on Ubuntu 24.04 with one control-plane node and two worker nodes.

---

