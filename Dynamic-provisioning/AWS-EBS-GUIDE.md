# 💿 AWS EKS Dynamic Provisioning with EBS

This guide shows how to set up dynamic provisioning using Amazon EBS (Elastic Block Store) in EKS clusters.

## 📋 Prerequisites

- EKS cluster running
- `kubectl` configured for your cluster
- AWS CLI configured with appropriate permissions
- IAM permissions for EBS operations

---

## 🔧 Step 1: Install EBS CSI Driver

### Option A: Using EKS Add-on (Recommended)
```bash
# Install EBS CSI driver as EKS add-on
aws eks create-addon \
  --cluster-name YOUR_CLUSTER_NAME \
  --addon-name aws-ebs-csi-driver \
  --resolve-conflicts OVERWRITE

# Check addon status
aws eks describe-addon \
  --cluster-name YOUR_CLUSTER_NAME \
  --addon-name aws-ebs-csi-driver
```

### Option B: Manual Installation
```bash
# Install using kubectl
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.25"

# Verify installation
kubectl get pods -n kube-system -l app=ebs-csi-node
kubectl get pods -n kube-system -l app=ebs-csi-controller
```

---

## 📦 Step 2: Deploy EBS Resources

Save the following as `ebs-dynamic-setup.yaml`:

```yaml
# GP3 StorageClass with encryption
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-gp3-encrypted
provisioner: ebs.csi.aws.com
parameters:
  type: gp3                    # Volume type (gp2, gp3, io1, io2, st1, sc1)
  fsType: ext4                 # File system type
  encrypted: "true"            # Enable encryption
  iops: "3000"                # IOPS for gp3 volumes (3000-16000)
  throughput: "125"           # Throughput in MiB/s for gp3 (125-1000)
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete

---
# High Performance StorageClass for databases
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-io2-high-perf
provisioner: ebs.csi.aws.com
parameters:
  type: io2
  fsType: ext4
  encrypted: "true"
  iops: "10000"               # High IOPS for databases
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Retain          # Keep data after PVC deletion

---
# Standard PVC for web applications
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: webapp-storage
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ebs-gp3-encrypted
  resources:
    requests:
      storage: 20Gi

---
# Database PVC with high performance
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: database-storage
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ebs-io2-high-perf
  resources:
    requests:
      storage: 100Gi

---
# Web application deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
        volumeMounts:
        - name: webapp-storage
          mountPath: /usr/share/nginx/html
        - name: logs
          mountPath: /var/log/nginx
      volumes:
      - name: webapp-storage
        persistentVolumeClaim:
          claimName: webapp-storage
      - name: logs
        emptyDir: {}

---
# Database StatefulSet
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql-db
spec:
  serviceName: mysql
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "rootpassword123"
        - name: MYSQL_DATABASE
          value: "testdb"
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-data
        persistentVolumeClaim:
          claimName: database-storage

---
# Service for web app
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
  type: NodePort

---
# Service for MySQL
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  selector:
    app: mysql
  ports:
  - port: 3306
    targetPort: 3306
  type: ClusterIP
```

---

## 🚀 Step 3: Deploy and Test

### Deploy Resources
```bash
# Apply the configuration
kubectl apply -f ebs-dynamic-setup.yaml
```

### Verify Deployment
```bash
# Check StorageClasses
kubectl get storageclass

# Check PVC status
kubectl get pvc

# Check if PVs were created automatically
kubectl get pv

# Check deployments
kubectl get deployments
kubectl get statefulsets
```

### Test Web Application
```bash
# Get webapp service details
kubectl get service webapp-service

# Port forward to test locally
kubectl port-forward service/webapp-service 8080:80

# In another terminal, test the webapp
curl http://localhost:8080
```

---

## 🔍 Validation Steps

### 1. Test Volume Persistence
```bash
# Add content to webapp
WEBAPP_POD=$(kubectl get pods -l app=webapp -o jsonpath='{.items[0].metadata.name}')
kubectl exec $WEBAPP_POD -- sh -c 'echo "<h1>Persistent Storage Test</h1>" > /usr/share/nginx/html/test.html'

# Test the content
curl http://localhost:8080/test.html

# Delete and recreate pod
kubectl delete pod $WEBAPP_POD
kubectl wait --for=condition=ready pod -l app=webapp --timeout=300s

# Verify content persists
curl http://localhost:8080/test.html
```

### 2. Test Database Persistence
```bash
# Connect to MySQL and create test data
MYSQL_POD=$(kubectl get pods -l app=mysql -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $MYSQL_POD -- mysql -u root -prootpassword123 -e "
CREATE TABLE testdb.users (id INT PRIMARY KEY, name VARCHAR(50));
INSERT INTO testdb.users VALUES (1, 'John Doe');
SELECT * FROM testdb.users;"

# Delete StatefulSet pod
kubectl delete pod $MYSQL_POD

# Wait for pod recreation and verify data
kubectl wait --for=condition=ready pod -l app=mysql --timeout=300s
MYSQL_POD=$(kubectl get pods -l app=mysql -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $MYSQL_POD -- mysql -u root -prootpassword123 -e "SELECT * FROM testdb.users;"
```

### 3. Test Volume Expansion
```bash
# Expand the webapp volume
kubectl patch pvc webapp-storage -p '{"spec":{"resources":{"requests":{"storage":"30Gi"}}}}'

# Check expansion status
kubectl get pvc webapp-storage
kubectl describe pvc webapp-storage

# Verify new size in pod
kubectl exec $WEBAPP_POD -- df -h /usr/share/nginx/html
```

---

## 📊 Monitoring and Performance

### Check Volume Performance
```bash
# Check IOPS and throughput
kubectl exec $WEBAPP_POD -- iostat -x 1 5

# Test write performance
kubectl exec $WEBAPP_POD -- dd if=/dev/zero of=/usr/share/nginx/html/testfile bs=1M count=100 oflag=direct

# Test read performance
kubectl exec $WEBAPP_POD -- dd if=/usr/share/nginx/html/testfile of=/dev/null bs=1M iflag=direct
```

### AWS Console Monitoring
```bash
# Get volume IDs
aws ec2 describe-volumes --filters "Name=tag:kubernetes.io/created-for/pvc/name,Values=webapp-storage"

# Monitor CloudWatch metrics for EBS volumes
aws cloudwatch get-metric-statistics \
  --namespace AWS/EBS \
  --metric-name VolumeReadOps \
  --dimensions Name=VolumeId,Value=vol-xxxxxxxxx \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T01:00:00Z \
  --period 300 \
  --statistics Sum
```

---

## 🔧 Advanced Configuration

### Custom StorageClass for specific workloads
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-logs-optimized
provisioner: ebs.csi.aws.com
parameters:
  type: st1                    # Throughput optimized for logs
  fsType: ext4
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

### Volume Snapshots
```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: ebs-snapshot-class
driver: ebs.csi.aws.com
deletionPolicy: Delete

---
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: webapp-backup
spec:
  volumeSnapshotClassName: ebs-snapshot-class
  source:
    persistentVolumeClaimName: webapp-storage
```

---

## 🧹 Cleanup

```bash
# Delete all resources
kubectl delete -f ebs-dynamic-setup.yaml

# Check that PVs are deleted (except those with Retain policy)
kubectl get pv
```

---

## 🔧 Troubleshooting

### Common Issues

1. **PVC stuck in Pending**
   ```bash
   kubectl describe pvc webapp-storage
   # Check events for specific error messages
   ```

2. **Pod stuck in ContainerCreating**
   ```bash
   kubectl describe pod POD_NAME
   # Look for volume attachment errors
   ```

3. **Performance issues**
   ```bash
   # Check if volume is in the same AZ as the node
   kubectl get nodes --show-labels
   kubectl get pv -o wide
   ```

4. **IAM permission errors**
   ```bash
   # Check EBS CSI driver logs
   kubectl logs -n kube-system -l app=ebs-csi-controller
   ```

---

**Use Case**: Databases, file systems, single-pod storage
**Best For**: Applications requiring ReadWriteOnce with high performance
