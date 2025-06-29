# Helm 3 Complete Installation and Usage Guide

This comprehensive guide covers Helm 3 installation, configuration, and advanced usage patterns for Kubernetes package management.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Installation Methods](#installation-methods)
- [Initial Configuration](#initial-configuration)
- [Repository Management](#repository-management)
- [Chart Operations](#chart-operations)
- [Creating Custom Charts](#creating-custom-charts)
- [Advanced Usage](#advanced-usage)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)
- [Examples](#examples)

## Prerequisites

### System Requirements
- Kubernetes cluster (1.20+)
- `kubectl` configured and connected to your cluster
- Bash/PowerShell terminal access

### Verify Kubernetes Access
```bash
# Check cluster connectivity
kubectl cluster-info

# Verify permissions
kubectl auth can-i create deployments
kubectl auth can-i create services
kubectl auth can-i create configmaps
```

## Installation Methods

### Method 1: Script Installation (Recommended)
```bash
# Download and install Helm 3
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3

# Make executable and run
chmod 700 get_helm.sh
./get_helm.sh

# Add to PATH (if not already)
export PATH=$PATH:/usr/local/bin

# Verify installation
helm version
```

### Method 2: Package Manager Installation

#### Ubuntu/Debian
```bash
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```

#### CentOS/RHEL/Fedora
```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

#### macOS
```bash
# Using Homebrew
brew install helm

# Using MacPorts
sudo port install helm3
```

#### Windows
```powershell
# Using Chocolatey
choco install kubernetes-helm

# Using Scoop
scoop install helm

# Using winget
winget install Helm.Helm
```

### Method 3: Binary Installation
```bash
# Download specific version
HELM_VERSION="v3.14.0"
wget https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz

# Extract and install
tar -zxvf helm-${HELM_VERSION}-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm

# Verify
helm version --client
```

## Initial Configuration

### Basic Configuration
```bash
# Initialize Helm (no Tiller needed in Helm 3)
helm version

# Configure autocompletion (Bash)
echo 'source <(helm completion bash)' >> ~/.bashrc
source ~/.bashrc

# Configure autocompletion (Zsh)
echo 'source <(helm completion zsh)' >> ~/.zshrc
source ~/.zshrc

# Configure autocompletion (PowerShell)
helm completion powershell | Out-String | Invoke-Expression
```

### Environment Configuration
```bash
# Set default namespace (optional)
export HELM_NAMESPACE=default

# Set custom cache directory
export HELM_CACHE_HOME=~/.cache/helm

# Set custom config directory
export HELM_CONFIG_HOME=~/.config/helm

# Set custom data directory
export HELM_DATA_HOME=~/.local/share/helm
```

## Repository Management

### Adding Official Repositories
```bash
# Add Bitnami repository (replaces deprecated stable)
helm repo add bitnami https://charts.bitnami.com/bitnami

# Add other popular repositories
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add elastic https://helm.elastic.co
helm repo add hashicorp https://helm.releases.hashicorp.com

# Update repository index
helm repo update
```

### Repository Operations
```bash
# List configured repositories
helm repo list

# Search for charts
helm search repo mysql
helm search repo nginx --versions

# Add custom repository
helm repo add myrepo https://my-custom-repo.example.com

# Remove repository
helm repo remove myrepo

# Update specific repository
helm repo update bitnami
```

## Chart Operations

### Installing Charts
```bash
# Install with generated name
helm install bitnami/mysql --generate-name

# Install with custom name
helm install my-mysql bitnami/mysql

# Install with custom values
helm install my-mysql bitnami/mysql \
  --set auth.rootPassword=secretpassword \
  --set primary.persistence.size=20Gi

# Install with values file
helm install my-mysql bitnami/mysql -f custom-values.yaml

# Install in specific namespace
helm install my-mysql bitnami/mysql --namespace database --create-namespace

# Dry run installation
helm install my-mysql bitnami/mysql --dry-run --debug
```

### Managing Releases
```bash
# List releases
helm list
helm list --all-namespaces
helm list --namespace database

# Get release status
helm status my-mysql

# Get release values
helm get values my-mysql
helm get values my-mysql --all

# Get release manifest
helm get manifest my-mysql

# Get release history
helm history my-mysql
```

### Upgrading and Rolling Back
```bash
# Upgrade release
helm upgrade my-mysql bitnami/mysql --set auth.rootPassword=newpassword

# Upgrade with new values file
helm upgrade my-mysql bitnami/mysql -f updated-values.yaml

# Rollback to previous version
helm rollback my-mysql

# Rollback to specific revision
helm rollback my-mysql 2

# Force upgrade
helm upgrade my-mysql bitnami/mysql --force
```

### Uninstalling Releases
```bash
# Uninstall release
helm uninstall my-mysql

# Uninstall and keep history
helm uninstall my-mysql --keep-history

# Uninstall from specific namespace
helm uninstall my-mysql --namespace database
```

## Creating Custom Charts

### Generate Chart Structure
```bash
# Create new chart
helm create myapp
```

### Chart Structure Analysis
```
myapp/
├── Chart.yaml          # Chart metadata
├── values.yaml         # Default configuration values
├── charts/             # Chart dependencies
├── templates/          # Kubernetes manifest templates
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── serviceaccount.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── hpa.yaml
│   ├── NOTES.txt
│   ├── _helpers.tpl    # Template helpers
│   └── tests/
│       └── test-connection.yaml
└── .helmignore         # Files to ignore during packaging
```

### Validate and Test Charts
```bash
# Lint chart for issues
helm lint myapp/

# Template rendering (dry run)
helm template myapp myapp/

# Template with debug output
helm template myapp myapp/ --debug

# Install with dry run
helm install myapp myapp/ --dry-run --debug

# Test release
helm test myapp
```

### Package and Distribute Charts
```bash
# Package chart
helm package myapp/

# Package with version
helm package myapp/ --version 1.0.0

# Package and sign
helm package myapp/ --sign --key 'My Key' --keyring ~/.gnupg/secring.gpg

# Verify signed package
helm verify myapp-1.0.0.tgz

# Push to repository (if configured)
helm push myapp-1.0.0.tgz oci://my-registry.example.com/charts
```

## Advanced Usage

### Working with Dependencies
```bash
# Add dependency in Chart.yaml
# dependencies:
#   - name: mysql
#     version: 9.4.6
#     repository: https://charts.bitnami.com/bitnami

# Update dependencies
helm dependency update myapp/

# Build dependencies
helm dependency build myapp/

# List dependencies
helm dependency list myapp/
```

### Hooks and Tests
```bash
# View available hooks
helm get hooks my-release

# Run tests
helm test my-release

# Run tests with cleanup
helm test my-release --cleanup
```

### OCI Registry Support
```bash
# Login to OCI registry
helm registry login my-registry.example.com

# Push chart to OCI registry
helm push myapp-1.0.0.tgz oci://my-registry.example.com/charts

# Install from OCI registry
helm install myapp oci://my-registry.example.com/charts/myapp --version 1.0.0

# Logout from registry
helm registry logout my-registry.example.com
```

## Security Best Practices

### Chart Security
```bash
# Always verify chart sources
helm repo list

# Use specific versions
helm install myapp bitnami/mysql --version 9.4.6

# Review chart templates before installation
helm template myapp bitnami/mysql --version 9.4.6 | less

# Check for security issues
helm lint myapp/ --strict
```

### RBAC Configuration
```yaml
# Create service account for Helm operations
apiVersion: v1
kind: ServiceAccount
metadata:
  name: helm-user
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: helm-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: helm-user
  namespace: default
```

### Values Security
```bash
# Use secrets for sensitive data
kubectl create secret generic mysql-secret \
  --from-literal=root-password=secretpassword

# Reference in values.yaml
# auth:
#   existingSecret: mysql-secret
```

## Troubleshooting

### Common Issues and Solutions

#### Issue: Repository Not Found
```bash
# Solution: Update repository index
helm repo update

# Check repository status
helm repo list
```

#### Issue: Release Already Exists
```bash
# Solution: Use different name or upgrade existing
helm upgrade my-release bitnami/mysql

# Or uninstall existing
helm uninstall my-release
```

#### Issue: Insufficient Permissions
```bash
# Check RBAC permissions
kubectl auth can-i create deployments
kubectl auth can-i create services

# Check current context
kubectl config current-context
```

#### Issue: Template Rendering Errors
```bash
# Debug template rendering
helm template myapp myapp/ --debug

# Check syntax
helm lint myapp/
```

### Debug Commands
```bash
# Enable debug mode
helm install myapp bitnami/mysql --debug

# Verbose output
helm list --debug

# Get extended information
helm get all my-release

# Check Helm version compatibility
helm version
kubectl version
```

### Recovery Commands
```bash
# Force delete stuck release
helm uninstall my-release --no-hooks

# Reset Helm state (extreme cases)
kubectl delete secret -l owner=helm

# Manually clean up resources
kubectl delete deployment,service,configmap,secret -l app.kubernetes.io/managed-by=Helm
```

## Examples

### Example 1: WordPress with MySQL
```bash
# Add repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Create values file
cat > wordpress-values.yaml << EOF
wordpressUsername: admin
wordpressPassword: secure-password
wordpressEmail: admin@example.com
wordpressFirstName: Admin
wordpressLastName: User

service:
  type: LoadBalancer

persistence:
  enabled: true
  size: 10Gi

mysql:
  auth:
    rootPassword: mysql-root-password
    password: mysql-password
  primary:
    persistence:
      enabled: true
      size: 8Gi
EOF

# Install WordPress
helm install my-wordpress bitnami/wordpress -f wordpress-values.yaml

# Get status
helm status my-wordpress
```

### Example 2: Monitoring Stack
```bash
# Add Prometheus repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false

# Check installation
helm list -n monitoring
kubectl get pods -n monitoring
```

### Example 3: Custom Application Chart
```bash
# Create chart
helm create my-api

# Customize Chart.yaml
cat > my-api/Chart.yaml << EOF
apiVersion: v2
name: my-api
description: A REST API application
type: application
version: 0.1.0
appVersion: "1.0.0"
dependencies:
  - name: postgresql
    version: 12.1.2
    repository: https://charts.bitnami.com/bitnami
EOF

# Update dependencies
helm dependency update my-api/

# Install with custom values
helm install my-api ./my-api --set image.tag=v1.0.0
```

## Best Practices Summary

1. **Always use specific versions** for production deployments
2. **Test charts** in staging before production
3. **Use values files** for configuration management
4. **Implement proper RBAC** for security
5. **Monitor releases** with proper logging
6. **Backup configurations** and secrets
7. **Document custom charts** thoroughly
8. **Use semantic versioning** for custom charts
9. **Implement chart tests** for validation
10. **Keep repositories updated** regularly

## Additional Resources

- [Official Helm Documentation](https://helm.sh/docs/)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Chart Template Guide](https://helm.sh/docs/chart_template_guide/)
- [Helm Security Best Practices](https://helm.sh/docs/topics/securing_installation/)
- [Community Charts](https://artifacthub.io/)
	
	
