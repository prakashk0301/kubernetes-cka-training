# README: Helm 3 Complete Training Guide

Welcome to the comprehensive Helm 3 training guide! This directory contains everything you need to master Kubernetes package management with Helm 3.

## 📁 Directory Contents

### 📖 **Documentation Files**
- **`helm3-installation.md`** - Complete installation and usage guide (25KB+)
- **`helm-concepts.md`** - Comprehensive concepts and architecture guide (15KB+)

### 📋 **Example Files**
- **`helm-chart-examples.yaml`** - Basic to advanced chart examples
- **`helm-advanced-patterns.yaml`** - Production-ready patterns and configurations

### 🔧 **Utility Scripts**
- **`test-helm-comprehensive.sh`** - Interactive testing and validation script

## 🚀 Quick Start

### 1. Install Helm 3
```bash
# Download and install
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Verify installation
helm version
```

### 2. Setup Repositories
```bash
# Add popular repositories
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Update repositories
helm repo update
```

### 3. Create Your First Chart
```bash
# Create new chart
helm create my-app

# Customize values
vim my-app/values.yaml

# Install chart
helm install my-release my-app/
```

## 📚 Learning Path

### **Beginner Level**
1. Read `helm-concepts.md` - Core concepts and architecture
2. Follow `helm3-installation.md` - Installation and basic commands
3. Practice with simple chart creation and installation

### **Intermediate Level**
1. Study `helm-chart-examples.yaml` - Chart structure and templating
2. Learn dependency management and testing
3. Practice with multi-environment deployments

### **Advanced Level**
1. Master `helm-advanced-patterns.yaml` - Production patterns
2. Implement CI/CD with Helm
3. Custom chart development and security

## 🛠️ Hands-On Labs

### **Lab 1: Basic Chart Operations**
```bash
# Create and install a simple chart
helm create webapp
helm install my-webapp webapp/

# Check status and test
helm status my-webapp
helm test my-webapp

# Upgrade with new values
helm upgrade my-webapp webapp/ --set replicaCount=3

# Rollback if needed
helm rollback my-webapp
```

### **Lab 2: Working with Dependencies**
```bash
# Chart with PostgreSQL dependency
cat >> Chart.yaml << EOF
dependencies:
  - name: postgresql
    version: 12.1.2
    repository: https://charts.bitnami.com/bitnami
EOF

# Update dependencies
helm dependency update

# Install with dependency
helm install my-stack ./
```

### **Lab 3: Multi-Environment Deployment**
```bash
# Development deployment
helm install my-app-dev ./ -f values-development.yaml

# Staging deployment
helm install my-app-staging ./ -f values-staging.yaml

# Production deployment
helm install my-app-prod ./ -f values-production.yaml
```

## 🔧 Testing and Validation

### **Automated Testing**
```bash
# Make script executable
chmod +x test-helm-comprehensive.sh

# Run comprehensive tests
./test-helm-comprehensive.sh

# Select option 12 for full test suite
```

### **Manual Testing**
```bash
# Lint charts
helm lint ./my-chart

# Dry run installation
helm install my-release ./my-chart --dry-run --debug

# Template validation
helm template my-release ./my-chart
```

## 📋 Chart Development Checklist

### **Basic Requirements**
- [ ] `Chart.yaml` with proper metadata
- [ ] `values.yaml` with sensible defaults
- [ ] Template files with proper labels
- [ ] `_helpers.tpl` with reusable functions
- [ ] `NOTES.txt` with usage instructions

### **Security Best Practices**
- [ ] Non-root user configuration
- [ ] Read-only root filesystem
- [ ] Resource limits and requests
- [ ] Network policies (if applicable)
- [ ] Security contexts
- [ ] Secret management

### **Production Readiness**
- [ ] Health checks (liveness/readiness)
- [ ] Horizontal Pod Autoscaler
- [ ] Pod Disruption Budget
- [ ] Persistent Volume Claims
- [ ] Monitoring and metrics
- [ ] Backup strategies

## 🌟 Real-World Examples

### **Example 1: WordPress with MySQL**
```bash
# Add Bitnami repo
helm repo add bitnami https://charts.bitnami.com/bitnami

# Install WordPress
helm install my-wordpress bitnami/wordpress \
  --set wordpressUsername=admin \
  --set wordpressPassword=secure-password \
  --set service.type=LoadBalancer
```

### **Example 2: Monitoring Stack**
```bash
# Install Prometheus and Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

### **Example 3: Microservices Application**
```bash
# Deploy complete microservices stack
helm install my-microservices ./microservices-chart/ \
  --values values-production.yaml \
  --namespace production \
  --create-namespace
```

## 🔍 Troubleshooting Guide

### **Common Issues**

#### **Chart Installation Fails**
```bash
# Check chart syntax
helm lint ./my-chart

# Debug templates
helm template my-release ./my-chart --debug

# Check cluster resources
kubectl get events --sort-by=.metadata.creationTimestamp
```

#### **Release Not Found**
```bash
# List releases in all namespaces
helm list --all-namespaces

# Check specific namespace
helm list -n my-namespace

# Get release history
helm history my-release
```

#### **Template Rendering Errors**
```bash
# Validate YAML syntax
helm template my-release ./my-chart | kubectl apply --dry-run=client -f -

# Check specific template
helm template my-release ./my-chart -s templates/deployment.yaml
```

### **Debug Commands**
```bash
# Enable debug mode
helm install my-release ./my-chart --debug --dry-run

# Get detailed information
helm get all my-release

# Check manifest
helm get manifest my-release
```

## 📖 Additional Resources

### **Official Documentation**
- [Helm Documentation](https://helm.sh/docs/)
- [Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Template Guide](https://helm.sh/docs/chart_template_guide/)

### **Community Resources**
- [Artifact Hub](https://artifacthub.io/) - Discover charts
- [Helm GitHub](https://github.com/helm/helm) - Source code and issues
- [Helm Community](https://github.com/helm/community) - Contributing guidelines

### **Learning Materials**
- [Helm Workshop](https://helm.sh/docs/intro/quickstart/)
- [Chart Museum](https://chartmuseum.com/) - Chart repository
- [Helm Secrets](https://github.com/jkroepke/helm-secrets) - Secret management

## 🎯 Certification Preparation

### **CKA/CKAD Topics Covered**
- Package management with Helm
- Application deployment and updates
- Configuration management
- Resource management
- Troubleshooting deployments

### **Practice Scenarios**
1. **Deploy multi-tier application** using Helm charts
2. **Manage application lifecycle** (install, upgrade, rollback)
3. **Customize deployments** for different environments
4. **Troubleshoot failed deployments** and fix issues
5. **Implement security policies** in Helm charts

## 🏆 Mastery Goals

By completing this training, you should be able to:

1. **Install and configure** Helm 3 in any environment
2. **Create production-ready** Helm charts from scratch
3. **Manage complex applications** with dependencies
4. **Implement CI/CD pipelines** using Helm
5. **Troubleshoot and debug** Helm-related issues
6. **Apply security best practices** in chart development
7. **Optimize chart performance** and resource usage

## 📝 Quick Reference

### **Essential Commands**
```bash
# Repository management
helm repo add <name> <url>
helm repo update
helm search repo <keyword>

# Chart operations
helm create <chart-name>
helm lint <chart>
helm package <chart>

# Release management
helm install <release> <chart>
helm upgrade <release> <chart>
helm rollback <release>
helm uninstall <release>

# Information
helm list
helm status <release>
helm history <release>
helm get values <release>
```

### **Useful Flags**
- `--dry-run` - Simulate installation
- `--debug` - Enable debug output
- `--wait` - Wait for resources to be ready
- `--timeout` - Set operation timeout
- `--force` - Force upgrade/rollback
- `--atomic` - Rollback on failure

---

**Happy Helming! 🚢⚓**

For questions or issues, refer to the troubleshooting section or check the official Helm documentation.
