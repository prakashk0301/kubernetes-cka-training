# Kubernetes Gateway API Lab with Istio

This lab provides a step-by-step guide to install and test the Kubernetes Gateway API using Istio on EKS or any Kubernetes cluster.

---

## ⚡ PowerShell Notes for Windows Users

Most commands in this guide work in PowerShell, but note the following adjustments:

- **Environment Variable Export:**
  - Bash: `export PATH="$PWD/bin:$PATH"`
  - PowerShell:
    ```powershell
    $env:PATH = "$PWD/bin;" + $env:PATH
    ```
- **YAML Files:**
  - Use a text editor (VS Code, Notepad++) to create YAML files, not Bash heredocs (`cat <<EOF ... EOF`).
- **kubectl and curl:**
  - All `kubectl` and `curl` commands work as written if the tools are installed and in your PATH.
- **Directory Navigation:**
  - Bash: `cd istio-*`
  - PowerShell: `Set-Location istio-*`

> If you encounter issues, check your PATH and ensure you are running PowerShell as Administrator if needed.

---

## 🛠️ Step 1: Install Istio with Gateway API Support

### 1.1 Download Istio CLI
```bash
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH="$PWD/bin:$PATH"
```

### 1.2 Install Istio (Demo Profile)
```bash
istioctl install --set profile=demo -y
```
> This installs the Istio control plane, ingress gateway, and enables Gateway API CRDs.

### 1.3 Enable Sidecar Injection
```bash
kubectl label namespace default istio-injection=enabled
```

---

## 📦 Step 2: Deploy Example Namespace and Application

**namespace.yaml**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: web
```

**echo-server.yaml**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: echo
  namespace: web
spec:
  selector:
    app: echo
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo
  namespace: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo
  template:
    metadata:
      labels:
        app: echo
    spec:
      containers:
      - name: echo
        image: hashicorp/http-echo
        args:
        - "-text=Hello from Gateway"
        ports:
        - containerPort: 8080
```

**Apply Resources:**
```bash
kubectl apply -f namespace.yaml
kubectl apply -f echo-server.yaml
```

---

## 🌐 Step 3: Create Gateway and HTTPRoute

**gateway.yaml**
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web-gateway
  namespace: web
spec:
  gatewayClassName: istio
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: Same
```

**httproute.yaml**
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: echo-route
  namespace: web
spec:
  parentRefs:
  - name: web-gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: echo
      port: 80
```

**Apply Resources:**
```bash
kubectl apply -f gateway.yaml
kubectl apply -f httproute.yaml
```

---

## 🔍 Step 4: Verify Gateway Installation

**Get GatewayClass:**
```bash
kubectl get gatewayclass
```
Expected output:
```
NAME    CONTROLLER
istio   istio.io/gateway-controller
```

**Get Istio Gateway IP:**
```bash
kubectl get svc istio-ingressgateway -n istio-system
```
Use the EXTERNAL-IP for curl tests.

---

## 🧪 Step 5: Test the Gateway

```bash
curl http://<EXTERNAL-IP>
```
Expected output:
```
Hello from Gateway
```

---

## 📚 Gateway API Concepts

| Component    | Description                              |
|--------------|------------------------------------------|
| Gateway      | Defines listener and protocol (L4/L7)    |
| GatewayClass | Implementation type (e.g., istio)        |
| HTTPRoute    | Routes traffic to backend service        |

---

## ✅ Enhancements & Best Practices

- **TLS Termination:** Add a TLS listener to the Gateway for HTTPS support.
- **Multiple Routes:** Route to multiple services using multiple HTTPRoutes.
- **Advanced Matching:** Match by headers, methods, or hosts.
- **Security:** Use RBAC and NetworkPolicies to protect Gateway resources.
- **LoadBalancer Type:**
  - To explicitly configure NLB type or private/internal access, add annotations when installing Istio via Helm:
    ```yaml
    service:
      type: LoadBalancer
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-type: "external"       # or "nlb-ip"
        service.beta.kubernetes.io/aws-load-balancer-internal: "true"      # for private
    ```

---

## 🔗 References
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Istio Gateway API Support](https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/)
- [Istio Bookinfo Gateway YAMLs](https://istio.io/latest/docs/examples/bookinfo/gateway/)