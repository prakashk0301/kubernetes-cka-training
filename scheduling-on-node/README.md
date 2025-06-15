
# 🧪 Advanced Kubernetes Scheduling Labs

> **Environment:**  
> Self-managed Kubernetes cluster on AWS Ubuntu EC2 instances  
> 🖥️ 1 Master Node  
> 🖥️ 2 Worker Nodes

---

## ✅ Prerequisites

- Kubernetes cluster is up and running
- `kubectl` configured and working
- Worker nodes are labeled to support affinity/anti-affinity scheduling

### 🏷️ Label Your Nodes

Apply labels to the worker nodes for testing:

```bash
kubectl label nodes <worker-node-1> disktype=ssd zone=us-east-1a
kubectl label nodes <worker-node-2> disktype=hdd zone=us-east-1b
```

Check the labels:

```bash
kubectl get nodes --show-labels
```

---

## 1️⃣ Node Selector: 

nodeSelector is the simplest form of node scheduling constraint in Kubernetes. It is used to constrain a Pod to be scheduled only on nodes that have a specific label

### 🧾 node-selector-pod.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-ssd
spec:
  containers:
  - name: nginx
    image: nginx
  nodeSelector:
    disktype: ssd
```

### 🔍 Description

This pod will only be scheduled on nodes labeled with `disktype=ssd`.

---

## 2️⃣ Node Affinity

### 🧾 node-affinity-pod.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-node-affinity
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:    #hard condition
        nodeSelectorTerms:
        - matchExpressions:                               #actual condition that a nodes label's must meet      
          - key: disktype                                 #this looks for a label on worker   
            operator: In                                  #operation means the value of key (disktype)

            values:
            - ssd
      preferredDuringSchedulingIgnoredDuringExecution:   #soft rule, scheduler try to find a node that meets this condition, if it can's then pod will on any worker node that meets the required rule

      - weight: 1                                           #the node with the highest score will be chosen
        preference:
          matchExpressions:
          - key: zone
            operator: In
            values:
            - us-east-1a
  containers:
  - name: nginx
    image: nginx
```

Hard (requiredDuringSchedulingIgnoredDuringExecution) rules must be satisfied for a Pod to be scheduled.
→ If these rules are not met, the Pod will not be scheduled.

Soft (preferredDuringSchedulingIgnoredDuringExecution) rules are preferences.
→ If possible, the scheduler tries to place the Pod on a node that satisfies these rules, but if not, the Pod can still be scheduled on any node that meets the required rules.

You can define both required and preferred node affinity rules in the same Pod specification.

You can define only required rules in a Pod manifest if you want strict control.

You can define only preferred rules in a Pod manifest if you want flexible placement with preferences.

### 🔍 Description

- **Required:** Must be scheduled on nodes with `disktype=ssd`
- **Preferred:** Ideally run in `zone=us-east-1a`

---

## 3️⃣ Pod Affinity

### 🧾 base-pod.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: base-pod
  labels:
    app: myapp
spec:
  containers:
  - name: nginx
    image: nginx
```

### 🧾 pod-with-affinity.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-affinity
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - myapp
        topologyKey: "kubernetes.io/hostname"
  containers:
  - name: nginx
    image: nginx
```

### 🔍 Description

The second pod will be scheduled on the **same node** where `base-pod` is running (based on label `app=myapp`).

---

## 4️⃣ Pod Anti-Affinity

### 🧾 pod-anti-affinity.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-anti-affinity
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - myapp
        topologyKey: "kubernetes.io/hostname"
  containers:
  - name: nginx
    image: nginx
```

### 🔍 Description

This pod will **not be scheduled** on a node that already has a pod with the label `app=myapp`.

---

## 5️⃣ Taints and Tolerations

### 🧪 Taint a Node

Run this to taint a worker node:

```bash
kubectl taint nodes <worker-node-1> key=value:NoSchedule
```

Verify:

```bash
kubectl describe node <worker-node-1> | grep Taint
```

### 🧾 toleration-pod.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: toleration-pod
spec:
  containers:
  - name: nginx
    image: nginx
  tolerations:
  - key: "key"
    operator: "Equal"
    value: "value"
    effect: "NoSchedule"
```

### 🔍 Description

This pod includes a toleration that matches the taint on the node, allowing it to be scheduled on it.

---

## 🧹 Clean Up

To remove all pods:

```bash
kubectl delete pod pod-ssd pod-node-affinity base-pod pod-with-affinity pod-with-anti-affinity toleration-pod
```

To remove the taint from the node:

```bash
kubectl taint nodes <worker-node-1> key=value:NoSchedule-
```

---

## 📊 Summary Table

| Feature            | Description                                                            |
|--------------------|------------------------------------------------------------------------|
| Node Selector      | Schedule a pod on a node with specific labels                         |
| Node Affinity      | Require or prefer node selection using `matchExpressions`             |
| Pod Affinity       | Schedule a pod close to another pod based on label match              |
| Pod Anti-Affinity  | Prevent pods from being scheduled on same node as others with labels  |
| Taints/Tolerations | Mark nodes as "special" and only allow matching pods to run on them   |

---

## 💡 Tips

- Always use `topologyKey: "kubernetes.io/hostname"` for node-level pod affinity/anti-affinity.
- Test affinity and anti-affinity by deploying multiple pods and observing node placement.
- Use `kubectl get pods -o wide` to verify where pods are scheduled.
