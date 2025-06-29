#!/bin/bash

# Static Provisioning Testing and Validation Script
# This script helps test and validate static provisioning configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_status $RED "❌ kubectl is not installed"
        exit 1
    else
        print_status $GREEN "✅ kubectl is available"
        kubectl version --client --short
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        print_status $RED "❌ Cannot connect to Kubernetes cluster"
        exit 1
    else
        print_status $GREEN "✅ Connected to Kubernetes cluster"
    fi
    
    # Check if we have the required permissions
    if ! kubectl auth can-i create pv &> /dev/null; then
        print_status $YELLOW "⚠️  Warning: May not have permissions to create PersistentVolumes"
    fi
}

# Function to test cloud provider static provisioning
test_cloud_provisioning() {
    local provider=$1
    print_header "Testing ${provider} Static Provisioning"
    
    case $provider in
        "aws")
            test_aws_provisioning
            ;;
        "azure")
            test_azure_provisioning
            ;;
        "gcp")
            test_gcp_provisioning
            ;;
        *)
            print_status $RED "❌ Unknown provider: $provider"
            ;;
    esac
}

test_aws_provisioning() {
    print_status $BLUE "Testing AWS EBS Static Provisioning..."
    
    # Check if AWS EBS CSI driver is installed
    if kubectl get csidriver ebs.csi.aws.com &> /dev/null; then
        print_status $GREEN "✅ AWS EBS CSI driver is installed"
    else
        print_status $RED "❌ AWS EBS CSI driver is not installed"
        print_status $YELLOW "Install with: kubectl apply -k \"github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.24\""
        return 1
    fi
    
    # Check for EBS volume (mock check)
    print_status $YELLOW "⚠️  Ensure you have created an EBS volume and updated the volumeHandle in the PV manifest"
    
    # Apply the AWS configuration
    kubectl apply -f multi-platform-static-examples.yaml --dry-run=client
    print_status $GREEN "✅ AWS EBS configuration is valid"
}

test_azure_provisioning() {
    print_status $BLUE "Testing Azure Disk Static Provisioning..."
    
    # Check if Azure Disk CSI driver is installed
    if kubectl get csidriver disk.csi.azure.com &> /dev/null; then
        print_status $GREEN "✅ Azure Disk CSI driver is installed"
    else
        print_status $RED "❌ Azure Disk CSI driver is not installed"
        print_status $YELLOW "This is usually pre-installed in AKS clusters"
        return 1
    fi
    
    print_status $YELLOW "⚠️  Ensure you have created an Azure Disk and updated the volumeHandle in the PV manifest"
    
    # Validate Azure configuration
    kubectl apply -f multi-platform-static-examples.yaml --dry-run=client
    print_status $GREEN "✅ Azure Disk configuration is valid"
}

test_gcp_provisioning() {
    print_status $BLUE "Testing GCP Persistent Disk Static Provisioning..."
    
    # Check if GCE PD CSI driver is installed
    if kubectl get csidriver pd.csi.storage.gke.io &> /dev/null; then
        print_status $GREEN "✅ GCP Persistent Disk CSI driver is installed"
    else
        print_status $RED "❌ GCP Persistent Disk CSI driver is not installed"
        print_status $YELLOW "This is usually pre-installed in GKE clusters"
        return 1
    fi
    
    print_status $YELLOW "⚠️  Ensure you have created a GCE Persistent Disk and updated the volumeHandle in the PV manifest"
    
    # Validate GCP configuration
    kubectl apply -f multi-platform-static-examples.yaml --dry-run=client
    print_status $GREEN "✅ GCP Persistent Disk configuration is valid"
}

# Function to test NFS provisioning
test_nfs_provisioning() {
    print_header "Testing NFS Static Provisioning"
    
    # Check if NFS CSI driver is installed
    if kubectl get csidriver nfs.csi.k8s.io &> /dev/null; then
        print_status $GREEN "✅ NFS CSI driver is installed"
    else
        print_status $YELLOW "⚠️  NFS CSI driver not found, checking for native NFS support"
    fi
    
    # Test NFS server connectivity (if specified)
    NFS_SERVER="${NFS_SERVER:-10.0.0.100}"
    print_status $BLUE "Testing connectivity to NFS server: $NFS_SERVER"
    
    if timeout 5 bash -c "</dev/tcp/$NFS_SERVER/2049" 2>/dev/null; then
        print_status $GREEN "✅ NFS server $NFS_SERVER is reachable on port 2049"
    else
        print_status $YELLOW "⚠️  Cannot reach NFS server $NFS_SERVER:2049 (this may be expected if using external NFS)"
    fi
    
    # Validate NFS configuration
    kubectl apply -f nfs-static-examples.yaml --dry-run=client
    print_status $GREEN "✅ NFS configuration is valid"
}

# Function to test local storage provisioning
test_local_provisioning() {
    print_header "Testing Local Storage Static Provisioning"
    
    # Check for local storage paths on nodes
    print_status $BLUE "Checking for local storage paths on nodes..."
    
    # Get list of nodes
    nodes=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
    
    for node in $nodes; do
        print_status $BLUE "Checking node: $node"
        
        # Check if we can access the node (this might not work in all environments)
        if kubectl get node $node &> /dev/null; then
            print_status $GREEN "✅ Node $node is accessible"
        else
            print_status $RED "❌ Cannot access node $node"
        fi
    done
    
    print_status $YELLOW "⚠️  Ensure local storage paths exist on target nodes:"
    print_status $YELLOW "   - /mnt/nvme-ssd/database (for NVMe storage)"
    print_status $YELLOW "   - /mnt/ssd/cache (for SSD cache)"
    print_status $YELLOW "   - /mnt/storage/logs (for log storage)"
    print_status $YELLOW "   - /mnt/models (for ML models on edge nodes)"
    
    # Validate local storage configuration
    kubectl apply -f local-storage-examples.yaml --dry-run=client
    print_status $GREEN "✅ Local storage configuration is valid"
}

# Function to deploy and test a specific example
deploy_test_example() {
    local example_type=$1
    print_header "Deploying and Testing $example_type Example"
    
    case $example_type in
        "multi-platform")
            kubectl apply -f multi-platform-static-examples.yaml
            test_multi_platform_deployment
            ;;
        "nfs")
            kubectl apply -f nfs-static-examples.yaml
            test_nfs_deployment
            ;;
        "local")
            kubectl apply -f local-storage-examples.yaml
            test_local_deployment
            ;;
        *)
            print_status $RED "❌ Unknown example type: $example_type"
            ;;
    esac
}

test_multi_platform_deployment() {
    print_status $BLUE "Testing multi-platform deployment..."
    
    # Wait for PVs to be created
    print_status $BLUE "Waiting for PersistentVolumes to be created..."
    sleep 5
    
    # Check PV status
    kubectl get pv | grep -E "(aws-ebs|azure-disk|gce-disk)" || true
    
    # Check PVC status
    kubectl get pvc -n production | grep -E "(aws-database|azure-app|gce-analytics)" || true
    
    # Check pod status
    kubectl get pods -n production -l app=postgresql || true
    kubectl get pods -n production -l app=azure-app || true
    kubectl get pods -n production -l app=elasticsearch || true
}

test_nfs_deployment() {
    print_status $BLUE "Testing NFS deployment..."
    
    # Check NFS PVs
    kubectl get pv | grep nfs || true
    
    # Check NFS PVCs
    kubectl get pvc -n production | grep -E "(shared-data|logs|backups)" || true
    
    # Check applications using NFS
    kubectl get pods -n production -l app=web-app || true
    kubectl get pods -n production -l app=file-processor || true
}

test_local_deployment() {
    print_status $BLUE "Testing local storage deployment..."
    
    # Check local PVs
    kubectl get pv | grep local || true
    
    # Check local PVCs
    kubectl get pvc -n production | grep -E "(database-storage|cache-storage|logs-storage)" || true
    kubectl get pvc -n edge-computing | grep ml-models || true
    
    # Check applications using local storage
    kubectl get pods -n production -l storage=local-nvme || true
    kubectl get pods -n production -l storage=local-ssd || true
    kubectl get pods -n edge-computing -l location=edge || true
}

# Function to cleanup test resources
cleanup_resources() {
    print_header "Cleaning Up Test Resources"
    
    print_status $YELLOW "⚠️  This will delete all static provisioning test resources"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status $BLUE "Deleting resources..."
        
        # Delete in reverse order to avoid dependency issues
        kubectl delete -f multi-platform-static-examples.yaml --ignore-not-found=true
        kubectl delete -f nfs-static-examples.yaml --ignore-not-found=true
        kubectl delete -f local-storage-examples.yaml --ignore-not-found=true
        
        print_status $GREEN "✅ Cleanup completed"
    else
        print_status $BLUE "Cleanup cancelled"
    fi
}

# Function to show storage statistics
show_storage_stats() {
    print_header "Storage Statistics"
    
    print_status $BLUE "PersistentVolumes:"
    kubectl get pv -o wide
    
    print_status $BLUE "\nPersistentVolumeClaims:"
    kubectl get pvc --all-namespaces
    
    print_status $BLUE "\nStorageClasses:"
    kubectl get storageclass
    
    print_status $BLUE "\nCSI Drivers:"
    kubectl get csidriver
    
    print_status $BLUE "\nNode Storage Usage:"
    kubectl top nodes --use-protocol-buffers=false 2>/dev/null || print_status $YELLOW "⚠️  Metrics server not available"
}

# Function to troubleshoot common issues
troubleshoot() {
    print_header "Troubleshooting Static Provisioning Issues"
    
    print_status $BLUE "Checking common issues..."
    
    # Check for PVs in failed state
    failed_pvs=$(kubectl get pv -o jsonpath='{.items[?(@.status.phase!="Available")].metadata.name}' || true)
    if [ -n "$failed_pvs" ]; then
        print_status $RED "❌ Found PVs not in Available state:"
        echo "$failed_pvs"
    else
        print_status $GREEN "✅ All PVs are in Available state"
    fi
    
    # Check for pending PVCs
    pending_pvcs=$(kubectl get pvc --all-namespaces -o jsonpath='{.items[?(@.status.phase=="Pending")].metadata.name}' || true)
    if [ -n "$pending_pvcs" ]; then
        print_status $RED "❌ Found pending PVCs:"
        echo "$pending_pvcs"
        print_status $BLUE "Use 'kubectl describe pvc <name>' for more details"
    else
        print_status $GREEN "✅ No pending PVCs found"
    fi
    
    # Check for failed pods
    failed_pods=$(kubectl get pods --all-namespaces -o jsonpath='{.items[?(@.status.phase=="Failed")].metadata.name}' || true)
    if [ -n "$failed_pods" ]; then
        print_status $RED "❌ Found failed pods:"
        echo "$failed_pods"
    else
        print_status $GREEN "✅ No failed pods found"
    fi
    
    # Check node affinity issues
    print_status $BLUE "Checking node affinity for local PVs..."
    kubectl get pv -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0] | grep -v '<none>' || true
}

# Main menu
show_menu() {
    print_header "Static Provisioning Test Script"
    echo "1. Check Prerequisites"
    echo "2. Test Cloud Provider Provisioning (AWS/Azure/GCP)"
    echo "3. Test NFS Provisioning"
    echo "4. Test Local Storage Provisioning"
    echo "5. Deploy and Test Examples"
    echo "6. Show Storage Statistics"
    echo "7. Troubleshoot Issues"
    echo "8. Cleanup Resources"
    echo "9. Exit"
    echo
}

# Main script logic
main() {
    while true; do
        show_menu
        read -p "Select an option (1-9): " choice
        
        case $choice in
            1)
                check_prerequisites
                ;;
            2)
                echo "Available providers: aws, azure, gcp"
                read -p "Enter provider: " provider
                test_cloud_provisioning "$provider"
                ;;
            3)
                test_nfs_provisioning
                ;;
            4)
                test_local_provisioning
                ;;
            5)
                echo "Available examples: multi-platform, nfs, local"
                read -p "Enter example type: " example_type
                deploy_test_example "$example_type"
                ;;
            6)
                show_storage_stats
                ;;
            7)
                troubleshoot
                ;;
            8)
                cleanup_resources
                ;;
            9)
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

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
