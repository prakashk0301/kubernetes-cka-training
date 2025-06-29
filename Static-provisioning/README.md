# Static Volume Provisioning in Kubernetes

Static provisioning involves manually creating storage resources (PersistentVolumes) that applications can claim through PersistentVolumeClaims. This approach provides more control over storage configuration and is often used for production environments with specific storage requirements.

---

## 🎯 What is Static Provisioning?

**Static Provisioning** is the process where:
1. **Administrator** pre-creates storage volumes (PVs) manually
2. **Developer** creates PersistentVolumeClaims (PVCs) to request storage
3. **Kubernetes** binds PVCs to available PVs based on requirements
4. **Applications** use the bound storage through volume mounts

---

## 🆚 Static vs Dynamic Provisioning

| Feature | Static Provisioning | Dynamic Provisioning |
|---------|-------------------|---------------------|
| **Setup** | Manual PV creation | Automatic via StorageClass |
| **Control** | Full control over storage | Standardized provisioning |
| **Flexibility** | Custom configurations | Template-based |
| **Management** | More administrative overhead | Simplified management |
| **Use Cases** | Production, specific requirements | Development, standardized needs |

---

## 🏗️ Static Provisioning Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Administrator  │    │   Developer     │    │   Application   │
│                 │    │                 │    │                 │
│  Creates PV  ───┼───▶│  Creates PVC ───┼───▶│  Uses Volume    │
│  (Pre-provision)│    │  (Claims space) │    │  (Mount Path)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                        │                        │
         ▼                        ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Physical Storage│    │ PV ←→ PVC Bind  │    │   Pod Volume    │
│ (EBS, NFS, etc.)│    │   (Kubernetes)  │    │   (Container)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

---

## 🌟 Multi-Platform Static Provisioning Examples

### 🟧 AWS EBS Static Provisioning

#### Step 1: Create EBS Volume
```bash
# Create EBS volume using AWS CLI
aws ec2 create-volume \
    --size 20 \
    --volume-type gp3 \
    --availability-zone us-west-2a \
    --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=k8s-static-volume}]' \
    --encrypted

# Get the volume ID from output
VOLUME_ID="vol-1234567890abcdef0"
```

#### Step 2: Deploy EBS Static Resources
```yaml
# ebs-static-provisioning.yaml
# Pre-created EBS Persistent Volume
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ebs-static-pv
  labels:
    type: ebs
    environment: production
    storage-tier: ssd
spec:
  capacity:
    storage: 20Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ebs-static
  csi:
    driver: ebs.csi.aws.com
    volumeHandle: vol-1234567890abcdef0  # Replace with actual volume ID
    fsType: ext4
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: topology.ebs.csi.aws.com/zone
          operator: In
          values:
          - us-west-2a  # Must match EBS volume AZ

---
# StorageClass for static provisioning
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-static
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain

---
# PVC claiming the static volume
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: database-storage
  namespace: production
  labels:
    app: postgresql
    tier: database
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  storageClassName: ebs-static
  selector:
    matchLabels:
      type: ebs
      environment: production

---
# PostgreSQL deployment using static volume
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql-static
  namespace: production
spec:
  serviceName: postgresql
  replicas: 1
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
      - name: postgresql
        image: postgres:15
        env:
        - name: POSTGRES_DB
          value: "productiondb"
        - name: POSTGRES_USER
          value: "dbuser"
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: database-storage
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
      volumes:
      - name: database-storage
        persistentVolumeClaim:
          claimName: database-storage

---
# Database secret
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: production
type: Opaque
data:
  password: cGFzc3dvcmQxMjM=  # base64 encoded 'password123'

---
# Service for PostgreSQL
apiVersion: v1
kind: Service
metadata:
  name: postgresql-service
  namespace: production
spec:
  selector:
    app: postgresql
  ports:
  - port: 5432
    targetPort: 5432
  type: ClusterIP
```

### 🔷 Azure Disk Static Provisioning

```yaml
# azure-disk-static.yaml
# Pre-created Azure Disk PV
apiVersion: v1
kind: PersistentVolume
metadata:
  name: azure-disk-static-pv
  labels:
    type: azure-disk
    performance-tier: premium
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: azure-disk-static
  csi:
    driver: disk.csi.azure.com
    volumeHandle: /subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Compute/disks/{disk-name}
    fsType: ext4
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: topology.disk.csi.azure.com/zone
          operator: In
          values:
          - westus2-1

---
# PVC for Azure Disk
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: azure-app-storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: azure-disk-static
  selector:
    matchLabels:
      type: azure-disk
      performance-tier: premium
```

### 🔵 Google Persistent Disk Static Provisioning

```yaml
# gcp-disk-static.yaml
# Pre-created GCE Persistent Disk PV
apiVersion: v1
kind: PersistentVolume
metadata:
  name: gce-disk-static-pv
  labels:
    type: gce-pd
    disk-type: ssd
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: gce-disk-static
  csi:
    driver: pd.csi.storage.gke.io
    volumeHandle: projects/{project-id}/zones/{zone}/disks/{disk-name}
    fsType: ext4
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: topology.gke.io/zone
          operator: In
          values:
          - us-central1-a

---
# High-performance application using GCE disk
apiVersion: apps/v1
kind: Deployment
metadata:
  name: analytics-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: analytics
  template:
    metadata:
      labels:
        app: analytics
    spec:
      containers:
      - name: analytics
        image: elasticsearch:8.11.0
        ports:
        - containerPort: 9200
        volumeMounts:
        - name: es-data
          mountPath: /usr/share/elasticsearch/data
        env:
        - name: discovery.type
          value: single-node
      volumes:
      - name: es-data
        persistentVolumeClaim:
          claimName: gce-app-storage
```

### 🏠 NFS Static Provisioning

```yaml
# nfs-static-provisioning.yaml
# Pre-configured NFS Persistent Volume
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-static-pv
  labels:
    type: nfs
    access-mode: shared
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs-static
  nfs:
    server: 192.168.1.100  # NFS server IP
    path: /exports/k8s-storage
  mountOptions:
    - nfsvers=4.1
    - rsize=1048576
    - wsize=1048576
    - hard
    - timeo=600
    - retrans=2

---
# PVC for shared NFS storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-storage
  namespace: content-management
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 50Gi
  storageClassName: nfs-static
  selector:
    matchLabels:
      type: nfs
      access-mode: shared

---
# Multi-pod application using shared storage
apiVersion: apps/v1
kind: Deployment
metadata:
  name: content-cms
  namespace: content-management
spec:
  replicas: 3
  selector:
    matchLabels:
      app: cms
  template:
    metadata:
      labels:
        app: cms
    spec:
      containers:
      - name: cms
        image: wordpress:6.4
        ports:
        - containerPort: 80
        env:
        - name: WORDPRESS_DB_HOST
          value: mysql-service
        - name: WORDPRESS_DB_USER
          value: wordpress
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: wp-db-credentials
              key: password
        volumeMounts:
        - name: wordpress-content
          mountPath: /var/www/html/wp-content
        - name: shared-uploads
          mountPath: /var/www/html/wp-content/uploads
      volumes:
      - name: wordpress-content
        emptyDir: {}
      - name: shared-uploads
        persistentVolumeClaim:
          claimName: shared-storage
```

### 💾 Local Storage Static Provisioning

```yaml
# local-storage-static.yaml
# Local storage PV (node-specific)
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-ssd-pv
  labels:
    type: local-ssd
    performance: high
spec:
  capacity:
    storage: 200Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-ssd
  local:
    path: /mnt/fast-ssd  # Pre-mounted SSD on node
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - worker-node-1  # Specific node with SSD

---
# PVC for local high-performance storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-fast-storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 200Gi
  storageClassName: local-ssd
  selector:
    matchLabels:
      type: local-ssd
      performance: high

---
# Database requiring high IOPS
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb-high-performance
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
      nodeSelector:
        kubernetes.io/hostname: worker-node-1  # Force scheduling to SSD node
      containers:
      - name: mongodb
        image: mongo:7.0
        ports:
        - containerPort: 27017
        volumeMounts:
        - name: mongodb-data
          mountPath: /data/db
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          value: admin
        - name: MONGO_INITDB_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mongo-credentials
              key: password
      volumes:
      - name: mongodb-data
        persistentVolumeClaim:
          claimName: local-fast-storage
```

---

## 🔄 Migration from Dynamic to Static

Sometimes you need to convert dynamically provisioned volumes to static ones:

```yaml
# migration-example.yaml
# Step 1: Backup existing PVC data
apiVersion: batch/v1
kind: Job
metadata:
  name: volume-backup
spec:
  template:
    spec:
      containers:
      - name: backup
        image: busybox:1.35
        command: ["/bin/sh"]
        args: ["-c", "tar czf /backup/data-backup.tar.gz -C /source ."]
        volumeMounts:
        - name: source-volume
          mountPath: /source
        - name: backup-storage
          mountPath: /backup
      volumes:
      - name: source-volume
        persistentVolumeClaim:
          claimName: existing-dynamic-pvc
      - name: backup-storage
        hostPath:
          path: /tmp/backups
      restartPolicy: Never

---
# Step 2: Create static PV pointing to the same underlying storage
apiVersion: v1
kind: PersistentVolume
metadata:
  name: migrated-static-pv
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: migrated-static
  csi:
    driver: ebs.csi.aws.com
    volumeHandle: vol-existing123  # Use existing volume ID
    fsType: ext4

---
# Step 3: Create new PVC for static volume
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: migrated-static-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: migrated-static
  volumeName: migrated-static-pv
```

---

## 🧪 Testing and Validation

### Validation Script
```bash
#!/bin/bash
# test-static-provisioning.sh

echo "🧪 Testing Static Volume Provisioning..."

# Test 1: Check PV creation
echo "Test 1: Checking PersistentVolume creation"
if kubectl get pv | grep -q "ebs-static-pv"; then
    echo "✅ PV created successfully"
else
    echo "❌ PV creation failed"
    exit 1
fi

# Test 2: Check PVC binding
echo "Test 2: Checking PVC binding"
PVC_STATUS=$(kubectl get pvc database-storage -n production -o jsonpath='{.status.phase}')
if [ "$PVC_STATUS" = "Bound" ]; then
    echo "✅ PVC bound successfully"
else
    echo "❌ PVC binding failed (Status: $PVC_STATUS)"
    exit 1
fi

# Test 3: Test data persistence
echo "Test 3: Testing data persistence"
POD_NAME=$(kubectl get pods -n production -l app=postgresql -o jsonpath='{.items[0].metadata.name}')
if [ -n "$POD_NAME" ]; then
    kubectl exec -n production $POD_NAME -- psql -U dbuser -d productiondb -c "CREATE TABLE test_table (id SERIAL PRIMARY KEY, data TEXT);"
    kubectl exec -n production $POD_NAME -- psql -U dbuser -d productiondb -c "INSERT INTO test_table (data) VALUES ('Static provisioning test');"
    
    # Restart pod and check data
    kubectl delete pod -n production $POD_NAME
    kubectl wait --for=condition=ready pod -l app=postgresql -n production --timeout=300s
    
    NEW_POD=$(kubectl get pods -n production -l app=postgresql -o jsonpath='{.items[0].metadata.name}')
    RESULT=$(kubectl exec -n production $NEW_POD -- psql -U dbuser -d productiondb -t -c "SELECT data FROM test_table WHERE id=1;")
    
    if echo "$RESULT" | grep -q "Static provisioning test"; then
        echo "✅ Data persistence verified"
    else
        echo "❌ Data persistence failed"
    fi
else
    echo "❌ PostgreSQL pod not found"
fi

echo "🎉 Static provisioning testing completed!"
```

### Performance Testing
```bash
# Test disk I/O performance
kubectl exec -n production deployment/postgresql-static -- sh -c "
# Write test
dd if=/dev/zero of=/var/lib/postgresql/data/test_write bs=1M count=100 oflag=direct

# Read test
dd if=/var/lib/postgresql/data/test_write of=/dev/null bs=1M iflag=direct

# Clean up
rm /var/lib/postgresql/data/test_write
"
```

---

## 📊 Monitoring and Management

### Resource Monitoring
```bash
# Check PV/PVC status
kubectl get pv,pvc -A

# Monitor storage usage
kubectl describe pv ebs-static-pv

# Check volume health
kubectl get events --field-selector involvedObject.kind=PersistentVolume

# Check CSI driver logs
kubectl logs -n kube-system -l app=ebs-csi-controller
```

### Capacity Management
```yaml
# resource-quotas.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: storage-quota
  namespace: production
spec:
  hard:
    requests.storage: "500Gi"
    persistentvolumeclaims: "10"
    count/persistentvolumeclaims: "10"

---
# LimitRange for PVC sizes
apiVersion: v1
kind: LimitRange
metadata:
  name: pvc-limit-range
  namespace: production
spec:
  limits:
  - type: PersistentVolumeClaim
    min:
      storage: "1Gi"
    max:
      storage: "100Gi"
    default:
      storage: "10Gi"
```

---

## 🔐 Security Best Practices

### 1. Volume Encryption
```yaml
# Encrypted EBS volume PV
apiVersion: v1
kind: PersistentVolume
metadata:
  name: encrypted-ebs-pv
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  csi:
    driver: ebs.csi.aws.com
    volumeHandle: vol-encrypted123
    fsType: ext4
    volumeAttributes:
      encrypted: "true"
      kmsKeyId: "arn:aws:kms:region:account:key/key-id"
```

### 2. Access Control
```yaml
# RBAC for PV management
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: pvc-manager
rules:
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pv-admin
rules:
- apiGroups: [""]
  resources: ["persistentvolumes"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
```

### 3. Pod Security
```yaml
# Security context for pods using static volumes
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
  containers:
  - name: app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
    volumeMounts:
    - name: data-volume
      mountPath: /data
  volumes:
  - name: data-volume
    persistentVolumeClaim:
      claimName: secure-storage
```

---

## 🧹 Cleanup and Maintenance

### Cleanup Script
```bash
#!/bin/bash
# cleanup-static-volumes.sh

echo "🧹 Cleaning up static volumes..."

# Delete applications first
kubectl delete statefulset postgresql-static -n production
kubectl delete deployment content-cms -n content-management

# Delete PVCs (this will release PVs)
kubectl delete pvc database-storage -n production
kubectl delete pvc shared-storage -n content-management

# Check PV status (should be Released or Available)
kubectl get pv

# Manually delete PVs if needed
kubectl delete pv ebs-static-pv nfs-static-pv local-ssd-pv

# Clean up cloud resources (if not using Retain policy)
# aws ec2 delete-volume --volume-id vol-1234567890abcdef0

echo "✅ Cleanup completed!"
```

### Volume Reclaim Policies
```yaml
# Different reclaim policies
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-retain
spec:
  persistentVolumeReclaimPolicy: Retain  # Keep data after PVC deletion
  # ... other specs

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-delete
spec:
  persistentVolumeReclaimPolicy: Delete  # Delete underlying storage
  # ... other specs

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-recycle
spec:
  persistentVolumeReclaimPolicy: Recycle  # Deprecated - use Delete instead
  # ... other specs
```

---

## 📚 Real-World Use Cases

### 1. Database Migration
- **Scenario**: Migrating from external database to Kubernetes
- **Solution**: Pre-create volumes, import data, configure static PVs

### 2. Compliance Requirements
- **Scenario**: Regulated environments requiring specific storage configurations
- **Solution**: Use static provisioning for full control over encryption, location, and access

### 3. Performance Optimization
- **Scenario**: Applications requiring specific IOPS or throughput
- **Solution**: Pre-provision high-performance volumes with optimal configuration

### 4. Multi-Zone Deployments
- **Scenario**: Applications spanning multiple availability zones
- **Solution**: Create regional volumes or zone-specific static PVs

---

## 📖 References

- [Kubernetes Persistent Volumes Documentation](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [CSI Driver Documentation](https://kubernetes-csi.github.io/docs/)
- [AWS EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)
- [Azure Disk CSI Driver](https://github.com/kubernetes-sigs/azuredisk-csi-driver)
- [Google GCE PD CSI Driver](https://github.com/kubernetes-sigs/gcp-compute-persistent-disk-csi-driver)

---

**Last Updated**: December 2024  
**Kubernetes Version**: 1.32+  
**Status**: ✅ Production Ready

### 📝 `pv-static.yaml`
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ebs-pv-static
spec:
  capacity:
    storage: 1Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  csi:
    driver: ebs.csi.aws.com
    volumeHandle: vol-xxxxxxxx  # Replace with actual EBS volume ID
    fsType: ext4
```

### 📝 `pvc-static.yaml`
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ebs-pvc-static
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  volumeName: ebs-pv-static
  storageClassName: manual
```

### 📝 `pod.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "while true; do sleep 10; done"]
    volumeMounts:
    - mountPath: /data
      name: ebs-volume
  volumes:
  - name: ebs-volume
    persistentVolumeClaim:
      claimName: ebs-pvc
```