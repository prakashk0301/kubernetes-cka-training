# Kubernetes Gateway API Lab – Step-by-Step Guide

## 🛠️ Step 1: Install Gateway Controller (Istio Example)

For this lab, we'll use Istio as the Gateway API controller.

```bash
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH
istioctl install --set profile=demo -y
```

**Verify GatewayClass:**
```bash
kubectl get gatewayclass
```
Expected output:
```
NAME    CONTROLLER                  ...
istio   istio.io/gateway-controller
```

---

## 🏗️ Step 2: Deploy Example Namespace & Application

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

**Apply resources:**
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

**Apply resources:**
```bash
kubectl apply -f gateway.yaml
kubectl apply -f httproute.yaml
```

---

## 🧪 Step 4: Test the Gateway

**Get the external IP:**
```bash
kubectl get svc istio-ingressgateway -n istio-system
```

**Test with curl:**
```bash
curl http://<EXTERNAL-IP>
```
Expected output:
```
Hello from Gateway
```

---

## 📚 Gateway API Concepts

| Component     | Description                                 |
|-------------- |---------------------------------------------|
| Gateway       | Defines listener and protocol (L4/L7)        |
| GatewayClass  | Implementation type (e.g., istio)            |
| HTTPRoute     | Routes traffic to backend service            |

---

## 🚀 Enhancements & Best Practices

- **TLS Termination:**
  - You can add a TLS listener to the Gateway for HTTPS traffic.
- **Multiple Routes:**
  - Attach multiple HTTPRoutes to a single Gateway for advanced routing.
- **Cross-Namespace Routing:**
  - Use `allowedRoutes` to permit routes from other namespaces.
- **Advanced Matching:**
  - HTTPRoute supports header, method, and host-based routing.
- **Security:**
  - Use NetworkPolicies and RBAC to restrict access to Gateway resources.
- **Monitoring:**
  - Integrate with Prometheus/Grafana for traffic and health metrics.

---

## 🔗 References
- [Kubernetes Gateway API Docs](https://gateway-api.sigs.k8s.io/)
- [Istio Gateway API Support](https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/)
- [HTTPRoute Spec](https://gateway-api.sigs.k8s.io/references/spec/#gateway.networking.k8s.io/v1.HTTPRoute)
