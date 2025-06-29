# 📦 Kubernetes ConfigMap - Complete Guide

## 🧠 What is a ConfigMap in Kubernetes?
**Kubernetes ConfigMap** is an object used to store **non-sensitive** configuration data in key-value pairs. It helps you **decouple configuration from container images** and code, following the twelve-factor app methodology.

---

## ❓ Why Use ConfigMaps?

| Problem | How ConfigMap Helps |
|---------|-------------------|
| Hardcoded app configs in image | Externalize config as key-values |
| Rebuild needed for config changes | No rebuild – just update ConfigMap |
| Managing different environments manually | Use environment-specific ConfigMaps |
| Configuration drift between environments | Consistent configuration management |

---

## 📅 When to Use ConfigMaps?

**✅ Use ConfigMaps for:**
- Application configuration (database URLs, feature flags)
- Environment-specific settings (dev, staging, prod)
- Configuration files (nginx.conf, application.properties)
- CLI arguments and startup parameters
- Non-sensitive data that varies between deployments

**❌ Do NOT use ConfigMaps for:**
- Sensitive data (passwords, tokens) - use **Secrets** instead
- Large binary files - use **Volumes** instead
- Data exceeding 1MB - use external config stores

---

## 🛠️ Creating ConfigMaps

### Method 1: From Literals
```bash
# Create from command line
kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=APP_DEBUG=false \
  --from-literal=DATABASE_URL=postgresql://localhost:5432/myapp

# Verify creation
kubectl get configmap app-config -o yaml
```

### Method 2: From Files
```bash
# Create config file
echo "server.port=8080" > application.properties
echo "logging.level=INFO" >> application.properties

# Create ConfigMap from file
kubectl create configmap app-properties --from-file=application.properties

# Create from multiple files
kubectl create configmap web-config \
  --from-file=nginx.conf \
  --from-file=mime.types \
  --from-file=ssl.conf
```

### Method 3: From Directory
```bash
# Create from entire directory
mkdir config-files
echo "production settings" > config-files/env.conf
echo "debug=false" > config-files/debug.conf

kubectl create configmap dir-config --from-file=config-files/
```

### Method 4: YAML Manifest
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: comprehensive-config
  namespace: default
  labels:
    app: myapp
    environment: production
    version: v1.0.0
data:
  # Simple key-value pairs
  APP_ENV: "production"
  APP_DEBUG: "false"
  APP_VERSION: "1.0.0"
  DATABASE_URL: "postgresql://db.example.com:5432/myapp"
  REDIS_URL: "redis://cache.example.com:6379"
  
  # Configuration files
  nginx.conf: |
    server {
        listen 80;
        server_name example.com;
        
        location / {
            proxy_pass http://backend:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
  
  application.yaml: |
    server:
      port: 8080
    
    spring:
      datasource:
        url: jdbc:postgresql://db:5432/myapp
        username: ${DB_USER}
        password: ${DB_PASSWORD}
      
    logging:
      level:
        com.example: DEBUG
        org.springframework: INFO
  
  logback.xml: |
    <?xml version="1.0" encoding="UTF-8"?>
    <configuration>
        <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
            <encoder>
                <pattern>%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern>
            </encoder>
        </appender>
        <root level="INFO">
            <appender-ref ref="STDOUT" />
        </root>
    </configuration>
```

---

## 🔧 Using ConfigMaps in Pods

### 1. Environment Variables (Individual Keys)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: env-demo
spec:
  containers:
  - name: demo
    image: nginx:1.25
    env:
    - name: APP_ENV
      valueFrom:
        configMapKeyRef:
          name: comprehensive-config
          key: APP_ENV
    - name: DATABASE_URL
      valueFrom:
        configMapKeyRef:
          name: comprehensive-config
          key: DATABASE_URL
          optional: false  # Pod fails if key doesn't exist
```

### 2. Environment Variables (All Keys)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: envfrom-demo
spec:
  containers:
  - name: demo
    image: nginx:1.25
    envFrom:
    - configMapRef:
        name: comprehensive-config
        optional: false
    - configMapRef:
        name: optional-config
        optional: true  # Pod starts even if ConfigMap doesn't exist
```

### 3. Volume Mounts (Files)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: volume-demo
spec:
  containers:
  - name: demo
    image: nginx:1.25
    volumeMounts:
    - name: config-volume
      mountPath: /etc/nginx/conf.d
      readOnly: true
    - name: app-config
      mountPath: /etc/app
      readOnly: true
  volumes:
  - name: config-volume
    configMap:
      name: comprehensive-config
      items:
      - key: nginx.conf
        path: default.conf
  - name: app-config
    configMap:
      name: comprehensive-config
      items:
      - key: application.yaml
        path: application.yaml
      - key: logback.xml
        path: logback.xml
      defaultMode: 0644
```

### 4. Projected Volumes (Multiple Sources)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: projected-demo
spec:
  containers:
  - name: demo
    image: busybox:1.35
    command: ["sleep", "3600"]
    volumeMounts:
    - name: all-config
      mountPath: /etc/config
      readOnly: true
  volumes:
  - name: all-config
    projected:
      sources:
      - configMap:
          name: comprehensive-config
          items:
          - key: application.yaml
            path: app/application.yaml
      - configMap:
          name: comprehensive-config
          items:
          - key: logback.xml
            path: app/logback.xml
      - secret:
          name: app-secrets
          items:
          - key: database-password
            path: secrets/db-password
```

---

## 🚀 Production Deployment Examples

### Complete Application Deployment
```yaml
# ConfigMap for application configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
  namespace: production
  labels:
    app: webapp
    component: config
    version: v2.1.0
data:
  APP_ENV: "production"
  LOG_LEVEL: "info"
  SERVER_PORT: "8080"
  METRICS_ENABLED: "true"
  HEALTH_CHECK_PATH: "/health"
  
  # Application configuration file
  app-config.json: |
    {
      "server": {
        "port": 8080,
        "host": "0.0.0.0"
      },
      "database": {
        "maxConnections": 20,
        "connectionTimeout": "30s",
        "retryAttempts": 3
      },
      "cache": {
        "ttl": "1h",
        "maxEntries": 10000
      },
      "features": {
        "enableMetrics": true,
        "enableTracing": true,
        "enableCaching": true
      }
    }

---
# Deployment using the ConfigMap
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
        version: v2.1.0
    spec:
      containers:
      - name: webapp
        image: myregistry/webapp:v2.1.0
        ports:
        - containerPort: 8080
        envFrom:
        - configMapRef:
            name: webapp-config
        volumeMounts:
        - name: app-config
          mountPath: /etc/app/config.json
          subPath: app-config.json
          readOnly: true
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: app-config
        configMap:
          name: webapp-config
          items:
          - key: app-config.json
            path: app-config.json

---
# Service
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  namespace: production
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
```

### Multi-Environment Configuration
```yaml
# Development ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: development
data:
  APP_ENV: "development"
  LOG_LEVEL: "debug"
  DATABASE_URL: "postgresql://dev-db:5432/myapp"
  REDIS_URL: "redis://dev-redis:6379"
  ENABLE_DEBUG: "true"
  METRICS_ENABLED: "false"

---
# Production ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: production
data:
  APP_ENV: "production"
  LOG_LEVEL: "info"
  DATABASE_URL: "postgresql://prod-db:5432/myapp"
  REDIS_URL: "redis://prod-redis:6379"
  ENABLE_DEBUG: "false"
  METRICS_ENABLED: "true"
  CACHE_TTL: "3600"
  MAX_CONNECTIONS: "100"
```

---

## 🔄 ConfigMap Updates and Hot Reloading

### Updating ConfigMaps
```bash
# Method 1: Edit directly
kubectl edit configmap webapp-config

# Method 2: Replace from file
kubectl create configmap webapp-config --from-file=config.yaml --dry-run=client -o yaml | kubectl replace -f -

# Method 3: Patch specific keys
kubectl patch configmap webapp-config --patch '{"data":{"LOG_LEVEL":"debug"}}'

# Method 4: Update from literals
kubectl create configmap webapp-config \
  --from-literal=APP_ENV=production \
  --from-literal=LOG_LEVEL=debug \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Triggering Pod Updates
```bash
# Force deployment rollout after ConfigMap change
kubectl rollout restart deployment webapp

# Add annotation to trigger update
kubectl patch deployment webapp -p \
  '{"spec":{"template":{"metadata":{"annotations":{"configmap/update":"'$(date +%s)'"}}}}}'
```

### Automatic Reload with Reloader
```yaml
# Install Reloader (external tool)
# kubectl apply -f https://raw.githubusercontent.com/stakater/Reloader/master/deployments/kubernetes/reloader.yaml

# Add annotation to enable auto-reload
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  annotations:
    reloader.stakater.com/auto: "true"
    # or specific ConfigMaps
    configmap.reloader.stakater.com/reload: "webapp-config,shared-config"
spec:
  # ...deployment spec...
```

---

## 🧪 Testing and Validation

### Validation Scripts
```bash
#!/bin/bash
# test-configmap.sh

echo "Testing ConfigMap functionality..."

# Create test ConfigMap
kubectl create configmap test-config \
  --from-literal=TEST_KEY=test-value \
  --from-literal=ANOTHER_KEY=another-value

# Test Pod with environment variables
kubectl run test-env-pod --image=busybox:1.35 --rm -i --tty \
  --env=TEST_KEY \
  --env=ANOTHER_KEY \
  --overrides='
{
  "spec": {
    "containers": [
      {
        "name": "test-env-pod",
        "image": "busybox:1.35",
        "command": ["sh", "-c", "echo TEST_KEY=$TEST_KEY && echo ANOTHER_KEY=$ANOTHER_KEY && sleep 10"],
        "env": [
          {
            "name": "TEST_KEY",
            "valueFrom": {
              "configMapKeyRef": {
                "name": "test-config",
                "key": "TEST_KEY"
              }
            }
          },
          {
            "name": "ANOTHER_KEY",
            "valueFrom": {
              "configMapKeyRef": {
                "name": "test-config",
                "key": "ANOTHER_KEY"
              }
            }
          }
        ]
      }
    ]
  }
}' -- /bin/sh

# Cleanup
kubectl delete configmap test-config
```

### Validation Commands
```bash
# Check ConfigMap exists
kubectl get configmap webapp-config

# Verify data
kubectl get configmap webapp-config -o jsonpath='{.data.APP_ENV}'

# Check Pod environment
kubectl exec deployment/webapp -- printenv | grep APP_

# Verify mounted files
kubectl exec deployment/webapp -- ls -la /etc/app/
kubectl exec deployment/webapp -- cat /etc/app/config.json

# Check for events
kubectl get events --field-selector involvedObject.name=webapp-config
```

---

## � Troubleshooting

### Common Issues

1. **ConfigMap Not Found**
```bash
# Check ConfigMap exists in correct namespace
kubectl get configmap webapp-config -n production

# Check spelling and case sensitivity
kubectl get configmap -o name | grep webapp
```

2. **Environment Variable Not Set**
```bash
# Check Pod environment
kubectl exec POD_NAME -- printenv

# Verify ConfigMap key exists
kubectl get configmap webapp-config -o jsonpath='{.data}'

# Check for optional vs required keys
kubectl describe pod POD_NAME | grep -A 10 "Environment Variables"
```

3. **File Not Mounted**
```bash
# Check volume mounts
kubectl describe pod POD_NAME | grep -A 10 "Mounts:"

# Verify file exists
kubectl exec POD_NAME -- ls -la /etc/app/

# Check permissions
kubectl exec POD_NAME -- ls -la /etc/app/config.json
```

4. **ConfigMap Too Large**
```bash
# Check ConfigMap size (limit: 1MB)
kubectl get configmap webapp-config -o jsonpath='{.data}' | wc -c

# Split large configs into multiple ConfigMaps
kubectl create configmap app-config-1 --from-file=config1.yaml
kubectl create configmap app-config-2 --from-file=config2.yaml
```

---

## 🔐 Security Best Practices

### 1. Namespace Isolation
```yaml
# Use namespaces to isolate configurations
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: production  # Separate from dev/staging
```

### 2. RBAC Controls
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: configmap-reader
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
  resourceNames: ["webapp-config"]  # Restrict to specific ConfigMaps

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: configmap-reader-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: webapp-sa
  namespace: production
roleRef:
  kind: Role
  name: configmap-reader
  apiGroup: rbac.authorization.k8s.io
```

### 3. Avoid Sensitive Data
```yaml
# ❌ DON'T store sensitive data in ConfigMaps
data:
  database-password: "supersecret123"  # Use Secret instead

# ✅ DO reference sensitive data properly
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-credentials
      key: password
- name: DB_HOST
  valueFrom:
    configMapKeyRef:
      name: db-config
      key: hostname
```

---

## 📊 Monitoring and Observability

### ConfigMap Metrics
```bash
# Number of ConfigMaps
kubectl get configmaps --all-namespaces --no-headers | wc -l

# ConfigMap sizes
kubectl get configmaps -o custom-columns=NAME:.metadata.name,SIZE:.data | grep -v SIZE

# ConfigMaps by namespace
kubectl get configmaps --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name --no-headers | sort
```

### Monitoring Changes
```bash
# Watch ConfigMap changes
kubectl get configmaps -w

# Check ConfigMap events
kubectl get events --field-selector involvedObject.kind=ConfigMap

# Audit ConfigMap modifications
kubectl get events --field-selector reason=ConfigMapUpdated
```

---

## 🧹 Cleanup

```bash
# Delete specific ConfigMap
kubectl delete configmap webapp-config

# Delete all ConfigMaps in namespace
kubectl delete configmaps --all -n development

# Delete ConfigMaps by label
kubectl delete configmaps -l app=webapp

# Verify cleanup
kubectl get configmaps
```

---

## 📚 Real-World Examples

Find complete examples in this directory:
- **[Basic ConfigMap](./basic-configmap-example.yaml)** - Simple key-value configuration
- **[File-based ConfigMap](./file-configmap-example.yaml)** - Configuration from files
- **[Multi-environment Setup](./multi-env-configmap.yaml)** - Different configs per environment
- **[Production Deployment](./production-deployment.yaml)** - Complete application with ConfigMap

---

## 📖 References

- [Kubernetes ConfigMap Documentation](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Configure Pods Using ConfigMaps](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/)
- [Twelve-Factor App Config](https://12factor.net/config)
- [Kubernetes Best Practices: Configuration](https://cloud.google.com/blog/products/containers-kubernetes/kubernetes-best-practices-how-and-when-to-use-configmaps)

---

**Last Updated**: December 2024  
**Kubernetes Version**: 1.32+  
**Status**: ✅ Production Ready

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