# 🔐 Kubernetes Secrets Lab – Full Guide

## 🧠 What is a Secret in Kubernetes?
**Kubernetes Secret** is an object used to store sensitive data such as:
- Database credentials
- API keys
- TLS certificates
- OAuth tokens

It allows you to **avoid hardcoding sensitive values** in application code or Pod specifications.

## ❓Why Use a Secret?
| Problem                          | How Secret Helps                            |
|----------------------------------|----------------------------------------------|
| Hardcoding sensitive data        | Stores securely, decouples from code         |
| Shared configs in plain YAML     | Secures values using base64 encoding         |
| Rotation and management issues   | Secrets can be updated dynamically           |

## 📅 When to Use Secrets?
Use **Secrets** whenever your application needs to:
- Connect to databases or message brokers
- Access APIs or third-party services securely
- Use SSL/TLS certificates or tokens

## 🛠️ How Kubernetes Secrets Work
Kubernetes stores secrets in **base64** format (optionally encrypted at rest). Secrets can be:
- Exposed as environment variables
- Mounted as volumes
- Used in container commands

## ✅ Lab Goal
Deploy a web application (frontend) that connects to a **PostgreSQL** database using credentials stored in a **Secret**.

---

## 🧾 Step-by-Step Lab Instructions

### 🧩 1. Create Secret for DB Credentials
**File:** `db-secret.yaml`
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
type: Opaque
data:
  username: cG9zdGdyZXM=     # base64 of 'postgres'
  password: c2VjcmV0MTIz     # base64 of 'secret123'
  dbname: YXBwZGI=           # base64 of 'appdb'
```

To generate base64 values:
```bash
echo -n 'postgres' | base64
echo -n 'secret123' | base64
echo -n 'appdb' | base64
```

Apply:
```bash
kubectl apply -f db-secret.yaml
kubectl get secrets
kubectl describe secret postgres-secret
```

---

### 🛢️ 2. Deploy PostgreSQL Database

**File:** `postgres-deployment.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: dbname
```

**File:** `postgres-service.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
```

Apply:
```bash
kubectl apply -f postgres-deployment.yaml
kubectl apply -f postgres-service.yaml
```

---

### 🌐 3. Deploy Frontend App That Uses the Secret

**File:** `frontend-deployment.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: gauravtiwari/flask-postgres-demo:latest
        ports:
        - containerPort: 5000
        env:
        - name: DB_HOST
          value: postgres
        - name: DB_PORT
          value: "5432"
        - name: DB_NAME
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: dbname
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: DB_PASS
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
```

**File:** `frontend-service.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  selector:
    app: frontend
  ports:
    - port: 80
      targetPort: 5000
  type: LoadBalancer
```

Apply:
```bash
kubectl apply -f frontend-deployment.yaml
kubectl apply -f frontend-service.yaml
```

---

### 🔍 4. Test the Application

```bash
kubectl get pods
kubectl get svc
kubectl port-forward svc/frontend 8080:80
```

Visit: http://localhost:8080

---

## 📌 How to View a Secret Safely

```bash
kubectl get secret postgres-secret -o yaml
echo "c2VjcmV0MTIz" | base64 --decode
```

## ✅ Benefits of Using Secrets

| Benefit                          | Description                                     |
|----------------------------------|-------------------------------------------------|
| Security                         | Avoid hardcoding credentials in Pod YAML        |
| Separation of concern            | Config and secret managed independently         |
| Rotation                         | Can be updated and reloaded without app redeploy |
| Compatibility                    | Works with env vars and volumes                 |
| Auditing                         | RBAC & audit logs help control access           |

## 📁 Final File Structure

```bash
.
├── db-secret.yaml
├── postgres-deployment.yaml
├── postgres-service.yaml
├── frontend-deployment.yaml
├── frontend-service.yaml
└── README.md
```