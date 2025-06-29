#!/usr/bin/env pwsh

# Comprehensive Cluster Administration Testing Script
# This script provides interactive testing for cluster administration scenarios

Write-Host "=== Kubernetes Cluster Administration Testing Suite ===" -ForegroundColor Cyan
Write-Host "Interactive testing for resource management, QoS, quotas, and security" -ForegroundColor Green
Write-Host ""

# Function to check prerequisites
function Test-Prerequisites {
    Write-Host "🔍 Checking Prerequisites..." -ForegroundColor Yellow
    
    # Check kubectl
    try {
        $kubectlVersion = kubectl version --client --short 2>$null
        if ($kubectlVersion) {
            Write-Host "✅ kubectl: $kubectlVersion" -ForegroundColor Green
        } else {
            Write-Host "❌ kubectl not found" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ kubectl not available" -ForegroundColor Red
        return $false
    }
    
    # Check cluster connectivity
    try {
        $clusterInfo = kubectl cluster-info 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Cluster connectivity verified" -ForegroundColor Green
        } else {
            Write-Host "❌ Cannot connect to cluster" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ Cluster connection failed" -ForegroundColor Red
        return $false
    }
    
    # Check admin permissions
    try {
        $canCreate = kubectl auth can-i create pods --all-namespaces 2>$null
        if ($canCreate -eq "yes") {
            Write-Host "✅ Admin permissions verified" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Limited permissions detected" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️  Unable to verify permissions" -ForegroundColor Yellow
    }
    
    # Check metrics server
    try {
        kubectl top nodes 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Metrics server available" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Metrics server not available (kubectl top commands will fail)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️  Metrics server status unknown" -ForegroundColor Yellow
    }
    
    return $true
}

# Function to create test namespace
function New-TestNamespace {
    param([string]$NamespaceName = "cluster-admin-test")
    
    Write-Host "📦 Creating test namespace: $NamespaceName" -ForegroundColor Yellow
    
    $namespaceYaml = @"
apiVersion: v1
kind: Namespace
metadata:
  name: $NamespaceName
  labels:
    purpose: testing
    created-by: cluster-admin-test-script
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/warn: baseline
"@
    
    $namespaceYaml | kubectl apply -f - 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Namespace '$NamespaceName' created/updated" -ForegroundColor Green
        return $true
    } else {
        Write-Host "❌ Failed to create namespace" -ForegroundColor Red
        return $false
    }
}

# Function to test resource quotas
function Test-ResourceQuotas {
    param([string]$Namespace = "cluster-admin-test")
    
    Write-Host "📊 Testing Resource Quotas in namespace: $Namespace" -ForegroundColor Yellow
    
    # Create resource quota
    $quotaYaml = @"
apiVersion: v1
kind: ResourceQuota
metadata:
  name: test-quota
  namespace: $Namespace
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    pods: "10"
    persistentvolumeclaims: "5"
    services: "5"
    secrets: "10"
    configmaps: "10"
"@
    
    Write-Host "  Creating resource quota..." -ForegroundColor Cyan
    $quotaYaml | kubectl apply -f - 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Resource quota created" -ForegroundColor Green
        
        # Show quota details
        Write-Host "  📋 Quota details:" -ForegroundColor Cyan
        kubectl describe quota test-quota -n $Namespace
        
        return $true
    } else {
        Write-Host "  ❌ Failed to create resource quota" -ForegroundColor Red
        return $false
    }
}

# Function to test limit ranges
function Test-LimitRanges {
    param([string]$Namespace = "cluster-admin-test")
    
    Write-Host "📏 Testing Limit Ranges in namespace: $Namespace" -ForegroundColor Yellow
    
    # Create limit range
    $limitRangeYaml = @"
apiVersion: v1
kind: LimitRange
metadata:
  name: test-limits
  namespace: $Namespace
spec:
  limits:
  - type: Container
    default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    min:
      cpu: "50m"
      memory: "64Mi"
    max:
      cpu: "2"
      memory: "4Gi"
  - type: Pod
    min:
      cpu: "100m"
      memory: "128Mi"
    max:
      cpu: "4"
      memory: "8Gi"
"@
    
    Write-Host "  Creating limit range..." -ForegroundColor Cyan
    $limitRangeYaml | kubectl apply -f - 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Limit range created" -ForegroundColor Green
        
        # Show limit range details
        Write-Host "  📋 Limit range details:" -ForegroundColor Cyan
        kubectl describe limitrange test-limits -n $Namespace
        
        return $true
    } else {
        Write-Host "  ❌ Failed to create limit range" -ForegroundColor Red
        return $false
    }
}

# Function to test QoS classes
function Test-QoSClasses {
    param([string]$Namespace = "cluster-admin-test")
    
    Write-Host "🏆 Testing Quality of Service (QoS) Classes" -ForegroundColor Yellow
    
    # Test Guaranteed QoS
    Write-Host "  Testing Guaranteed QoS..." -ForegroundColor Cyan
    $guaranteedPod = @"
apiVersion: v1
kind: Pod
metadata:
  name: qos-guaranteed-test
  namespace: $Namespace
  labels:
    qos-test: guaranteed
spec:
  containers:
  - name: test-container
    image: busybox:1.36
    command: ["sleep", "300"]
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "100m"
  restartPolicy: Never
"@
    
    $guaranteedPod | kubectl apply -f - 2>$null
    
    # Test Burstable QoS
    Write-Host "  Testing Burstable QoS..." -ForegroundColor Cyan
    $burstablePod = @"
apiVersion: v1
kind: Pod
metadata:
  name: qos-burstable-test
  namespace: $Namespace
  labels:
    qos-test: burstable
spec:
  containers:
  - name: test-container
    image: busybox:1.36
    command: ["sleep", "300"]
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "256Mi"
        cpu: "500m"
  restartPolicy: Never
"@
    
    $burstablePod | kubectl apply -f - 2>$null
    
    # Test BestEffort QoS
    Write-Host "  Testing BestEffort QoS..." -ForegroundColor Cyan
    $bestEffortPod = @"
apiVersion: v1
kind: Pod
metadata:
  name: qos-besteffort-test
  namespace: $Namespace
  labels:
    qos-test: besteffort
spec:
  containers:
  - name: test-container
    image: busybox:1.36
    command: ["sleep", "300"]
  restartPolicy: Never
"@
    
    $bestEffortPod | kubectl apply -f - 2>$null
    
    # Wait for pods to be scheduled
    Write-Host "  Waiting for pods to be scheduled..." -ForegroundColor Cyan
    Start-Sleep -Seconds 10
    
    # Check QoS classes
    Write-Host "  📋 QoS Class Results:" -ForegroundColor Cyan
    kubectl get pods -n $Namespace -l qos-test -o custom-columns="NAME:.metadata.name,QOS:.status.qosClass,STATUS:.status.phase"
    
    return $true
}

# Function to test resource monitoring
function Test-ResourceMonitoring {
    param([string]$Namespace = "cluster-admin-test")
    
    Write-Host "📈 Testing Resource Monitoring" -ForegroundColor Yellow
    
    # Check if metrics are available
    try {
        Write-Host "  📊 Node resource usage:" -ForegroundColor Cyan
        kubectl top nodes 2>$null
        
        Write-Host "  📊 Pod resource usage:" -ForegroundColor Cyan
        kubectl top pods -n $Namespace 2>$null
        
        Write-Host "  📊 All pods resource usage:" -ForegroundColor Cyan
        kubectl top pods --all-namespaces --sort-by=cpu 2>$null | Select-Object -First 10
        
    } catch {
        Write-Host "  ⚠️  Metrics server not available" -ForegroundColor Yellow
    }
    
    # Show resource quota usage
    Write-Host "  📊 Resource quota usage:" -ForegroundColor Cyan
    kubectl describe quota -n $Namespace 2>$null
    
    return $true
}

# Function to test pod disruption budgets
function Test-PodDisruptionBudgets {
    param([string]$Namespace = "cluster-admin-test")
    
    Write-Host "🛡️ Testing Pod Disruption Budgets" -ForegroundColor Yellow
    
    # Create a deployment
    Write-Host "  Creating test deployment..." -ForegroundColor Cyan
    $deploymentYaml = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pdb-test-app
  namespace: $Namespace
spec:
  replicas: 3
  selector:
    matchLabels:
      app: pdb-test
  template:
    metadata:
      labels:
        app: pdb-test
    spec:
      containers:
      - name: app
        image: nginx:1.25-alpine
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
"@
    
    $deploymentYaml | kubectl apply -f - 2>$null
    
    # Create PDB
    Write-Host "  Creating Pod Disruption Budget..." -ForegroundColor Cyan
    $pdbYaml = @"
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: pdb-test
  namespace: $Namespace
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: pdb-test
"@
    
    $pdbYaml | kubectl apply -f - 2>$null
    
    # Wait for deployment
    Write-Host "  Waiting for deployment to be ready..." -ForegroundColor Cyan
    kubectl wait --for=condition=available --timeout=60s deployment/pdb-test-app -n $Namespace 2>$null
    
    # Show PDB status
    Write-Host "  📋 Pod Disruption Budget status:" -ForegroundColor Cyan
    kubectl get pdb -n $Namespace
    kubectl describe pdb pdb-test -n $Namespace
    
    return $true
}

# Function to test security policies
function Test-SecurityPolicies {
    param([string]$Namespace = "cluster-admin-test")
    
    Write-Host "🔒 Testing Security Policies" -ForegroundColor Yellow
    
    # Test pod with security context
    Write-Host "  Testing pod with security context..." -ForegroundColor Cyan
    $securePod = @"
apiVersion: v1
kind: Pod
metadata:
  name: security-test-pod
  namespace: $Namespace
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
  containers:
  - name: secure-container
    image: alpine:3.18
    command: ["sleep", "300"]
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      runAsUser: 1000
      capabilities:
        drop:
        - ALL
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
  restartPolicy: Never
"@
    
    $securePod | kubectl apply -f - 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Secure pod created successfully" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Failed to create secure pod" -ForegroundColor Red
    }
    
    # Check pod security standards
    Write-Host "  📋 Pod Security Standards:" -ForegroundColor Cyan
    kubectl get ns $Namespace -o yaml | Select-String "pod-security"
    
    return $true
}

# Function to generate load test
function Start-LoadTest {
    param([string]$Namespace = "cluster-admin-test")
    
    Write-Host "⚡ Starting Load Test" -ForegroundColor Yellow
    
    # Create a load testing job
    $loadTestJob = @"
apiVersion: batch/v1
kind: Job
metadata:
  name: load-test
  namespace: $Namespace
spec:
  template:
    spec:
      containers:
      - name: load-generator
        image: busybox:1.36
        command:
        - /bin/sh
        - -c
        - |
          echo "Starting CPU load test..."
          for i in `$(seq 1 4); do
            echo "Starting CPU worker \$i"
            (while true; do echo "CPU load \$i" > /dev/null; done) &
          done
          echo "Load test running for 60 seconds..."
          sleep 60
          echo "Load test completed"
        resources:
          requests:
            memory: "256Mi"
            cpu: "500m"
          limits:
            memory: "512Mi"
            cpu: "1000m"
      restartPolicy: Never
  backoffLimit: 1
"@
    
    Write-Host "  Creating load test job..." -ForegroundColor Cyan
    $loadTestJob | kubectl apply -f - 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Load test job created" -ForegroundColor Green
        Write-Host "  📊 Monitor with: kubectl logs -f job/load-test -n $Namespace" -ForegroundColor Cyan
    } else {
        Write-Host "  ❌ Failed to create load test job" -ForegroundColor Red
    }
    
    return $true
}

# Function to show comprehensive status
function Show-ClusterStatus {
    param([string]$Namespace = "cluster-admin-test")
    
    Write-Host "📊 Comprehensive Cluster Status" -ForegroundColor Yellow
    
    Write-Host "  🖥️  Node Status:" -ForegroundColor Cyan
    kubectl get nodes -o wide
    
    Write-Host "`n  📦 Namespace Resources:" -ForegroundColor Cyan
    kubectl get all -n $Namespace
    
    Write-Host "`n  📊 Resource Quotas:" -ForegroundColor Cyan
    kubectl get quota -n $Namespace
    
    Write-Host "`n  📏 Limit Ranges:" -ForegroundColor Cyan
    kubectl get limitrange -n $Namespace
    
    Write-Host "`n  🛡️  Pod Disruption Budgets:" -ForegroundColor Cyan
    kubectl get pdb -n $Namespace
    
    Write-Host "`n  ⚡ Events:" -ForegroundColor Cyan
    kubectl get events -n $Namespace --sort-by='.lastTimestamp' | Select-Object -Last 10
    
    try {
        Write-Host "`n  📈 Resource Usage:" -ForegroundColor Cyan
        kubectl top nodes
        kubectl top pods -n $Namespace
    } catch {
        Write-Host "  ⚠️  Metrics not available" -ForegroundColor Yellow
    }
}

# Function to cleanup test resources
function Remove-TestResources {
    param([string]$Namespace = "cluster-admin-test")
    
    Write-Host "🧹 Cleaning up test resources" -ForegroundColor Yellow
    
    $confirmation = Read-Host "Are you sure you want to delete namespace '$Namespace' and all its resources? (y/N)"
    
    if ($confirmation -eq 'y' -or $confirmation -eq 'Y') {
        Write-Host "  Deleting namespace and all resources..." -ForegroundColor Cyan
        kubectl delete namespace $Namespace 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ Cleanup completed" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Cleanup failed" -ForegroundColor Red
        }
    } else {
        Write-Host "  ❌ Cleanup cancelled" -ForegroundColor Yellow
    }
}

# Main interactive menu
function Show-Menu {
    Write-Host "`n=== Cluster Administration Testing Menu ===" -ForegroundColor Cyan
    Write-Host "1. Run Prerequisites Check" -ForegroundColor White
    Write-Host "2. Create Test Namespace" -ForegroundColor White
    Write-Host "3. Test Resource Quotas" -ForegroundColor White
    Write-Host "4. Test Limit Ranges" -ForegroundColor White
    Write-Host "5. Test QoS Classes" -ForegroundColor White
    Write-Host "6. Test Pod Disruption Budgets" -ForegroundColor White
    Write-Host "7. Test Security Policies" -ForegroundColor White
    Write-Host "8. Test Resource Monitoring" -ForegroundColor White
    Write-Host "9. Start Load Test" -ForegroundColor White
    Write-Host "10. Show Cluster Status" -ForegroundColor White
    Write-Host "11. Run All Tests" -ForegroundColor Yellow
    Write-Host "12. Cleanup Test Resources" -ForegroundColor Red
    Write-Host "0. Exit" -ForegroundColor Gray
    Write-Host ""
}

# Main execution
$namespace = "cluster-admin-test"

while ($true) {
    Show-Menu
    $choice = Read-Host "Select an option (0-12)"
    
    switch ($choice) {
        "1" { Test-Prerequisites }
        "2" { New-TestNamespace -NamespaceName $namespace }
        "3" { Test-ResourceQuotas -Namespace $namespace }
        "4" { Test-LimitRanges -Namespace $namespace }
        "5" { Test-QoSClasses -Namespace $namespace }
        "6" { Test-PodDisruptionBudgets -Namespace $namespace }
        "7" { Test-SecurityPolicies -Namespace $namespace }
        "8" { Test-ResourceMonitoring -Namespace $namespace }
        "9" { Start-LoadTest -Namespace $namespace }
        "10" { Show-ClusterStatus -Namespace $namespace }
        "11" {
            Write-Host "🚀 Running All Tests..." -ForegroundColor Cyan
            if (Test-Prerequisites) {
                New-TestNamespace -NamespaceName $namespace
                Test-ResourceQuotas -Namespace $namespace
                Test-LimitRanges -Namespace $namespace
                Test-QoSClasses -Namespace $namespace
                Test-PodDisruptionBudgets -Namespace $namespace
                Test-SecurityPolicies -Namespace $namespace
                Test-ResourceMonitoring -Namespace $namespace
                Show-ClusterStatus -Namespace $namespace
                Write-Host "✅ All tests completed!" -ForegroundColor Green
            }
        }
        "12" { Remove-TestResources -Namespace $namespace }
        "0" { 
            Write-Host "Goodbye! 👋" -ForegroundColor Green
            break 
        }
        default { Write-Host "Invalid option. Please try again." -ForegroundColor Red }
    }
    
    Write-Host "`nPress any key to continue..." -ForegroundColor Gray
    [System.Console]::ReadKey() | Out-Null
}

Write-Host "`n=== Cluster Administration Testing Complete ===" -ForegroundColor Cyan
