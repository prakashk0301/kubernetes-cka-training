# Kubernetes Gateway API with Istio - Complete Guide

This comprehensive guide covers the installation, configuration, and management of Kubernetes Gateway API using Istio service mesh for Kubernetes 1.32+.

---

## 🎯 What is Gateway API?

**Kubernetes Gateway API** is the next-generation API for managing ingress traffic in Kubernetes. It provides:
- **Role-oriented design** - Separating infrastructure and application concerns
- **Portable APIs** - Vendor-agnostic specifications
- **Expressive routing** - Advanced traffic management capabilities
- **Extensible architecture** - Support for various protocols and use cases

---

## 🆚 Gateway API vs Traditional Ingress

| Feature | Traditional Ingress | Gateway API |
|---------|-------------------|-------------|
| **Design** | Monolithic resource | Role-separated resources |
| **Extensibility** | Limited annotations | Native extensibility |
| **Protocol Support** | HTTP/HTTPS only | HTTP, HTTPS, TCP, UDP, TLS |
| **Traffic Management** | Basic routing | Advanced traffic splitting, header manipulation |
| **Multi-tenancy** | Complex RBAC | Built-in role separation |
| **Vendor Portability** | Implementation-specific | Standardized across vendors |

---

## 🏗️ Gateway API Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GatewayClass  │    │     Gateway     │    │   HTTPRoute     │
│                 │    │                 │    │                 │
│ Infrastructure  │───▶│   Listener      │◀───│   Application   │
│ Owner Resource  │    │   Configuration │    │   Route Rules   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

---

## ⚡ Prerequisites

Before starting, ensure you have:
- Kubernetes 1.25+ cluster (tested on 1.32)
- `kubectl` configured and connected
- Administrative access to the cluster
- External Load Balancer support (for cloud environments)

---

## 🛠️ Step 1: Install Istio with Gateway API Support

### 1.1 Download and Install Istio CLI
```bash
# Download latest Istio
curl -L https://istio.io/downloadIstio | sh -

# Navigate to Istio directory
cd istio-*

# Add Istio CLI to PATH (Linux/macOS)
export PATH=$PWD/bin:$PATH

# For Windows PowerShell
# $env:PATH = "$PWD/bin;" + $env:PATH
```

### 1.2 Install Istio with Gateway API
```bash
# Install Istio with demo profile (includes ingress gateway)
istioctl install --set profile=demo --set values.pilot.env.EXTERNAL_ISTIOD=false -y

# Verify installation
kubectl get pods -n istio-system

# Check Gateway API CRDs are installed
kubectl get crd | grep gateway.networking.k8s.io
```

### 1.3 Enable Sidecar Injection
```bash
# Enable automatic sidecar injection for default namespace
kubectl label namespace default istio-injection=enabled

# Verify label
kubectl get namespace default --show-labels
```

### 1.4 Install Gateway API CRDs (if not already installed)
```bash
# Install standard Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml

# Install experimental Gateway API CRDs (for advanced features)
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/experimental-install.yaml
```

---

## 📦 Step 2: Deploy Sample Applications

### 2.1 Create Namespaces
```yaml
# namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    istio-injection: enabled
    environment: production

---
apiVersion: v1
kind: Namespace
metadata:
  name: staging
  labels:
    istio-injection: enabled
    environment: staging
```

### 2.2 Deploy Applications
```yaml
# applications.yaml
# Production Application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-prod
  namespace: production
  labels:
    app: webapp
    version: v2.0
    environment: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
      version: v2.0
  template:
    metadata:
      labels:
        app: webapp
        version: v2.0
        environment: production
    spec:
      containers:
      - name: webapp
        image: hashicorp/http-echo:0.2.3
        args:
        - "-text=Production App v2.0 - Pod: $(HOSTNAME)"
        - "-listen=:8080"
        ports:
        - containerPort: 8080
        env:
        - name: HOSTNAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"

---
# Production Service
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  namespace: production
  labels:
    app: webapp
    environment: production
spec:
  selector:
    app: webapp
    version: v2.0
  ports:
  - port: 80
    targetPort: 8080
    name: http

---
# Staging Application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-staging
  namespace: staging
  labels:
    app: webapp
    version: v1.5
    environment: staging
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
      version: v1.5
  template:
    metadata:
      labels:
        app: webapp
        version: v1.5
        environment: staging
    spec:
      containers:
      - name: webapp
        image: hashicorp/http-echo:0.2.3
        args:
        - "-text=Staging App v1.5 - Pod: $(HOSTNAME)"
        - "-listen=:8080"
        ports:
        - containerPort: 8080
        env:
        - name: HOSTNAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"

---
# Staging Service
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  namespace: staging
  labels:
    app: webapp
    environment: staging
spec:
  selector:
    app: webapp
    version: v1.5
  ports:
  - port: 80
    targetPort: 8080
    name: http

---
# API Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
  namespace: production
  labels:
    app: api
    version: v1.0
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
      version: v1.0
  template:
    metadata:
      labels:
        app: api
        version: v1.0
    spec:
      containers:
      - name: api
        image: hashicorp/http-echo:0.2.3
        args:
        - "-text={\"message\":\"API Response\",\"version\":\"v1.0\",\"pod\":\"$(HOSTNAME)\"}"
        - "-listen=:8080"
        ports:
        - containerPort: 8080
        env:
        - name: HOSTNAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name

---
apiVersion: v1
kind: Service
metadata:
  name: api-service
  namespace: production
  labels:
    app: api
spec:
  selector:
    app: api
    version: v1.0
  ports:
  - port: 80
    targetPort: 8080
    name: http
```

### Apply Resources
```bash
kubectl apply -f namespaces.yaml
kubectl apply -f applications.yaml

# Verify deployments
kubectl get pods -n production
kubectl get pods -n staging
```

---

## 🌐 Step 3: Configure Gateway and Routes

### 3.1 Create GatewayClass
```yaml
# gatewayclass.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: istio
  labels:
    app.kubernetes.io/name: istio-gateway
spec:
  controllerName: istio.io/gateway-controller
  description: Istio-based Gateway implementation
```

### 3.2 Create Main Gateway
```yaml
# gateway.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: main-gateway
  namespace: istio-system
  labels:
    app.kubernetes.io/name: main-gateway
    app.kubernetes.io/component: gateway
spec:
  gatewayClassName: istio
  listeners:
  # HTTP listener for general traffic
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: All  # Allow routes from all namespaces
  
  # HTTPS listener (if you have TLS certificates)
  - name: https
    protocol: HTTPS
    port: 443
    tls:
      mode: Terminate
      certificateRefs:
      - name: gateway-cert
        kind: Secret
    allowedRoutes:
      namespaces:
        from: All

  # TCP listener for non-HTTP traffic
  - name: tcp
    protocol: TCP
    port: 9000
    allowedRoutes:
      namespaces:
        from: All
```

### 3.3 Create HTTP Routes
```yaml
# routes.yaml
# Production Application Route
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: webapp-prod-route
  namespace: production
  labels:
    app: webapp
    environment: production
spec:
  parentRefs:
  - name: main-gateway
    namespace: istio-system
  hostnames:
  - "app.example.com"
  - "www.example.com"
  rules:
  # Main application traffic
  - matches:
    - path:
        type: PathPrefix
        value: /
    - headers:
      - type: Exact
        name: x-environment
        value: production
    backendRefs:
    - name: webapp-service
      port: 80
      weight: 100
    filters:
    - type: RequestHeaderModifier
      requestHeaderModifier:
        add:
        - name: x-routed-by
          value: gateway-api
        - name: x-environment
          value: production

---
# API Routes
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: api-route
  namespace: production
  labels:
    app: api
spec:
  parentRefs:
  - name: main-gateway
    namespace: istio-system
  hostnames:
  - "api.example.com"
  rules:
  # API v1 routes
  - matches:
    - path:
        type: PathPrefix
        value: /api/v1
    backendRefs:
    - name: api-service
      port: 80
      weight: 100
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /
    - type: RequestHeaderModifier
      requestHeaderModifier:
        add:
        - name: x-api-version
          value: v1
        - name: x-request-id
          value: "${request.id}"

  # Health check endpoint
  - matches:
    - path:
        type: Exact
        value: /health
    backendRefs:
    - name: api-service
      port: 80

---
# Staging Routes (with traffic splitting)
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: webapp-staging-route
  namespace: staging
  labels:
    app: webapp
    environment: staging
spec:
  parentRefs:
  - name: main-gateway
    namespace: istio-system
  hostnames:
  - "staging.example.com"
  rules:
  # Canary deployment - split traffic between versions
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: webapp-service
      port: 80
      weight: 90  # 90% to staging
    - name: webapp-service
      namespace: production
      port: 80
      weight: 10  # 10% to production (canary)
    filters:
    - type: RequestHeaderModifier
      requestHeaderModifier:
        add:
        - name: x-environment
          value: staging
        - name: x-canary-deployment
          value: "true"

---
# Advanced routing with multiple conditions
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: advanced-routing
  namespace: production
spec:
  parentRefs:
  - name: main-gateway
    namespace: istio-system
  hostnames:
  - "app.example.com"
  rules:
  # Route based on user type (header-based routing)
  - matches:
    - path:
        type: PathPrefix
        value: /admin
    - headers:
      - type: Exact
        name: x-user-role
        value: admin
    backendRefs:
    - name: admin-service
      port: 80
    filters:
    - type: RequestRedirect
      requestRedirect:
        scheme: https
        hostname: admin.example.com
        statusCode: 301

  # Route based on query parameters
  - matches:
    - path:
        type: PathPrefix
        value: /beta
    - queryParams:
      - type: Exact
        name: version
        value: beta
    backendRefs:
    - name: webapp-service
      port: 80
    filters:
    - type: RequestHeaderModifier
      requestHeaderModifier:
        add:
        - name: x-beta-user
          value: "true"
```

### Apply Gateway Configuration
```bash
kubectl apply -f gatewayclass.yaml
kubectl apply -f gateway.yaml
kubectl apply -f routes.yaml

# Verify resources
kubectl get gatewayclass
kubectl get gateway -A
kubectl get httproute -A
```

---

## 🔍 Step 4: Verify and Test Gateway

### 4.1 Check Gateway Status
```bash
# Check Gateway status
kubectl describe gateway main-gateway -n istio-system

# Get Istio ingress gateway service
kubectl get svc istio-ingressgateway -n istio-system

# Get external IP/hostname
GATEWAY_HOST=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
GATEWAY_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')

echo "Gateway URL: http://$GATEWAY_HOST:$GATEWAY_PORT"
```

### 4.2 Test Routes
```bash
# Test production application
curl -H "Host: app.example.com" http://$GATEWAY_HOST:$GATEWAY_PORT/

# Test with environment header
curl -H "Host: app.example.com" -H "x-environment: production" http://$GATEWAY_HOST:$GATEWAY_PORT/

# Test API routes
curl -H "Host: api.example.com" http://$GATEWAY_HOST:$GATEWAY_PORT/api/v1/users

# Test staging (canary deployment)
curl -H "Host: staging.example.com" http://$GATEWAY_HOST:$GATEWAY_PORT/

# Test health check
curl -H "Host: api.example.com" http://$GATEWAY_HOST:$GATEWAY_PORT/health
```

### 4.3 Advanced Testing
```bash
# Test with multiple requests to see load balancing
for i in {1..10}; do
  curl -s -H "Host: app.example.com" http://$GATEWAY_HOST:$GATEWAY_PORT/ | grep Pod
done

# Test beta feature
curl -H "Host: app.example.com" "http://$GATEWAY_HOST:$GATEWAY_PORT/beta?version=beta"

# Test admin redirect
curl -I -H "Host: app.example.com" -H "x-user-role: admin" http://$GATEWAY_HOST:$GATEWAY_PORT/admin
```

---

## 🔐 Step 5: TLS/HTTPS Configuration

### 5.1 Create TLS Certificate
```bash
# Create self-signed certificate for demo
openssl req -x509 -newkey rsa:4096 -keyout tls.key -out tls.crt -days 365 -nodes \
  -subj "/CN=*.example.com/O=Demo Organization"

# Create Kubernetes secret
kubectl create secret tls gateway-cert \
  --cert=tls.crt \
  --key=tls.key \
  -n istio-system
```

### 5.2 Update Gateway for HTTPS
```yaml
# https-gateway.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: https-gateway
  namespace: istio-system
spec:
  gatewayClassName: istio
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    tls:
      mode: Terminate
      certificateRefs:
      - name: gateway-cert
        kind: Secret
    allowedRoutes:
      namespaces:
        from: All
  # Redirect HTTP to HTTPS
  - name: http-redirect
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: All
```

### 5.3 HTTP to HTTPS Redirect Route
```yaml
# redirect-route.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: http-redirect
  namespace: istio-system
spec:
  parentRefs:
  - name: https-gateway
    sectionName: http-redirect
  rules:
  - filters:
    - type: RequestRedirect
      requestRedirect:
        scheme: https
        statusCode: 301
```

---

## 📊 Step 6: Traffic Management and Observability

### 6.1 Traffic Splitting Configuration
```yaml
# traffic-split.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: canary-deployment
  namespace: production
spec:
  parentRefs:
  - name: main-gateway
    namespace: istio-system
  hostnames:
  - "canary.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    # 95% traffic to stable version
    - name: webapp-service
      port: 80
      weight: 95
    # 5% traffic to canary version
    - name: webapp-service
      namespace: staging
      port: 80
      weight: 5
```

### 6.2 Rate Limiting (using Istio EnvoyFilter)
```yaml
# rate-limit.yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: rate-limit-filter
  namespace: istio-system
spec:
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: GATEWAY
      listener:
        filterChain:
          filter:
            name: "envoy.filters.network.http_connection_manager"
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.local_ratelimit
        typed_config:
          "@type": type.googleapis.com/udpa.type.v1.TypedStruct
          type_url: type.googleapis.com/envoy.extensions.filters.http.local_ratelimit.v3.LocalRateLimit
          value:
            stat_prefix: rate_limiter
            token_bucket:
              max_tokens: 100
              tokens_per_fill: 100
              fill_interval: 60s
            filter_enabled:
              runtime_key: rate_limit_enabled
              default_value:
                numerator: 100
                denominator: HUNDRED
            filter_enforced:
              runtime_key: rate_limit_enforced
              default_value:
                numerator: 100
                denominator: HUNDRED
```

### 6.3 Install Kiali Dashboard
```bash
# Install Kiali for observability
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml

# Install Prometheus for metrics
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml

# Install Grafana for dashboards
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml

# Install Jaeger for tracing
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml

# Access Kiali dashboard
kubectl port-forward svc/kiali 20001:20001 -n istio-system
# Open http://localhost:20001 in browser
```

---

## 🔧 Step 7: Advanced Features

### 7.1 TCP/UDP Routes
```yaml
# tcp-route.yaml
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TCPRoute
metadata:
  name: tcp-route
  namespace: production
spec:
  parentRefs:
  - name: main-gateway
    namespace: istio-system
    sectionName: tcp
  rules:
  - backendRefs:
    - name: tcp-service
      port: 9000
```

### 7.2 gRPC Routes
```yaml
# grpc-route.yaml
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: GRPCRoute
metadata:
  name: grpc-route
  namespace: production
spec:
  parentRefs:
  - name: main-gateway
    namespace: istio-system
  hostnames:
  - "grpc.example.com"
  rules:
  - matches:
    - method:
        service: "hello.HelloService"
        method: "SayHello"
    backendRefs:
    - name: grpc-service
      port: 80
```

### 7.3 Cross-Namespace References
```yaml
# reference-grant.yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-gateway-access
  namespace: production
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: staging
  to:
  - group: ""
    kind: Service
    name: webapp-service
```

---

## 🛡️ Security and RBAC

### 7.1 RBAC Configuration
```yaml
# rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: gateway-manager
rules:
- apiGroups: ["gateway.networking.k8s.io"]
  resources: ["httproutes", "grpcroutes", "tcproutes"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: gateway-manager-binding
  namespace: production
subjects:
- kind: User
  name: app-developer
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: gateway-manager
  apiGroup: rbac.authorization.k8s.io

---
# Cluster-level RBAC for Gateway resources
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: gateway-admin
rules:
- apiGroups: ["gateway.networking.k8s.io"]
  resources: ["gateways", "gatewayClasses"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: gateway-admin-binding
subjects:
- kind: User
  name: platform-admin
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: gateway-admin
  apiGroup: rbac.authorization.k8s.io
```

### 7.2 Network Policies
```yaml
# network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: gateway-ingress-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: webapp
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: istio-system
    ports:
    - protocol: TCP
      port: 8080
```

---

## 🧪 Testing and Validation

### Testing Script
```bash
#!/bin/bash
# test-gateway-api.sh

set -e

echo "🧪 Testing Gateway API Implementation..."

# Get gateway information
GATEWAY_HOST=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
GATEWAY_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')

if [ -z "$GATEWAY_HOST" ]; then
    echo "❌ Gateway host not found"
    exit 1
fi

echo "🌐 Gateway: http://$GATEWAY_HOST:$GATEWAY_PORT"

# Test 1: Basic connectivity
echo "Test 1: Basic connectivity"
if curl -s -H "Host: app.example.com" "http://$GATEWAY_HOST:$GATEWAY_PORT/" | grep -q "Production"; then
    echo "✅ Basic connectivity works"
else
    echo "❌ Basic connectivity failed"
fi

# Test 2: API routing
echo "Test 2: API routing"
if curl -s -H "Host: api.example.com" "http://$GATEWAY_HOST:$GATEWAY_PORT/api/v1" | grep -q "API Response"; then
    echo "✅ API routing works"
else
    echo "❌ API routing failed"
fi

# Test 3: Load balancing
echo "Test 3: Load balancing"
UNIQUE_PODS=$(for i in {1..10}; do
    curl -s -H "Host: app.example.com" "http://$GATEWAY_HOST:$GATEWAY_PORT/" | grep -o "Pod: [^}]*" | cut -d' ' -f2
done | sort | uniq | wc -l)

if [ "$UNIQUE_PODS" -gt 1 ]; then
    echo "✅ Load balancing works (hit $UNIQUE_PODS different pods)"
else
    echo "⚠️  Load balancing may not be working (only hit $UNIQUE_PODS pod)"
fi

# Test 4: Header modification
echo "Test 4: Header modification"
HEADERS=$(curl -s -I -H "Host: app.example.com" "http://$GATEWAY_HOST:$GATEWAY_PORT/")
if echo "$HEADERS" | grep -q "x-routed-by: gateway-api"; then
    echo "✅ Header modification works"
else
    echo "❌ Header modification failed"
fi

echo "🎉 Gateway API testing completed!"
```

### Performance Testing
```bash
# Install hey for load testing
go install github.com/rakyll/hey@latest

# Load test the gateway
hey -n 1000 -c 10 -H "Host: app.example.com" http://$GATEWAY_HOST:$GATEWAY_PORT/

# Test with different routes
hey -n 500 -c 5 -H "Host: api.example.com" http://$GATEWAY_HOST:$GATEWAY_PORT/api/v1
```

---

## 🔍 Troubleshooting

### Common Issues

1. **Gateway Not Ready**
```bash
# Check gateway status
kubectl describe gateway main-gateway -n istio-system

# Check Istio ingress gateway pods
kubectl get pods -n istio-system -l app=istio-ingressgateway

# Check Istio configuration
istioctl proxy-config cluster istio-ingressgateway-xxx -n istio-system
```

2. **Routes Not Working**
```bash
# Check HTTPRoute status
kubectl describe httproute webapp-prod-route -n production

# Verify backend services
kubectl get svc -n production

# Check Istio proxy configuration
istioctl proxy-config routes istio-ingressgateway-xxx -n istio-system
```

3. **TLS Issues**
```bash
# Check certificate secret
kubectl describe secret gateway-cert -n istio-system

# Verify TLS configuration
openssl s_client -connect $GATEWAY_HOST:443 -servername app.example.com

# Check Istio TLS configuration
istioctl proxy-config secret istio-ingressgateway-xxx -n istio-system
```

### Debugging Commands
```bash
# Check all Gateway API resources
kubectl get gatewayclasses,gateways,httproutes,grpcroutes,tcproutes -A

# Istio configuration dump
istioctl proxy-config dump istio-ingressgateway-xxx -n istio-system > config-dump.json

# Check Envoy access logs
kubectl logs -n istio-system -l app=istio-ingressgateway -f

# Verify service mesh configuration
istioctl analyze
```

---

## 🧹 Cleanup

```bash
# Delete all resources
kubectl delete httproute --all -A
kubectl delete gateway --all -A
kubectl delete gatewayclass --all

# Remove applications
kubectl delete namespace production staging

# Uninstall Istio
istioctl uninstall --purge -y

# Remove Gateway API CRDs
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
```

---

## 📚 References

- [Kubernetes Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [Istio Gateway API Guide](https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/)
- [Gateway API Conformance Tests](https://github.com/kubernetes-sigs/gateway-api/tree/main/conformance)
- [Istio Configuration Reference](https://istio.io/latest/docs/reference/config/)

---

**Last Updated**: December 2024  
**Kubernetes Version**: 1.32+  
**Istio Version**: 1.20+  
**Status**: ✅ Production Ready

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