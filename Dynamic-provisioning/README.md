# Dynamic Provisioning in Kubernetes

This directory contains comprehensive guides for setting up dynamic provisioning in Kubernetes across different environments.

## 📂 Available Guides

### ☁️ Cloud Provider Specific Guides

- **[AWS EFS Guide](./AWS-EFS-GUIDE.md)** - Amazon Elastic File System setup for shared storage
- **[AWS EBS Guide](./AWS-EBS-GUIDE.md)** - Amazon Elastic Block Store configuration for high-performance storage
- **[Azure AKS Guide](./AZURE-AKS-GUIDE.md)** - Azure Disk and Azure Files provisioning in AKS
- **[Google GKE Guide](./GOOGLE-GKE-GUIDE.md)** - Google Persistent Disk and Filestore setup
- **[Local Provisioning Guide](./LOCAL-PROVISIONING-GUIDE.md)** - Local Path Provisioner and NFS for on-premises

## 🏗️ Overview

Dynamic provisioning allows storage volumes to be created on-demand when PersistentVolumeClaim (PVC) objects are created. This eliminates the need to pre-provision storage and provides better resource utilization.

## 🎯 Quick Selection Guide

| Environment | Use Case | Recommended Guide |
|-------------|----------|-------------------|
| **AWS EKS** | High-performance databases | [AWS EBS Guide](./AWS-EBS-GUIDE.md) |
| **AWS EKS** | Shared file storage | [AWS EFS Guide](./AWS-EFS-GUIDE.md) |
| **Azure AKS** | Enterprise applications | [Azure AKS Guide](./AZURE-AKS-GUIDE.md) |
| **Google GKE** | High-performance workloads | [Google GKE Guide](./GOOGLE-GKE-GUIDE.md) |
| **Local/On-Prem** | Development/Testing | [Local Provisioning Guide](./LOCAL-PROVISIONING-GUIDE.md) |

## 📋 Common Prerequisites

Before starting with any guide, ensure you have:
- A running Kubernetes cluster (v1.32+ recommended)
- `kubectl` configured and connected to your cluster
- Appropriate cloud CLI tools installed and configured
- Required IAM permissions for storage operations

---

## � AWS EKS - Dynamic Provisioning Examples

### Prerequisites for AWS EKS

Before implementing dynamic provisioning, ensure you have:

1. **EKS cluster with proper IAM roles**
2. **CSI drivers installed**
3. **Proper security groups and subnets**

### 📁 AWS EFS Dynamic Provisioning

#### Step 1: Install EFS CSI Driver

```bash
# Add the EFS CSI driver using AWS Load Balancer Controller or EKS add-on
kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.7"

# Or use EKS add-on (recommended)
aws eks create-addon \
  --cluster-name your-cluster-name \
  --addon-name aws-efs-csi-driver \
  --resolve-conflicts OVERWRITE
```

#### Step 2: Create EFS File System (if not exists)

```bash
# Create EFS file system
aws efs create-file-system \
  --performance-mode generalPurpose \
  --throughput-mode provisioned \
  --provisioned-throughput-in-mibps 100 \
  --tags Key=Name,Value=eks-efs-dynamic

# Get File System ID (save this)
aws efs describe-file-systems --query 'FileSystems[0].FileSystemId' --output text
```

#### Step 3: Create EFS Mount Targets

```bash
# Get subnet IDs from your EKS cluster
aws eks describe-cluster --name your-cluster-name \
  --query 'cluster.resourcesVpcConfig.subnetIds' --output text

# Create mount targets for each subnet
aws efs create-mount-target \
  --file-system-id fs-xxxxxxxxx \
  --subnet-id subnet-xxxxxxxxx \
  --security-groups sg-xxxxxxxxx
```

#### Step 4: Deploy EFS StorageClass and Resources

**efs-dynamic-storageclass.yaml**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-05ff8378afea6c10c     # Replace with your EFS File System ID
  directoryPerms: "0755"                 # Directory permissions
  gidRangeStart: "1000"                  # GID range for access points
  gidRangeEnd: "2000"
  basePath: "/dynamic_provisioning"     # Base directory in EFS
  subPathPattern: "${.PVC.namespace}/${.PVC.name}"
  ensureUniqueDirectory: "true"
  reuseAccessPoint: "false"
allowVolumeExpansion: true
volumeBindingMode: Immediate
```

**efs-pvc.yaml**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: efs-claim
  namespace: default
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: 5Gi   # Symbolic size for EFS
```

**efs-deployment.yaml**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: efs-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: efs-app
  template:
    metadata:
      labels:
        app: efs-app
    spec:
      containers:
      - name: app
        image: busybox:1.35
        command: ["/bin/sh"]
        args: ["-c", "while true; do echo $(date) >> /data/log.txt; sleep 30; done"]
        volumeMounts:
        - name: persistent-storage
          mountPath: /data
      volumes:
      - name: persistent-storage
        persistentVolumeClaim:
          claimName: efs-claim
```

### � AWS EBS Dynamic Provisioning

#### Step 1: Install EBS CSI Driver

```bash
# Install EBS CSI driver
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.25"

# Or use EKS add-on (recommended)
aws eks create-addon \
  --cluster-name your-cluster-name \
  --addon-name aws-ebs-csi-driver \
  --resolve-conflicts OVERWRITE
```

#### Step 2: Deploy EBS StorageClass and Resources

**ebs-dynamic-storageclass.yaml**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc
provisioner: ebs.csi.aws.com
parameters:
  type: gp3                    # EBS volume type (gp2, gp3, io1, io2)
  fsType: ext4                 # File system type
  encrypted: "true"            # Encrypt volumes
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

**ebs-pvc.yaml**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ebs-claim
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ebs-sc
  resources:
    requests:
      storage: 10Gi
```

**ebs-pod.yaml**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ebs-app
spec:
  containers:
  - name: app
    image: nginx:1.25
    volumeMounts:
    - name: persistent-storage
      mountPath: /usr/share/nginx/html
  volumes:
  - name: persistent-storage
    persistentVolumeClaim:
      claimName: ebs-claim
```

---

## ☁️ Azure AKS - Dynamic Provisioning Examples

### Azure Disk (Block Storage)

**azure-disk-storageclass.yaml**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-disk-sc
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_LRS      # Standard_LRS, Premium_LRS, StandardSSD_LRS
  cachingmode: ReadOnly     # None, ReadOnly, ReadWrite
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

### Azure Files (Network File System)

**azure-files-storageclass.yaml**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-files-sc
provisioner: file.csi.azure.com
parameters:
  skuName: Standard_LRS
  storageAccount: mystorageaccount  # Optional: specify storage account
allowVolumeExpansion: true
volumeBindingMode: Immediate
```

---

## 🌟 Google GKE - Dynamic Provisioning

**gce-pd-storageclass.yaml**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd           # pd-standard, pd-ssd, pd-balanced
  replication-type: regional-pd  # none, regional-pd
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

---

## 🏠 Local/On-Premises Dynamic Provisioning

### NFS Dynamic Provisioning

#### Step 1: Install NFS Subdir External Provisioner

```bash
# Add Helm repository
helm repo add nfs-subdir-external-provisioner \
  https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

# Update repository
helm repo update

# Install NFS provisioner
helm install nfs-subdir-external-provisioner \
  nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=your-nfs-server-ip \
  --set nfs.path=/path/to/nfs/share
```

#### Step 2: Create NFS StorageClass

**nfs-storageclass.yaml**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-client
provisioner: k8s-sigs.io/nfs-subdir-external-provisioner
parameters:
  pathPattern: "${.PVC.namespace}/${.PVC.name}"
  onDelete: delete  # delete, retain
allowVolumeExpansion: true
volumeBindingMode: Immediate
```

### Local Path Dynamic Provisioning

#### Step 1: Install Local Path Provisioner

```bash
# Install local path provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.28/deploy/local-path-storage.yaml
```

#### Step 2: Create Local Path StorageClass

**local-path-storageclass.yaml**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
provisioner: rancher.io/local-path
parameters:
  nodePath: /opt/local-path-provisioner  # Path on worker nodes
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

---

## 🧪 Complete Testing Example

Let's create a comprehensive test that works with any StorageClass:

**dynamic-provisioning-test.yaml**
```yaml
# Test PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce  # Change to ReadWriteMany for shared storage
  storageClassName: efs-sc  # Change to your StorageClass name
  resources:
    requests:
      storage: 1Gi
---
# Test Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: storage-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: storage-test
  template:
    metadata:
      labels:
        app: storage-test
    spec:
      containers:
      - name: test-container
        image: busybox:1.35
        command: ["/bin/sh"]
        args: ["-c", "while true; do echo $(date) >> /data/test.log; sleep 10; done"]
        volumeMounts:
        - name: test-volume
          mountPath: /data
      volumes:
      - name: test-volume
        persistentVolumeClaim:
          claimName: test-pvc
---
# Service for testing (optional)
apiVersion: v1
kind: Service
metadata:
  name: storage-test-svc
spec:
  selector:
    app: storage-test
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
```

---

## � Validation and Testing Steps

### 1. Deploy Resources
```bash
# Apply the StorageClass
kubectl apply -f your-storageclass.yaml

# Apply the test manifests
kubectl apply -f dynamic-provisioning-test.yaml
```

### 2. Check Resource Status
```bash
# Check StorageClass
kubectl get storageclass

# Check PVC status
kubectl get pvc

# Check PV (should be automatically created)
kubectl get pv

# Check Pod status
kubectl get pods

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp
```

### 3. Validate Data Persistence
```bash
# Get Pod name
POD_NAME=$(kubectl get pods -l app=storage-test -o jsonpath='{.items[0].metadata.name}')

# Check the mounted volume
kubectl exec $POD_NAME -- ls -la /data

# View the log file being written
kubectl exec $POD_NAME -- tail -f /data/test.log

# Create a test file
kubectl exec $POD_NAME -- touch /data/persistence-test.txt

# Delete the pod (deployment will recreate it)
kubectl delete pod $POD_NAME

# Wait for new pod and check if file still exists
kubectl wait --for=condition=ready pod -l app=storage-test
NEW_POD=$(kubectl get pods -l app=storage-test -o jsonpath='{.items[0].metadata.name}')
kubectl exec $NEW_POD -- ls -la /data/persistence-test.txt
```

---

## 🔧 Troubleshooting Dynamic Provisioning

### Common Issues and Solutions

#### 1. PVC Stuck in Pending State
```bash
# Check PVC events
kubectl describe pvc your-pvc-name

# Check StorageClass
kubectl get storageclass

# Check provisioner pods
kubectl get pods -n kube-system | grep -E "(csi|provisioner)"
```

**Common Causes:**
- CSI driver not installed or running
- Incorrect StorageClass configuration
- Insufficient permissions (RBAC/IAM)
- Network connectivity issues

#### 2. Pod Cannot Mount Volume
```bash
# Check pod events
kubectl describe pod your-pod-name

# Check node CSI driver logs
kubectl logs -n kube-system -l app=ebs-csi-node  # for EBS
kubectl logs -n kube-system -l app=efs-csi-node  # for EFS
```

**Common Causes:**
- CSI driver node component not running
- Security group/firewall blocking access
- Incorrect volume parameters

#### 3. Volume Mount Permission Issues
```bash
# Check volume permissions inside pod
kubectl exec your-pod-name -- ls -la /mount/path

# Fix permissions (if needed)
kubectl exec your-pod-name -- chown -R 1000:1000 /mount/path
```

#### 4. AWS-Specific Issues

**EFS Mount Issues:**
```bash
# Check EFS mount targets
aws efs describe-mount-targets --file-system-id fs-xxxxxxxxx

# Check security groups
aws ec2 describe-security-groups --group-ids sg-xxxxxxxxx

# Test EFS connectivity from worker node
sudo mount -t efs fs-xxxxxxxxx:/ /mnt/efs-test
```

**EBS Volume Issues:**
```bash
# Check AWS EBS volume status
aws ec2 describe-volumes --filters "Name=tag:kubernetes.io/created-for/pvc/name,Values=your-pvc-name"

# Check IAM permissions for EBS CSI driver
kubectl get serviceaccount ebs-csi-controller-sa -n kube-system -o yaml
```

---

## 🛡️ Security Best Practices

### 1. Use Encryption
```yaml
# EBS with encryption
parameters:
  encrypted: "true"
  kmsKeyId: "arn:aws:kms:region:account:key/key-id"

# Azure Disk with encryption
parameters:
  diskEncryptionType: "EncryptionAtRestWithCustomerKey"
```

### 2. Set Resource Limits
```yaml
# Limit storage size in StorageClass
parameters:
  type: gp3
  maxVolumeSize: "100Gi"
```

### 3. Use Pod Security Standards
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
  containers:
  - name: app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
```

---

## 📊 Performance Tuning

### 1. Choose Appropriate Volume Types

**AWS EBS:**
- `gp3`: General purpose, cost-effective
- `io2`: High IOPS for databases
- `st1`: Throughput optimized for big data

**Azure:**
- `Standard_LRS`: Cost-effective
- `Premium_LRS`: High performance
- `UltraSSD_LRS`: Ultra-high performance

### 2. Configure Volume Binding
```yaml
# Wait for pod scheduling to optimize placement
volumeBindingMode: WaitForFirstConsumer

# Immediate binding for shared storage
volumeBindingMode: Immediate
```

---

## 🚀 Quick Start

1. **Choose your environment** from the table above
2. **Follow the specific guide** for detailed setup instructions
3. **Test your setup** using the validation steps in each guide
4. **Monitor and troubleshoot** using the provided tools and commands

## 🔍 What's in Each Guide

Each guide contains:
- ✅ **Prerequisites** - What you need before starting
- 🔧 **Step-by-step setup** - Detailed installation and configuration
- 📦 **YAML examples** - Ready-to-use configurations
- 🧪 **Testing procedures** - Validation and performance testing
- 📊 **Monitoring tips** - How to monitor your storage
- 🔧 **Troubleshooting** - Common issues and solutions
- 🧹 **Cleanup procedures** - How to safely remove resources

## 📊 Storage Comparison

| Feature | AWS EBS | AWS EFS | Azure Disk | Azure Files | GCP PD | GCP Filestore | Local Path | NFS |
|---------|---------|---------|------------|-------------|--------|---------------|------------|-----|
| **Access Mode** | RWO | RWX | RWO | RWX | RWO | RWX | RWO | RWX |
| **Performance** | High | Moderate | High | Moderate | High | High | Variable | Moderate |
| **Shared Access** | ❌ | ✅ | ❌ | ✅ | ❌ | ✅ | ❌ | ✅ |
| **Encryption** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Backup** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | Manual |

## 🔐 Security Best Practices

All guides include security considerations:
- 🔒 **Encryption at rest** - Enable storage encryption
- 🛡️ **Access control** - Proper RBAC configuration
- 🔐 **Network security** - Secure CSI driver communications
- 💾 **Backup strategy** - Regular backup procedures

## 🎓 Learning Path

1. **Start with [Local Provisioning Guide](./LOCAL-PROVISIONING-GUIDE.md)** for learning basics
2. **Move to cloud-specific guides** based on your target environment
3. **Practice with real workloads** using the provided examples
4. **Implement monitoring and backup** strategies

---

**💡 Tip**: Each guide is self-contained and can be used independently. Choose the one that matches your environment and follow the step-by-step instructions.

---

## Example Files in This Directory

This directory contains ready-to-use examples for different environments:

### 🔗 Quick Links
- **[`QUICK_REFERENCE.md`](QUICK_REFERENCE.md)** - Commands and troubleshooting cheat sheet
- **[`test-dynamic-provisioning.sh`](test-dynamic-provisioning.sh)** - Automated testing script

### 📄 YAML Examples
- **[`aws-efs-example.yaml`](aws-efs-example.yaml)** - Complete EFS setup with multi-pod access
- **[`aws-ebs-example.yaml`](aws-ebs-example.yaml)** - EBS volume with encryption
- **[`local-path-example.yaml`](local-path-example.yaml)** - Local development setup

### 🚀 Quick Start
```bash
# Test your environment
chmod +x test-dynamic-provisioning.sh
./test-dynamic-provisioning.sh

# Deploy AWS EFS example (update file system ID first)
kubectl apply -f aws-efs-example.yaml

# Deploy local path example
kubectl apply -f local-path-example.yaml
```

---

**Last Updated**: December 2024  
**Kubernetes Version**: 1.32+  
**Status**: ✅ Production Ready
