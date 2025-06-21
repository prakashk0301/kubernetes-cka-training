# Kubernetes NetworkPolicy Lab – Full Guide

## 🧠 What is a NetworkPolicy in Kubernetes?
A **NetworkPolicy** is a Kubernetes resource used to control **network traffic** between **Pods**, **Namespaces**, and **external endpoints**. It allows you to define **rules** about **who can talk to whom** inside the cluster.

## ❓ Why Use Network Policies?

| Problem                               | NetworkPolicy Helps With                  |
|---------------------------------------|--------------------------------------------|
| Unrestricted Pod-to-Pod communication | Restrict based on labels/namespaces        |
| No control over ingress/egress traffic| Allow/deny incoming or outgoing traffic    |
| No isolation between environments     | Enforce namespace-level security zones     |

## 📅 When to Use Network Policies?
Use them when you want to:
- Isolate environments (e.g., dev vs prod)
- Restrict app access to specific DBs or services
- Enforce Zero Trust networking

---

## ✅ Prerequisite: Enable a Network Plugin

For `kubeadm`-based Ubuntu cluster, install **Calico** (supports NetworkPolicy natively):

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
```

**Verify:**
```bash
kubectl get pods -n kube-system
kubectl get nodes
```

---

## 🧾 Lab: Isolate Frontend & Backend Using NetworkPolicy

**Scenario:**
- **Namespace:** `web`
- **Pods:**
  - `frontend`: should be allowed to connect to `backend`
  - `backend`: should only accept traffic from `frontend`

### 🧱 Step 1: Create Namespace and Deploy Pods

**namespace.yaml**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: web
```

**frontend.yaml**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: web
  labels:
    app: frontend
spec:
  containers:
  - name: frontend
    image: busybox
    command: ["sleep", "3600"]
```

**backend.yaml**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: web
  labels:
    app: backend
spec:
  containers:
  - name: backend
    image: busybox
    command: ["sleep", "3600"]
```

**Apply all:**
```bash
kubectl apply -f namespace.yaml
kubectl apply -f frontend.yaml
kubectl apply -f backend.yaml
```

**Test before policy:**
```bash
kubectl exec -n web frontend -- ping backend
```

---

### 🔒 Step 2: Create a NetworkPolicy (Deny All)

**deny-all.yaml**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: web
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

**Apply and test again:**
```bash
kubectl apply -f deny-all.yaml
kubectl exec -n web frontend -- ping backend  # Should fail
```

---

### ✅ Step 3: Allow Frontend to Access Backend

**allow-frontend.yaml**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
  namespace: web
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
```

**Apply and test again:**
```bash
kubectl apply -f allow-frontend.yaml
kubectl exec -n web frontend -- ping backend  # Should now succeed
```

---

## ✅ Key Concepts

| Field        | Description                        |
|--------------|------------------------------------|
| podSelector  | Selects the Pods this policy applies to |
| ingress      | Controls incoming connections      |
| egress       | Controls outgoing connections      |
| from / to    | Define source/destination Pods or namespaces |

---

## 🧪 Bonus Lab: TCP-Based Testing (More Reliable Than Ping)

### 🔍 Why Not Use ping?
Most NetworkPolicy implementations (like Calico) do not block ICMP/ping by default. Instead, they enforce policies on TCP/UDP traffic. So it's better to test using wget, curl, or netcat.

### 🧱 Updated Scenario
- Update the backend Pod to run a minimal HTTP server.
- Test access using wget from the frontend Pod.

#### ✅ Step 1: Update backend.yaml

Replace or modify your backend.yaml with this:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: web
  labels:
    app: backend
spec:
  containers:
  - name: backend
    image: hashicorp/http-echo
    args:
    - "-text=hello from backend"
    ports:
    - containerPort: 5678
```

**Apply:**
```bash
kubectl apply -f backend.yaml
```

#### ✅ Step 2: Test Without NetworkPolicy (Should Work)
```bash
kubectl exec -n web frontend -- wget -qO- http://backend:5678
```
**Expected output:**
```
hello from backend
```

#### 🔒 Step 3: Apply Deny-All Policy (Should Fail)
```bash
kubectl apply -f deny-all.yaml
kubectl exec -n web frontend -- wget -qO- http://backend:5678
```
**Expected output:**
```
wget: can't connect to remote host (10.x.x.x): Connection timed out
```

#### ✅ Step 4: Apply Allow Policy (Should Work Again)
```bash
kubectl apply -f allow-frontend.yaml
kubectl exec -n web frontend -- wget -qO- http://backend:5678
```
**Expected output:**
```
hello from backend
```

---

## 📌 Summary Table

| Step                     | Command                                 | Expected Result |
|--------------------------|-----------------------------------------|-----------------|
| No policy applied        | wget from frontend to backend           | ✅ Success      |
| Deny-all policy applied  | wget from frontend to backend           | ❌ Blocked      |
| Allow-frontend policy    | wget from frontend to backend           | ✅ Success      |

---

## 📌 How to View Applied Network Policies

```bash
kubectl get networkpolicy -n web
kubectl describe networkpolicy allow-frontend -n web
```

---

## 📁 Final File Structure

```
.
├── namespace.yaml
├── frontend.yaml
├── backend.yaml
├── deny-all.yaml
├── allow-frontend.yaml
└── README.md
```