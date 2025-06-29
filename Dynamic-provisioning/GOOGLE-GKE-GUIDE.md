# 🔵 Google GKE Dynamic Provisioning

This guide demonstrates dynamic provisioning using Google Persistent Disk and Google Cloud Filestore in GKE clusters.

## 📋 Prerequisites

- GKE cluster running
- `kubectl` configured for your cluster
- `gcloud` CLI authenticated with appropriate permissions
- Service account with storage permissions

---

## 🔧 Step 1: Verify CSI Drivers

GKE includes CSI drivers by default. Verify they're operational:

```bash
# Check GCE Persistent Disk CSI driver
kubectl get pods -n kube-system | grep gce-pd

# Check available StorageClasses
kubectl get storageclass

# Check CSI driver version
kubectl get csidriver
```

---

## 📦 Step 2: Deploy Google Persistent Disk Resources

Save the following as `gke-disk-setup.yaml`:

```yaml
# High-performance SSD StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd                   # pd-standard, pd-ssd, pd-extreme
  replication-type: regional-pd   # none, regional-pd
  zones: us-central1-a,us-central1-b
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete

---
# Balanced persistent disk for general use
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: balanced-disk
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-balanced
  replication-type: none
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete

---
# Extreme performance disk
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: extreme-disk
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-extreme
  provisioned-iops-on-create: "10000"
  provisioned-throughput-on-create: "1200Mi"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete

---
# Fast SSD PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fast-ssd-claim
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 100Gi

---
# Balanced PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: balanced-claim
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: balanced-disk
  resources:
    requests:
      storage: 50Gi

---
# MongoDB with fast SSD storage
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
spec:
  serviceName: mongodb
  replicas: 1
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      containers:
      - name: mongodb
        image: mongo:7.0
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          value: "admin"
        - name: MONGO_INITDB_ROOT_PASSWORD
          value: "password123"
        ports:
        - containerPort: 27017
        volumeMounts:
        - name: mongodb-data
          mountPath: /data/db
      volumes:
      - name: mongodb-data
        persistentVolumeClaim:
          claimName: fast-ssd-claim

---
# Redis cache with balanced storage
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-cache
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis-cache
  template:
    metadata:
      labels:
        app: redis-cache
    spec:
      containers:
      - name: redis
        image: redis:7.2
        command: ["redis-server", "--appendonly", "yes"]
        ports:
        - containerPort: 6379
        volumeMounts:
        - name: redis-data
          mountPath: /data
      volumes:
      - name: redis-data
        persistentVolumeClaim:
          claimName: balanced-claim

---
# Services
apiVersion: v1
kind: Service
metadata:
  name: mongodb-service
spec:
  selector:
    app: mongodb
  ports:
  - port: 27017
    targetPort: 27017
  type: ClusterIP

---
apiVersion: v1
kind: Service
metadata:
  name: redis-service
spec:
  selector:
    app: redis-cache
  ports:
  - port: 6379
    targetPort: 6379
  type: ClusterIP
```

---

## 📂 Step 3: Deploy Google Cloud Filestore Resources

First, create a Filestore instance:

```bash
# Create Filestore instance
gcloud filestore instances create nfs-server \
    --project=YOUR_PROJECT_ID \
    --zone=us-central1-a \
    --tier=BASIC_HDD \
    --file-share=name="nfs_share",capacity=1TB \
    --network=name="default"

# Get Filestore IP address
FILESTORE_IP=$(gcloud filestore instances describe nfs-server \
    --project=YOUR_PROJECT_ID \
    --zone=us-central1-a \
    --format="value(networks.ipAddresses[0])")

echo "Filestore IP: $FILESTORE_IP"
```

Save the following as `gke-filestore-setup.yaml`:

```yaml
# NFS StorageClass using Filestore
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: filestore-nfs
provisioner: nfs.csi.k8s.io
parameters:
  server: FILESTORE_IP_ADDRESS    # Replace with actual Filestore IP
  share: /nfs_share
volumeBindingMode: Immediate
reclaimPolicy: Retain

---
# Shared storage PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-nfs-claim
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: filestore-nfs
  resources:
    requests:
      storage: 100Gi

---
# Content management system deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cms-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: cms-app
  template:
    metadata:
      labels:
        app: cms-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
        volumeMounts:
        - name: shared-content
          mountPath: /usr/share/nginx/html
        - name: uploads
          mountPath: /var/uploads
      volumes:
      - name: shared-content
        persistentVolumeClaim:
          claimName: shared-nfs-claim
      - name: uploads
        persistentVolumeClaim:
          claimName: shared-nfs-claim

---
# File processor job
apiVersion: batch/v1
kind: Job
metadata:
  name: file-processor
spec:
  template:
    spec:
      containers:
      - name: processor
        image: busybox:1.35
        command: ["/bin/sh"]
        args: ["-c", "
          mkdir -p /shared/uploads /shared/processed;
          for i in $(seq 1 100); do
            echo 'Processing file '$i > /shared/processed/file_$i.txt;
            sleep 1;
          done;
          echo 'Processing complete'"]
        volumeMounts:
        - name: shared-storage
          mountPath: /shared
      volumes:
      - name: shared-storage
        persistentVolumeClaim:
          claimName: shared-nfs-claim
      restartPolicy: Never
  backoffLimit: 4

---
# Service for CMS
apiVersion: v1
kind: Service
metadata:
  name: cms-service
spec:
  selector:
    app: cms-app
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
```

---

## 🚀 Step 4: Deploy and Test

### Deploy Persistent Disk Resources
```bash
# Apply disk configuration
kubectl apply -f gke-disk-setup.yaml

# Check resources
kubectl get storageclass
kubectl get pvc
kubectl get pods
```

### Deploy Filestore Resources
```bash
# Replace FILESTORE_IP_ADDRESS in the YAML file
sed -i "s/FILESTORE_IP_ADDRESS/$FILESTORE_IP/g" gke-filestore-setup.yaml

# Apply Filestore configuration
kubectl apply -f gke-filestore-setup.yaml

# Check shared storage
kubectl get pvc shared-nfs-claim
kubectl get pods -l app=cms-app
```

---

## 🔍 Validation Steps

### 1. Test Persistent Disk Performance
```bash
# Connect to MongoDB and test performance
MONGODB_POD=$(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $MONGODB_POD -- mongosh -u admin -p password123 --eval "
use testdb;
// Insert test data
for(let i = 0; i < 10000; i++) {
  db.testcollection.insertOne({
    _id: i,
    name: 'user' + i,
    data: 'test data ' + Math.random(),
    timestamp: new Date()
  });
}
// Query performance test
db.testcollection.find({name: /user1.*/}).explain('executionStats');
"

# Test Redis performance
REDIS_POD=$(kubectl get pods -l app=redis-cache -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $REDIS_POD -- redis-cli eval "
for i=1,1000 do
  redis.call('set', 'key'..i, 'value'..i)
end
return 'Inserted 1000 keys'" 0
```

### 2. Test Filestore Shared Access
```bash
# Check file processing job
kubectl logs job/file-processor

# Verify shared files across CMS pods
CMS_PODS=($(kubectl get pods -l app=cms-app -o jsonpath='{.items[*].metadata.name}'))
for pod in "${CMS_PODS[@]}"; do
  echo "Checking $pod:"
  kubectl exec $pod -- ls -la /usr/share/nginx/html/processed/ | head -5
done

# Test concurrent file access
kubectl exec ${CMS_PODS[0]} -- touch /usr/share/nginx/html/test-concurrent.txt
kubectl exec ${CMS_PODS[1]} -- ls -la /usr/share/nginx/html/test-concurrent.txt
```

### 3. Test Volume Expansion
```bash
# Expand fast SSD volume
kubectl patch pvc fast-ssd-claim -p '{"spec":{"resources":{"requests":{"storage":"200Gi"}}}}'

# Check expansion status
kubectl get pvc fast-ssd-claim
kubectl describe pvc fast-ssd-claim

# Verify new size in MongoDB pod
kubectl exec $MONGODB_POD -- df -h /data/db
```

---

## 📊 Performance Testing

### Disk I/O Benchmarks
```bash
# Test MongoDB disk performance
kubectl exec $MONGODB_POD -- sh -c "
cd /data/db
# Sequential write test
dd if=/dev/zero of=testfile bs=1M count=1000 oflag=direct
# Sequential read test
dd if=testfile of=/dev/null bs=1M iflag=direct
# Random I/O test
dd if=/dev/zero of=testfile bs=4k count=25000 oflag=direct
rm testfile"

# Test Redis persistence performance
kubectl exec $REDIS_POD -- sh -c "
# Fill Redis with data
redis-cli eval 'for i=1,100000 do redis.call(\"set\", \"benchmark:\"..i, string.rep(\"x\", 1000)) end' 0
# Force save to disk
redis-cli bgsave
# Check save completion
while [ \$(redis-cli eval 'return redis.call(\"info\", \"persistence\")' 0 | grep -c rdb_bgsave_in_progress:0) -eq 0 ]; do
  sleep 1
done
echo 'Background save completed'"
```

### Network Performance (Filestore)
```bash
# Test NFS throughput
kubectl run nfs-test --image=busybox:1.35 --rm -it -- sh -c "
mount | grep nfs
# Large file write test
dd if=/dev/zero of=/mnt/test_large.dat bs=1M count=100
# Multiple small files test
for i in \$(seq 1 1000); do
  echo 'test content' > /mnt/small_\$i.txt
done
# Cleanup
rm /mnt/test_large.dat /mnt/small_*.txt"
```

---

## 🔧 Advanced Configuration

### Regional Persistent Disk for High Availability
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: regional-ssd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
  replication-type: regional-pd
  zones: us-central1-a,us-central1-b,us-central1-c
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

### Extreme Performance Configuration
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ultra-performance
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-extreme
  provisioned-iops-on-create: "50000"
  provisioned-throughput-on-create: "2000Mi"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

### High-Performance Filestore
```bash
# Create high-performance Filestore
gcloud filestore instances create nfs-performance \
    --project=YOUR_PROJECT_ID \
    --zone=us-central1-a \
    --tier=BASIC_SSD \
    --file-share=name="fast_share",capacity=2.5TB \
    --network=name="default"
```

---

## 🧹 Cleanup

```bash
# Delete Kubernetes resources
kubectl delete -f gke-disk-setup.yaml
kubectl delete -f gke-filestore-setup.yaml

# Delete Filestore instance
gcloud filestore instances delete nfs-server \
    --project=YOUR_PROJECT_ID \
    --zone=us-central1-a \
    --quiet

# Check that PVs are deleted
kubectl get pv
```

---

## 🔧 Troubleshooting

### Common Issues

1. **PVC stuck in Pending**
   ```bash
   kubectl describe pvc YOUR_PVC_NAME
   # Check for zone mismatches or quota issues
   gcloud compute disks list --filter="zone:YOUR_ZONE"
   ```

2. **Filestore mount failures**
   ```bash
   # Check Filestore instance status
   gcloud filestore instances list --project=YOUR_PROJECT_ID
   
   # Verify network connectivity
   kubectl run netshoot --rm -it --image=nicolaka/netshoot -- nslookup FILESTORE_IP
   ```

3. **Performance issues**
   ```bash
   # Check disk type and performance limits
   gcloud compute disks describe DISK_NAME --zone=YOUR_ZONE
   
   # Monitor disk metrics
   gcloud logging read "resource.type=gce_disk" --limit=10
   ```

4. **Regional PD issues**
   ```bash
   # Check zone availability
   gcloud compute zones list --filter="region:YOUR_REGION AND status:UP"
   
   # Verify cluster spans multiple zones
   kubectl get nodes -o wide
   ```

### Performance Tuning
```bash
# Check GKE cluster version for latest CSI features
kubectl version --short

# Monitor storage performance
kubectl top node
kubectl describe node NODE_NAME | grep -A 10 "Allocated resources"

# Check for storage-related events
kubectl get events --field-selector reason=FailedMount --all-namespaces
```

### Google Cloud Console Monitoring
```bash
# View persistent disk usage
gcloud compute disks list --project=YOUR_PROJECT_ID

# Check Filestore performance metrics
gcloud filestore instances describe INSTANCE_NAME \
    --project=YOUR_PROJECT_ID \
    --zone=YOUR_ZONE
```

---

**Use Case**: High-performance databases, shared content management, data analytics
**Best For**: Google Cloud native applications requiring enterprise-grade storage
