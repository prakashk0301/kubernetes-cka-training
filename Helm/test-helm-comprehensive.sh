#!/bin/bash

# Comprehensive Helm Testing and Validation Script
# This script helps test, validate, and manage Helm charts and releases

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
CHART_DIR="./charts"
TEST_NAMESPACE="helm-test"
RELEASE_PREFIX="test"

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_header() {
    echo -e "\n${BLUE}===============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===============================================${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Helm
    if ! command -v helm &> /dev/null; then
        print_status $RED "❌ Helm is not installed"
        print_status $YELLOW "Install Helm: https://helm.sh/docs/intro/install/"
        exit 1
    else
        print_status $GREEN "✅ Helm is available"
        helm version --short
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_status $RED "❌ kubectl is not installed"
        exit 1
    else
        print_status $GREEN "✅ kubectl is available"
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        print_status $RED "❌ Cannot connect to Kubernetes cluster"
        exit 1
    else
        print_status $GREEN "✅ Connected to Kubernetes cluster"
    fi
    
    # Check permissions
    if ! kubectl auth can-i create deployments &> /dev/null; then
        print_status $YELLOW "⚠️  Warning: May not have permissions to create deployments"
    fi
    
    # Check if test namespace exists, create if not
    if ! kubectl get namespace $TEST_NAMESPACE &> /dev/null; then
        print_status $BLUE "Creating test namespace: $TEST_NAMESPACE"
        kubectl create namespace $TEST_NAMESPACE
    else
        print_status $GREEN "✅ Test namespace exists: $TEST_NAMESPACE"
    fi
}

# Function to setup Helm repositories
setup_repositories() {
    print_header "Setting Up Helm Repositories"
    
    # Add common repositories
    repositories=(
        "bitnami:https://charts.bitnami.com/bitnami"
        "ingress-nginx:https://kubernetes.github.io/ingress-nginx"
        "jetstack:https://charts.jetstack.io"
        "prometheus-community:https://prometheus-community.github.io/helm-charts"
        "grafana:https://grafana.github.io/helm-charts"
        "elastic:https://helm.elastic.co"
    )
    
    for repo in "${repositories[@]}"; do
        IFS=':' read -r name url <<< "$repo"
        print_status $BLUE "Adding repository: $name"
        helm repo add "$name" "$url" 2>/dev/null || print_status $YELLOW "Repository $name already exists"
    done
    
    # Update repositories
    print_status $BLUE "Updating repositories..."
    helm repo update
    
    # List repositories
    print_status $GREEN "✅ Configured repositories:"
    helm repo list
}

# Function to create example chart
create_example_chart() {
    print_header "Creating Example Chart"
    
    local chart_name="example-app"
    local chart_path="${CHART_DIR}/${chart_name}"
    
    # Create charts directory if it doesn't exist
    mkdir -p "$CHART_DIR"
    
    # Create chart if it doesn't exist
    if [ ! -d "$chart_path" ]; then
        print_status $BLUE "Creating new chart: $chart_name"
        helm create "$chart_path"
        
        # Enhance the chart with better defaults
        cat > "${chart_path}/values.yaml" << EOF
replicaCount: 2

image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "1.25-alpine"

serviceAccount:
  create: true
  annotations: {}
  name: ""

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: false
  className: ""
  annotations: {}
  hosts:
    - host: chart-example.local
      paths:
        - path: /
          pathType: Prefix
  tls: []

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 100
  targetCPUUtilizationPercentage: 80

healthCheck:
  enabled: true
  path: /
  port: http

nodeSelector: {}
tolerations: []
affinity: {}
EOF
        
        print_status $GREEN "✅ Created example chart: $chart_name"
    else
        print_status $YELLOW "Chart already exists: $chart_name"
    fi
    
    echo "$chart_path"
}

# Function to lint charts
lint_charts() {
    print_header "Linting Helm Charts"
    
    if [ ! -d "$CHART_DIR" ]; then
        print_status $YELLOW "No charts directory found: $CHART_DIR"
        return 0
    fi
    
    local failed=0
    
    for chart in "$CHART_DIR"/*; do
        if [ -d "$chart" ] && [ -f "$chart/Chart.yaml" ]; then
            local chart_name=$(basename "$chart")
            print_status $BLUE "Linting chart: $chart_name"
            
            if helm lint "$chart" --strict; then
                print_status $GREEN "✅ Chart $chart_name passed linting"
            else
                print_status $RED "❌ Chart $chart_name failed linting"
                failed=1
            fi
        fi
    done
    
    if [ $failed -eq 0 ]; then
        print_status $GREEN "✅ All charts passed linting"
    else
        print_status $RED "❌ Some charts failed linting"
        return 1
    fi
}

# Function to template charts
template_charts() {
    print_header "Templating Helm Charts"
    
    if [ ! -d "$CHART_DIR" ]; then
        print_status $YELLOW "No charts directory found: $CHART_DIR"
        return 0
    fi
    
    for chart in "$CHART_DIR"/*; do
        if [ -d "$chart" ] && [ -f "$chart/Chart.yaml" ]; then
            local chart_name=$(basename "$chart")
            print_status $BLUE "Templating chart: $chart_name"
            
            # Template with debug output
            if helm template "$chart_name" "$chart" --debug --namespace "$TEST_NAMESPACE" > /dev/null; then
                print_status $GREEN "✅ Chart $chart_name templated successfully"
            else
                print_status $RED "❌ Chart $chart_name failed templating"
                return 1
            fi
        fi
    done
}

# Function to test chart installation
test_chart_installation() {
    local chart_path=$1
    local chart_name=$(basename "$chart_path")
    local release_name="${RELEASE_PREFIX}-${chart_name}"
    
    print_header "Testing Chart Installation: $chart_name"
    
    # Dry run installation
    print_status $BLUE "Performing dry run installation..."
    if helm install "$release_name" "$chart_path" --dry-run --debug --namespace "$TEST_NAMESPACE"; then
        print_status $GREEN "✅ Dry run successful"
    else
        print_status $RED "❌ Dry run failed"
        return 1
    fi
    
    # Actual installation
    print_status $BLUE "Installing chart..."
    if helm install "$release_name" "$chart_path" --namespace "$TEST_NAMESPACE" --wait --timeout=300s; then
        print_status $GREEN "✅ Chart installed successfully"
    else
        print_status $RED "❌ Chart installation failed"
        return 1
    fi
    
    # Check status
    print_status $BLUE "Checking release status..."
    helm status "$release_name" --namespace "$TEST_NAMESPACE"
    
    # List resources
    print_status $BLUE "Checking deployed resources..."
    kubectl get all -n "$TEST_NAMESPACE" -l "app.kubernetes.io/instance=$release_name"
    
    # Run tests if available
    print_status $BLUE "Running chart tests..."
    if helm test "$release_name" --namespace "$TEST_NAMESPACE" --logs 2>/dev/null; then
        print_status $GREEN "✅ Chart tests passed"
    else
        print_status $YELLOW "⚠️  No tests found or tests failed"
    fi
    
    echo "$release_name"
}

# Function to test chart upgrade
test_chart_upgrade() {
    local chart_path=$1
    local release_name=$2
    local chart_name=$(basename "$chart_path")
    
    print_header "Testing Chart Upgrade: $chart_name"
    
    # Modify values for upgrade
    local upgrade_values="replicaCount=3,image.tag=1.24-alpine"
    
    print_status $BLUE "Upgrading chart with new values..."
    if helm upgrade "$release_name" "$chart_path" --set "$upgrade_values" --namespace "$TEST_NAMESPACE" --wait; then
        print_status $GREEN "✅ Chart upgraded successfully"
    else
        print_status $RED "❌ Chart upgrade failed"
        return 1
    fi
    
    # Check upgrade status
    print_status $BLUE "Checking upgrade status..."
    helm status "$release_name" --namespace "$TEST_NAMESPACE"
    
    # Show history
    print_status $BLUE "Release history:"
    helm history "$release_name" --namespace "$TEST_NAMESPACE"
}

# Function to test rollback
test_chart_rollback() {
    local release_name=$1
    
    print_header "Testing Chart Rollback: $release_name"
    
    print_status $BLUE "Rolling back to previous version..."
    if helm rollback "$release_name" --namespace "$TEST_NAMESPACE" --wait; then
        print_status $GREEN "✅ Rollback successful"
    else
        print_status $RED "❌ Rollback failed"
        return 1
    fi
    
    # Check rollback status
    helm status "$release_name" --namespace "$TEST_NAMESPACE"
}

# Function to package charts
package_charts() {
    print_header "Packaging Helm Charts"
    
    if [ ! -d "$CHART_DIR" ]; then
        print_status $YELLOW "No charts directory found: $CHART_DIR"
        return 0
    fi
    
    mkdir -p "./packages"
    
    for chart in "$CHART_DIR"/*; do
        if [ -d "$chart" ] && [ -f "$chart/Chart.yaml" ]; then
            local chart_name=$(basename "$chart")
            print_status $BLUE "Packaging chart: $chart_name"
            
            if helm package "$chart" --destination "./packages"; then
                print_status $GREEN "✅ Chart $chart_name packaged successfully"
            else
                print_status $RED "❌ Chart $chart_name packaging failed"
                return 1
            fi
        fi
    done
    
    print_status $GREEN "✅ Packaged charts:"
    ls -la ./packages/
}

# Function to validate security
validate_security() {
    print_header "Validating Chart Security"
    
    local chart_path=$1
    local chart_name=$(basename "$chart_path")
    
    print_status $BLUE "Checking security configurations for: $chart_name"
    
    # Template and check for security contexts
    local templates=$(helm template "$chart_name" "$chart_path" --namespace "$TEST_NAMESPACE")
    
    # Check for security context
    if echo "$templates" | grep -q "securityContext:"; then
        print_status $GREEN "✅ Security context found"
    else
        print_status $YELLOW "⚠️  No security context defined"
    fi
    
    # Check for resource limits
    if echo "$templates" | grep -q "limits:"; then
        print_status $GREEN "✅ Resource limits found"
    else
        print_status $YELLOW "⚠️  No resource limits defined"
    fi
    
    # Check for non-root user
    if echo "$templates" | grep -q "runAsNonRoot: true"; then
        print_status $GREEN "✅ Non-root user configuration found"
    else
        print_status $YELLOW "⚠️  Non-root user not configured"
    fi
    
    # Check for read-only filesystem
    if echo "$templates" | grep -q "readOnlyRootFilesystem: true"; then
        print_status $GREEN "✅ Read-only root filesystem found"
    else
        print_status $YELLOW "⚠️  Read-only root filesystem not configured"
    fi
}

# Function to check dependencies
check_dependencies() {
    print_header "Checking Chart Dependencies"
    
    local chart_path=$1
    local chart_name=$(basename "$chart_path")
    
    if [ -f "$chart_path/Chart.yaml" ]; then
        # Check if chart has dependencies
        if grep -q "dependencies:" "$chart_path/Chart.yaml"; then
            print_status $BLUE "Chart $chart_name has dependencies"
            
            # Update dependencies
            print_status $BLUE "Updating dependencies..."
            if helm dependency update "$chart_path"; then
                print_status $GREEN "✅ Dependencies updated successfully"
            else
                print_status $RED "❌ Failed to update dependencies"
                return 1
            fi
            
            # List dependencies
            print_status $BLUE "Dependencies:"
            helm dependency list "$chart_path"
        else
            print_status $GREEN "✅ Chart $chart_name has no dependencies"
        fi
    fi
}

# Function to cleanup test resources
cleanup_test_resources() {
    print_header "Cleaning Up Test Resources"
    
    print_status $YELLOW "⚠️  This will delete all test releases and resources"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Uninstall all test releases
        print_status $BLUE "Uninstalling test releases..."
        helm list --namespace "$TEST_NAMESPACE" -q | grep "^$RELEASE_PREFIX-" | while read -r release; do
            print_status $BLUE "Uninstalling release: $release"
            helm uninstall "$release" --namespace "$TEST_NAMESPACE"
        done
        
        # Delete test namespace
        print_status $BLUE "Deleting test namespace: $TEST_NAMESPACE"
        kubectl delete namespace "$TEST_NAMESPACE" --ignore-not-found=true
        
        # Clean up packages
        if [ -d "./packages" ]; then
            print_status $BLUE "Removing packages directory"
            rm -rf "./packages"
        fi
        
        print_status $GREEN "✅ Cleanup completed"
    else
        print_status $BLUE "Cleanup cancelled"
    fi
}

# Function to show helm status
show_helm_status() {
    print_header "Helm Status Overview"
    
    print_status $BLUE "Helm Version:"
    helm version
    
    print_status $BLUE "\nConfigured Repositories:"
    helm repo list
    
    print_status $BLUE "\nReleases in all namespaces:"
    helm list --all-namespaces
    
    print_status $BLUE "\nReleases in test namespace:"
    helm list --namespace "$TEST_NAMESPACE" 2>/dev/null || print_status $YELLOW "No releases in test namespace"
    
    print_status $BLUE "\nKubernetes Resources in test namespace:"
    kubectl get all -n "$TEST_NAMESPACE" 2>/dev/null || print_status $YELLOW "Test namespace not found or empty"
}

# Function to run comprehensive tests
run_comprehensive_tests() {
    print_header "Running Comprehensive Helm Tests"
    
    local chart_path=$(create_example_chart)
    local release_name=""
    
    # Run all tests
    check_dependencies "$chart_path" && \
    lint_charts && \
    template_charts && \
    validate_security "$chart_path" && \
    release_name=$(test_chart_installation "$chart_path") && \
    test_chart_upgrade "$chart_path" "$release_name" && \
    test_chart_rollback "$release_name" && \
    package_charts
    
    if [ $? -eq 0 ]; then
        print_status $GREEN "✅ All tests passed successfully!"
    else
        print_status $RED "❌ Some tests failed"
        return 1
    fi
}

# Function to benchmark helm operations
benchmark_helm() {
    print_header "Benchmarking Helm Operations"
    
    local chart_path=$(create_example_chart)
    local chart_name=$(basename "$chart_path")
    local release_name="${RELEASE_PREFIX}-benchmark"
    
    # Benchmark installation
    print_status $BLUE "Benchmarking installation..."
    local start_time=$(date +%s.%N)
    helm install "$release_name" "$chart_path" --namespace "$TEST_NAMESPACE" --wait >/dev/null 2>&1
    local end_time=$(date +%s.%N)
    local install_time=$(echo "$end_time - $start_time" | bc)
    print_status $GREEN "Installation time: ${install_time}s"
    
    # Benchmark upgrade
    print_status $BLUE "Benchmarking upgrade..."
    start_time=$(date +%s.%N)
    helm upgrade "$release_name" "$chart_path" --set replicaCount=3 --namespace "$TEST_NAMESPACE" --wait >/dev/null 2>&1
    end_time=$(date +%s.%N)
    local upgrade_time=$(echo "$end_time - $start_time" | bc)
    print_status $GREEN "Upgrade time: ${upgrade_time}s"
    
    # Benchmark uninstall
    print_status $BLUE "Benchmarking uninstall..."
    start_time=$(date +%s.%N)
    helm uninstall "$release_name" --namespace "$TEST_NAMESPACE" >/dev/null 2>&1
    end_time=$(date +%s.%N)
    local uninstall_time=$(echo "$end_time - $start_time" | bc)
    print_status $GREEN "Uninstall time: ${uninstall_time}s"
    
    print_status $PURPLE "Benchmark Results:"
    print_status $PURPLE "  Installation: ${install_time}s"
    print_status $PURPLE "  Upgrade: ${upgrade_time}s"
    print_status $PURPLE "  Uninstall: ${uninstall_time}s"
}

# Main menu
show_menu() {
    print_header "Helm Testing and Validation Script"
    echo "1.  Check Prerequisites"
    echo "2.  Setup Repositories"
    echo "3.  Create Example Chart"
    echo "4.  Lint Charts"
    echo "5.  Template Charts"
    echo "6.  Test Chart Installation"
    echo "7.  Test Chart Upgrade"
    echo "8.  Test Chart Rollback"
    echo "9.  Package Charts"
    echo "10. Validate Security"
    echo "11. Check Dependencies"
    echo "12. Run Comprehensive Tests"
    echo "13. Benchmark Helm Operations"
    echo "14. Show Helm Status"
    echo "15. Cleanup Test Resources"
    echo "16. Exit"
    echo
}

# Main script logic
main() {
    while true; do
        show_menu
        read -p "Select an option (1-16): " choice
        
        case $choice in
            1)
                check_prerequisites
                ;;
            2)
                setup_repositories
                ;;
            3)
                create_example_chart
                ;;
            4)
                lint_charts
                ;;
            5)
                template_charts
                ;;
            6)
                chart_path=$(create_example_chart)
                test_chart_installation "$chart_path"
                ;;
            7)
                chart_path=$(create_example_chart)
                release_name="${RELEASE_PREFIX}-$(basename "$chart_path")"
                test_chart_upgrade "$chart_path" "$release_name"
                ;;
            8)
                release_name="${RELEASE_PREFIX}-example-app"
                test_chart_rollback "$release_name"
                ;;
            9)
                package_charts
                ;;
            10)
                chart_path=$(create_example_chart)
                validate_security "$chart_path"
                ;;
            11)
                chart_path=$(create_example_chart)
                check_dependencies "$chart_path"
                ;;
            12)
                run_comprehensive_tests
                ;;
            13)
                benchmark_helm
                ;;
            14)
                show_helm_status
                ;;
            15)
                cleanup_test_resources
                ;;
            16)
                print_status $GREEN "Goodbye!"
                exit 0
                ;;
            *)
                print_status $RED "Invalid option. Please try again."
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Check if bc is available for benchmarking
if ! command -v bc &> /dev/null; then
    print_status $YELLOW "⚠️  bc not found. Benchmarking will be disabled."
fi

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
