# 📦 Kubernetes ConfigMap Lab – Full Guide

## 🧠 What is a ConfigMap in Kubernetes?
**Kubernetes ConfigMap** is an object used to store **non-sensitive** configuration data in key-value pairs.

It helps you **decouple configuration from container images** and code.

## ❓Why Use a ConfigMap?
| Problem                           | How ConfigMap Helps                          |
|-----------------------------------|-----------------------------------------------|
| Hardcoded app configs in image    | Externalize config as key-values              |
| Rebuild needed for config change  | No rebuild – just update ConfigMap            |
| Managing different envs manually  | Use env-specific ConfigMaps                   |

## 📅 When to Use ConfigMaps?
Use **ConfigMaps** when your app needs:
- Environment-specific configurations
- Feature flags, app versions, modes (dev, prod)
- CLI arguments or config files

## ✅ Lab Goal
Deploy a sample application that uses configuration stored in a **ConfigMap** via environment variables and file mounts.

---

## 🧾 Step-by-Step Lab Instructions

### 🧩 1. Create a ConfigMap

**File:** `app-config.yaml`
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_ENV: production
  APP_DEBUG: "false"
  APP_VERSION: "1.0.0"
```

Apply the ConfigMap:
```bash
kubectl apply -f app-config.yaml
kubectl get configmaps
kubectl describe configmap app-config
```

---

### 🧪 2. Use ConfigMap in a Pod via Environment Variables

**File:** `pod-using-configmap.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: configmap-demo
spec:
  containers:
  - name: demo-container
    image: busybox
    command: ["sh", "-c", "echo ENV=$APP_ENV VERSION=$APP_VERSION DEBUG=$APP_DEBUG && sleep 3600"]
    env:
    - name: APP_ENV
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: APP_ENV
    - name: APP_VERSION
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: APP_VERSION
    - name: APP_DEBUG
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: APP_DEBUG
```

Apply the Pod:
```bash
kubectl apply -f pod-using-configmap.yaml
kubectl exec -it configmap-demo -- sh
```

---

### 📂 3. Mount ConfigMap as a Volume

**File:** `pod-configmap-volume.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: configmap-volume-demo
spec:
  containers:
  - name: demo-container
    image: busybox
    command: [ "sh", "-c", "cat /etc/config/APP_ENV && cat /etc/config/APP_VERSION && cat /etc/config/APP_DEBUG && sleep 3600" ]
    volumeMounts:
    - name: config-vol
      mountPath: /etc/config
  volumes:
  - name: config-vol
    configMap:
      name: app-config
```

Apply the Pod:
```bash
kubectl apply -f pod-configmap-volume.yaml
kubectl exec -it configmap-volume-demo -- sh
ls /etc/config
cat /etc/config/APP_ENV
```

---

## ✅ Benefits of ConfigMaps

| Benefit                         | Description                                   |
|----------------------------------|-----------------------------------------------|
| **Decouples config from image**  | Reuse the same image across environments      |
| **Env-specific settings**        | Inject different values per cluster/namespace |
| **Used in many ways**            | env vars, volumes, CLI args, etc.             |
| **Hot reload support**           | With projected volumes + restart, can update  |

---

## 📌 How to View a ConfigMap

```bash
kubectl get configmap app-config -o yaml
kubectl describe configmap app-config
```

## 📁 Final File Structure

```bash
.
├── app-config.yaml
├── pod-using-configmap.yaml
├── pod-configmap-volume.yaml
└── README.md
```