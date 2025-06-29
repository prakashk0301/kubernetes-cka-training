# 🚀 AWS EKS Dynamic Provisioning with EFS

This guide shows how to set up dynamic provisioning using Amazon EFS (Elastic File System) in EKS clusters.

## 📋 Prerequisites

- EKS cluster running
- `kubectl` configured for your cluster
- AWS CLI configured with appropriate permissions
- IAM permissions for EFS operations

---

## 🔧 Step 1: Install EFS CSI Driver

### Option A: Using EKS Add-on (Recommended)
```bash
# Install EFS CSI driver as EKS add-on
aws eks create-addon \
  --cluster-name YOUR_CLUSTER_NAME \
  --addon-name aws-efs-csi-driver \
  --resolve-conflicts OVERWRITE

# Check addon status
aws eks describe-addon \
  --cluster-name YOUR_CLUSTER_NAME \
  --addon-name aws-efs-csi-driver
```

### Option B: Manual Installation
```bash
# Install using kubectl
kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.7"

# Verify installation
kubectl get pods -n kube-system -l app=efs-csi-node
kubectl get pods -n kube-system -l app=efs-csi-controller
```

---

## 🗂️ Step 2: Create EFS File System

### Create EFS File System
```bash
# Create EFS file system
EFS_ID=$(aws efs create-file-system \
  --performance-mode generalPurpose \
  --throughput-mode provisioned \
  --provisioned-throughput-in-mibps 100 \
  --tags Key=Name,Value=eks-efs-dynamic \
  --query 'FileSystemId' --output text)

echo "EFS File System ID: $EFS_ID"
```

### Create Mount Targets
```bash
# Get your cluster's VPC and subnets
VPC_ID=$(aws eks describe-cluster \
  --name YOUR_CLUSTER_NAME \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)

SUBNET_IDS=$(aws eks describe-cluster \
  --name YOUR_CLUSTER_NAME \
  --query 'cluster.resourcesVpcConfig.subnetIds' --output text)

# Get security group for EFS
SECURITY_GROUP=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=*eks-cluster-sg*" \
  --query 'SecurityGroups[0].GroupId' --output text)

# Create mount targets for each subnet
for subnet in $SUBNET_IDS; do
  echo "Creating mount target in subnet: $subnet"
  aws efs create-mount-target \
    --file-system-id $EFS_ID \
    --subnet-id $subnet \
    --security-groups $SECURITY_GROUP
done
```

### Configure Security Group
```bash
# Allow NFS traffic (port 2049)
aws ec2 authorize-security-group-ingress \
  --group-id $SECURITY_GROUP \
  --protocol tcp \
  --port 2049 \
  --source-group $SECURITY_GROUP
```

---

## 📦 Step 3: Deploy EFS Resources

Save the following as `efs-dynamic-setup.yaml`:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-XXXXXXXXX  # Replace with your EFS File System ID
  directoryPerms: "0755"
  gidRangeStart: "1000"
  gidRangeEnd: "2000"
  basePath: "/dynamic_provisioning"
  subPathPattern: "${.PVC.namespace}/${.PVC.name}"
  ensureUniqueDirectory: "true"
  reuseAccessPoint: "false"
allowVolumeExpansion: true
volumeBindingMode: Immediate

---
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
      storage: 5Gi

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: efs-writer
spec:
  replicas: 2
  selector:
    matchLabels:
      app: efs-writer
  template:
    metadata:
      labels:
        app: efs-writer
    spec:
      containers:
      - name: writer
        image: busybox:1.35
        command: ["/bin/sh"]
        args: ["-c", "while true; do echo $(hostname): $(date) >> /shared/data.log; sleep 30; done"]
        volumeMounts:
        - name: efs-storage
          mountPath: /shared
      volumes:
      - name: efs-storage
        persistentVolumeClaim:
          claimName: efs-claim

---
apiVersion: v1
kind: Pod
metadata:
  name: efs-reader
spec:
  containers:
  - name: reader
    image: busybox:1.35
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo 'Reading shared data:'; tail -10 /shared/data.log; sleep 60; done"]
    volumeMounts:
    - name: efs-storage
      mountPath: /shared
  volumes:
  - name: efs-storage
    persistentVolumeClaim:
      claimName: efs-claim
```

---

## 🚀 Step 4: Deploy and Test

### Deploy Resources
```bash
# Update the EFS File System ID in the YAML file
sed -i "s/fs-XXXXXXXXX/$EFS_ID/g" efs-dynamic-setup.yaml

# Apply the configuration
kubectl apply -f efs-dynamic-setup.yaml
```

### Verify Deployment
```bash
# Check StorageClass
kubectl get storageclass efs-sc

# Check PVC status
kubectl get pvc efs-claim

# Check if PV was created automatically
kubectl get pv

# Check pods
kubectl get pods -l app=efs-writer
kubectl get pod efs-reader
```

### Test Shared Storage
```bash
# Check logs from writer pods
kubectl logs -l app=efs-writer

# Check reader pod output
kubectl logs efs-reader

# Exec into reader pod and check shared file
kubectl exec efs-reader -- tail -f /shared/data.log
```

---

## 🔍 Validation Steps

### 1. Test Data Persistence
```bash
# Create a test file from one pod
kubectl exec -it efs-reader -- touch /shared/test-persistence.txt

# Verify from writer pod
WRITER_POD=$(kubectl get pods -l app=efs-writer -o jsonpath='{.items[0].metadata.name}')
kubectl exec $WRITER_POD -- ls -la /shared/test-persistence.txt
```

### 2. Test Multi-Pod Access
```bash
# Scale up writers
kubectl scale deployment efs-writer --replicas=3

# Check all pods can access shared storage
kubectl get pods -l app=efs-writer
for pod in $(kubectl get pods -l app=efs-writer -o jsonpath='{.items[*].metadata.name}'); do
  echo "Checking pod: $pod"
  kubectl exec $pod -- ls -la /shared/
done
```

---

## 🧹 Cleanup

```bash
# Delete Kubernetes resources
kubectl delete -f efs-dynamic-setup.yaml

# Delete EFS file system (optional)
aws efs delete-file-system --file-system-id $EFS_ID
```

---

## 🔧 Troubleshooting

### Common Issues

1. **Pods stuck in ContainerCreating**
   ```bash
   kubectl describe pod POD_NAME
   # Check events for EFS mount errors
   ```

2. **Permission denied errors**
   ```bash
   # Check EFS access point permissions
   aws efs describe-access-points --file-system-id $EFS_ID
   ```

3. **Security group issues**
   ```bash
   # Verify NFS port 2049 is open
   aws ec2 describe-security-groups --group-ids $SECURITY_GROUP
   ```

---

**Use Case**: Multi-pod shared storage, content management systems, shared logs
**Best For**: Applications requiring ReadWriteMany access mode
