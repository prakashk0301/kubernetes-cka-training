# 🔷 Azure AKS Dynamic Provisioning

This guide shows how to set up dynamic provisioning using Azure Disk and Azure Files in AKS clusters.

## 📋 Prerequisites

- AKS cluster running
- `kubectl` configured for your cluster
- Azure CLI configured with appropriate permissions
- Managed Identity or Service Principal with storage permissions

---

## 🔧 Step 1: Verify CSI Drivers

AKS comes with CSI drivers pre-installed. Verify they're running:

```bash
# Check Azure Disk CSI driver
kubectl get pods -n kube-system | grep disk

# Check Azure Files CSI driver
kubectl get pods -n kube-system | grep file

# Check available StorageClasses
kubectl get storageclass
```

---

## 📦 Step 2: Deploy Azure Disk Resources

Save the following as `azure-disk-setup.yaml`:

```yaml
# Premium SSD StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-disk-premium
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_LRS        # Standard_LRS, Premium_LRS, StandardSSD_LRS, UltraSSD_LRS
  cachingmode: ReadOnly       # None, ReadOnly, ReadWrite
  fsType: ext4
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true

---
# Standard SSD StorageClass for cost optimization
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-disk-standard
provisioner: disk.csi.azure.com
parameters:
  skuName: StandardSSD_LRS
  cachingmode: ReadOnly
  fsType: ext4
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true

---
# PVC for premium storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: premium-disk-claim
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: azure-disk-premium
  resources:
    requests:
      storage: 50Gi

---
# PVC for standard storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: standard-disk-claim
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: azure-disk-standard
  resources:
    requests:
      storage: 20Gi

---
# PostgreSQL database with premium storage
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres-db
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        env:
        - name: POSTGRES_DB
          value: "testdb"
        - name: POSTGRES_USER
          value: "admin"
        - name: POSTGRES_PASSWORD
          value: "password123"
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-data
        persistentVolumeClaim:
          claimName: premium-disk-claim

---
# Web application with standard storage
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
        volumeMounts:
        - name: web-content
          mountPath: /usr/share/nginx/html
      volumes:
      - name: web-content
        persistentVolumeClaim:
          claimName: standard-disk-claim

---
# Services
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
  type: ClusterIP

---
apiVersion: v1
kind: Service
metadata:
  name: web-app-service
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
```

---

## 📂 Step 3: Deploy Azure Files Resources

Save the following as `azure-files-setup.yaml`:

```yaml
# Azure Files StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-files-shared
provisioner: file.csi.azure.com
parameters:
  skuName: Standard_LRS       # Standard_LRS, Premium_LRS
  storageAccount: ""          # Optional: specify storage account
  resourceGroup: ""           # Optional: specify resource group
allowVolumeExpansion: true
volumeBindingMode: Immediate
reclaimPolicy: Delete

---
# Shared storage PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-files-claim
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: azure-files-shared
  resources:
    requests:
      storage: 10Gi

---
# Multi-writer deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: file-writer
spec:
  replicas: 3
  selector:
    matchLabels:
      app: file-writer
  template:
    metadata:
      labels:
        app: file-writer
    spec:
      containers:
      - name: writer
        image: busybox:1.35
        command: ["/bin/sh"]
        args: ["-c", "while true; do echo $(hostname): $(date) >> /shared/logs/activity.log; sleep 30; done"]
        volumeMounts:
        - name: shared-storage
          mountPath: /shared
      volumes:
      - name: shared-storage
        persistentVolumeClaim:
          claimName: shared-files-claim

---
# Log reader pod
apiVersion: v1
kind: Pod
metadata:
  name: log-reader
spec:
  containers:
  - name: reader
    image: busybox:1.35
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo 'Recent activity:'; tail -10 /shared/logs/activity.log; sleep 60; done"]
    volumeMounts:
    - name: shared-storage
      mountPath: /shared
  volumes:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: shared-files-claim
```

---

## 🚀 Step 4: Deploy and Test

### Deploy Azure Disk Resources
```bash
# Apply disk configuration
kubectl apply -f azure-disk-setup.yaml

# Check resources
kubectl get storageclass
kubectl get pvc
kubectl get pods
```

### Deploy Azure Files Resources
```bash
# Apply files configuration
kubectl apply -f azure-files-setup.yaml

# Check shared storage
kubectl get pvc shared-files-claim
kubectl get pods -l app=file-writer
```

---

## 🔍 Validation Steps

### 1. Test Azure Disk Persistence
```bash
# Connect to PostgreSQL and create test data
POSTGRES_POD=$(kubectl get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POSTGRES_POD -- psql -U admin -d testdb -c "
CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(50));
INSERT INTO users (name) VALUES ('Alice'), ('Bob');
SELECT * FROM users;"

# Delete pod and verify data persistence
kubectl delete pod $POSTGRES_POD
kubectl wait --for=condition=ready pod -l app=postgres --timeout=300s

# Verify data still exists
POSTGRES_POD=$(kubectl get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POSTGRES_POD -- psql -U admin -d testdb -c "SELECT * FROM users;"
```

### 2. Test Azure Files Shared Access
```bash
# Check shared file access across multiple pods
kubectl logs -l app=file-writer --tail=20

# View aggregated logs
kubectl logs log-reader --tail=20

# Create shared directory structure
kubectl exec log-reader -- mkdir -p /shared/uploads /shared/configs

# Test file sharing between pods
kubectl exec log-reader -- touch /shared/uploads/test-file.txt
WRITER_POD=$(kubectl get pods -l app=file-writer -o jsonpath='{.items[0].metadata.name}')
kubectl exec $WRITER_POD -- ls -la /shared/uploads/
```

### 3. Test Volume Expansion
```bash
# Expand Azure Disk volume
kubectl patch pvc premium-disk-claim -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'

# Check expansion status
kubectl get pvc premium-disk-claim
kubectl describe pvc premium-disk-claim

# Verify new size
kubectl exec $POSTGRES_POD -- df -h /var/lib/postgresql/data
```

---

## 📊 Monitoring and Performance

### Check Storage Performance
```bash
# Test disk performance in PostgreSQL pod
kubectl exec $POSTGRES_POD -- sh -c "
cd /var/lib/postgresql/data
# Write test
dd if=/dev/zero of=testfile bs=1M count=100 oflag=direct
# Read test
dd if=testfile of=/dev/null bs=1M iflag=direct
rm testfile"

# Monitor Azure Files performance
kubectl exec log-reader -- sh -c "
# Create multiple files simultaneously
for i in \$(seq 1 10); do
  dd if=/dev/zero of=/shared/test\$i.dat bs=1M count=10 &
done
wait"
```

### Azure Portal Monitoring
```bash
# Get resource information
az aks show --resource-group YOUR_RG --name YOUR_CLUSTER --query nodeResourceGroup -o tsv

# List managed disks
az disk list --resource-group MC_YOUR_RG_YOUR_CLUSTER_LOCATION --output table

# List storage accounts for Azure Files
az storage account list --resource-group MC_YOUR_RG_YOUR_CLUSTER_LOCATION --output table
```

---

## 🔧 Advanced Configuration

### Ultra SSD for high performance
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ultra-ssd
provisioner: disk.csi.azure.com
parameters:
  skuName: UltraSSD_LRS
  cachingmode: None
  diskIOPSReadWrite: "2000"
  diskMBpsReadWrite: "320"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

### Premium Azure Files
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-files-premium
provisioner: file.csi.azure.com
parameters:
  skuName: Premium_LRS
  protocol: SMB                # SMB or NFS
volumeBindingMode: Immediate
allowVolumeExpansion: true
```

---

## 🧹 Cleanup

```bash
# Delete all resources
kubectl delete -f azure-disk-setup.yaml
kubectl delete -f azure-files-setup.yaml

# Check that PVs are deleted
kubectl get pv
```

---

## 🔧 Troubleshooting

### Common Issues

1. **PVC stuck in Pending**
   ```bash
   kubectl describe pvc YOUR_PVC_NAME
   # Check for quota or permission issues
   ```

2. **Pod stuck in ContainerCreating**
   ```bash
   kubectl describe pod POD_NAME
   # Look for disk attachment errors
   ```

3. **Azure Files mount issues**
   ```bash
   # Check Azure Files CSI driver logs
   kubectl logs -n kube-system -l app=azure-file-csi-driver
   ```

4. **Performance issues**
   ```bash
   # Check if using appropriate storage tier
   kubectl get storageclass -o wide
   ```

### Azure CLI Troubleshooting
```bash
# Check AKS cluster status
az aks show --resource-group YOUR_RG --name YOUR_CLUSTER

# Check managed identity permissions
az aks show --resource-group YOUR_RG --name YOUR_CLUSTER --query identity

# List available VM sizes for Ultra SSD
az vm list-sizes --location YOUR_LOCATION --query "[?contains(name, 's')]"
```

---

**Use Case**: Enterprise applications, multi-tenant systems, shared workspaces
**Best For**: Azure-native applications requiring scalable storage
