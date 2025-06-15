
# 🚀 Kubernetes Deployments, Rollouts, HPA and Their Relationship with Pods

## 📌 Limitations of Standalone Pods

While Pods are the smallest deployable units in Kubernetes, using them directly has several limitations:
1. **No Replica Management**: You cannot define replica count in a Pod manifest.
2. **No Label Selectors**: `matchLabels` are not supported in Pod specifications.
3. **No Rollout/Rollback**: Kubernetes does not manage Pod history or versioning.

## ✅ Why Use a Deployment?

A **Deployment** is a higher-level controller that manages replica sets and Pods. It ensures:
- High availability through replicas
- Declarative updates (rollouts)
- Rollbacks to previous versions
- Easy integration with autoscaling

> 🧠 Note: You do not need a separate Pod manifest when using Deployments. The Pod is generated from the Deployment spec.

---

## 🛠 Example: Deployment + Service

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
      cloud: aws
  template:
    metadata:
      labels:
        app: nginx
        cloud: aws
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: service-deployment
spec:
  selector:
    app: nginx
    cloud: aws
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: NodePort
```

> ✅ **Deployment ensures desired state**. If a Pod is deleted or crashes, a new one is automatically created.

---

## 📈 Horizontal Pod Autoscaler (HPA)

`HorizontalPodAutoscaler` automatically scales the number of Pods in a Deployment based on metrics like CPU or memory.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx-deployment-hpa
  minReplicas: 4
  maxReplicas: 9
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment-hpa
  labels:
    app: nginx-hpa
spec:
  selector:
    matchLabels:
      app: nginx-hpa
      cloud: aws
  template:
    metadata:
      labels:
        app: nginx-hpa
        cloud: aws
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
```

```bash
# View current autoscaler status
kubectl get hpa
```

> ⚠️ When using HPA, **do not define `replicas:` in the Deployment**.

---

## 🔄 Deployment Rollout and Image Updates

### 🔧 Update the Container Image

```bash
kubectl set image deployment/<deployment-name> <container-name>=<new-image>
```

**Example:**
```bash
kubectl set image deployment/nginx-deployment-hpa nginx=nginx:1.28-perl
```

### 📜 View Rollout History

```bash
kubectl rollout history deployment/<deployment-name>
```

### 🔙 Rollback to Previous Version

```bash
kubectl rollout undo deployment/<deployment-name>
# OR rollback to a specific revision
kubectl rollout undo deployment/<deployment-name> --to-revision=<revision-number>
```

> 💡 Rollbacks are helpful if a new image or configuration causes a failure.

---

## 🧠 Additional Key Concepts

- **Rolling Update**: The default deployment strategy. Updates Pods gradually to ensure availability.
- **Recreate Strategy**: All old Pods are killed before new ones are created (downtime involved).
- **Deployment Status**: Use `kubectl rollout status deployment/<name>` to track progress.
- **Pause/Resume**:
  ```bash
  kubectl rollout pause deployment/<name>
  kubectl rollout resume deployment/<name>
  ```
- **Delete and Recreate**: If you delete the Deployment, all managed Pods and ReplicaSets will also be deleted.

---

## 📚 Reference

- [Kubernetes Deployment Docs](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Kubernetes HPA Docs](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
