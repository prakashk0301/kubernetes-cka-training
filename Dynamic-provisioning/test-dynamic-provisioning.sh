#!/bin/bash

# 🔍 Dynamic Provisioning Setup and Test Script
# This script helps set up and test dynamic provisioning

echo "🚀 Dynamic Provisioning Setup and Test Script"
echo "=============================================="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check status
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ SUCCESS${NC}"
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
}

# Function to wait for resource
wait_for_resource() {
    local resource_type=$1
    local resource_name=$2
    local condition=$3
    local timeout=${4:-300}
    
    echo -n "⏳ Waiting for $resource_type/$resource_name to be $condition..."
    kubectl wait --for=condition=$condition $resource_type/$resource_name --timeout=${timeout}s
    check_status
}

# Detect cloud provider or local setup
detect_environment() {
    echo "🔍 Detecting Kubernetes environment..."
    
    # Check for AWS
    if kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | grep -q "aws"; then
        echo -e "${BLUE}☁️  Detected: AWS EKS${NC}"
        return 1
    fi
    
    # Check for Azure
    if kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | grep -q "azure"; then
        echo -e "${BLUE}☁️  Detected: Azure AKS${NC}"
        return 2
    fi
    
    # Check for GCP
    if kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | grep -q "gce"; then
        echo -e "${BLUE}☁️  Detected: Google GKE${NC}"
        return 3
    fi
    
    # Default to local
    echo -e "${BLUE}🏠 Detected: Local/On-Premises${NC}"
    return 0
}

# Install local path provisioner
install_local_path_provisioner() {
    echo "📦 Installing Local Path Provisioner..."
    kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.28/deploy/local-path-storage.yaml
    check_status
    
    echo "⏳ Waiting for local-path-provisioner to be ready..."
    kubectl wait --for=condition=ready pod -l app=local-path-provisioner -n local-path-storage --timeout=300s
    check_status
}

# Test dynamic provisioning
test_dynamic_provisioning() {
    local storageclass=$1
    local test_name="dynamic-test-$(date +%s)"
    
    echo "🧪 Testing dynamic provisioning with StorageClass: $storageclass"
    
    # Create test PVC
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $test_name-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: $storageclass
  resources:
    requests:
      storage: 1Gi
EOF
    
    # Create test pod
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: $test_name-pod
spec:
  containers:
  - name: test
    image: busybox:1.35
    command: ["/bin/sh"]
    args: ["-c", "echo 'Dynamic provisioning test successful!' > /data/test.txt && sleep 3600"]
    volumeMounts:
    - name: test-volume
      mountPath: /data
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: $test_name-pvc
  restartPolicy: Never
EOF
    
    # Wait for PVC to be bound
    echo "⏳ Waiting for PVC to be bound..."
    kubectl wait --for=condition=Bound pvc/$test_name-pvc --timeout=300s
    check_status || return 1
    
    # Wait for pod to be ready
    echo "⏳ Waiting for test pod to be ready..."
    kubectl wait --for=condition=Ready pod/$test_name-pod --timeout=300s
    check_status || return 1
    
    # Verify data persistence
    echo "📝 Verifying data persistence..."
    kubectl exec $test_name-pod -- cat /data/test.txt
    check_status || return 1
    
    # Show results
    echo -e "${GREEN}✅ Dynamic provisioning test completed successfully!${NC}"
    echo
    echo "📊 Test Results:"
    echo "---------------"
    kubectl get pvc $test_name-pvc
    kubectl get pv
    
    # Cleanup
    echo
    read -p "🧹 Clean up test resources? (y/n): " cleanup
    if [ "$cleanup" = "y" ]; then
        kubectl delete pod $test_name-pod
        kubectl delete pvc $test_name-pvc
        echo -e "${GREEN}✅ Cleanup completed${NC}"
    fi
}

# Check prerequisites
check_prerequisites() {
    echo "🔧 Checking prerequisites..."
    
    # Check kubectl
    echo -n "kubectl command: "
    which kubectl > /dev/null
    check_status || return 1
    
    # Check cluster connectivity
    echo -n "Cluster connectivity: "
    kubectl cluster-info > /dev/null 2>&1
    check_status || return 1
    
    # Check RBAC permissions
    echo -n "RBAC permissions: "
    kubectl auth can-i create pvc > /dev/null 2>&1
    check_status || return 1
    
    return 0
}

# Main execution
main() {
    # Check prerequisites
    check_prerequisites || exit 1
    
    echo
    detect_environment
    env_type=$?
    
    echo
    echo "📋 Available StorageClasses:"
    kubectl get storageclass
    
    echo
    case $env_type in
        0) # Local
            echo "🏠 Setting up local dynamic provisioning..."
            install_local_path_provisioner
            echo
            echo "💡 Suggested StorageClass: local-path"
            ;;
        1) # AWS
            echo "☁️  For AWS EKS, ensure you have EBS or EFS CSI drivers installed"
            echo "💡 Suggested StorageClasses: gp2, gp3, efs-sc"
            ;;
        2) # Azure
            echo "☁️  For Azure AKS, CSI drivers are usually pre-installed"
            echo "💡 Suggested StorageClasses: default, managed-premium"
            ;;
        3) # GCP
            echo "☁️  For Google GKE, CSI drivers are usually pre-installed"
            echo "💡 Suggested StorageClasses: standard, ssd"
            ;;
    esac
    
    echo
    read -p "Enter StorageClass name to test (or press Enter for 'local-path'): " storageclass
    storageclass=${storageclass:-local-path}
    
    # Check if StorageClass exists
    if ! kubectl get storageclass $storageclass > /dev/null 2>&1; then
        echo -e "${RED}❌ StorageClass '$storageclass' not found${NC}"
        echo "Available StorageClasses:"
        kubectl get storageclass
        exit 1
    fi
    
    echo
    test_dynamic_provisioning $storageclass
}

# Run main function
main "$@"
