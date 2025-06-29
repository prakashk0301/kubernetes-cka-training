# 🏠 Local/On-Premises Dynamic Provisioning

This guide covers dynamic provisioning for local Kubernetes clusters using Local Path Provisioner, NFS, and other local storage solutions.

## 📋 Prerequisites

- Local Kubernetes cluster (minikube, kind, kubeadm, etc.)
- `kubectl` configured for your cluster
- Administrative access to nodes
- NFS server (optional, for shared storage)

---

## 🔧 Step 1: Install Local Path Provisioner

Local Path Provisioner provides dynamic provisioning using local storage on nodes.

```bash
# Install Local Path Provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml

# Verify installation
kubectl get pods -n local-path-storage
kubectl get storageclass local-path
```

---

## 📦 Step 2: Deploy Local Path Storage Resources

Save the following as `local-path-setup.yaml`:

```yaml
# Custom Local Path StorageClass for databases
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path-fast
provisioner: rancher.io/local-path
parameters:
  nodePath: /opt/local-path-provisioner/fast    # Custom path for faster storage
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true

---
# General purpose local storage
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path-general
provisioner: rancher.io/local-path
parameters:
  nodePath: /opt/local-path-provisioner/general
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true

---
# ConfigMap for custom storage paths
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-path-config
  namespace: local-path-storage
data:
  config.json: |-
    {
      "nodePathMap": [
        {
          "node": "DEFAULT_PATH_FOR_NON_LISTED_NODES",
          "paths": ["/opt/local-path-provisioner"]
        }
      ]
    }
  setup: |-
    #!/bin/sh
    set -eu
    mkdir -p "$VOL_DIR"
    if [ "$VOL_SIZE_BYTES" != "0" ]; then
      # Optional: Set up volume size limits using quotas
      echo "Volume size: $VOL_SIZE_BYTES bytes"
    fi
  teardown: |-
    #!/bin/sh
    set -eu
    rm -rf "$VOL_DIR"

---
# MySQL database with fast local storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path-fast
  resources:
    requests:
      storage: 20Gi

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-db
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql-db
  template:
    metadata:
      labels:
        app: mysql-db
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "rootpassword"
        - name: MYSQL_DATABASE
          value: "testdb"
        - name: MYSQL_USER
          value: "testuser"
        - name: MYSQL_PASSWORD
          value: "testpass"
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
        livenessProbe:
          exec:
            command: ["mysqladmin", "ping"]
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command: ["mysql", "-h", "127.0.0.1", "-e", "SELECT 1"]
          initialDelaySeconds: 5
          periodSeconds: 2
      volumes:
      - name: mysql-data
        persistentVolumeClaim:
          claimName: mysql-pvc

---
# Application storage PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-storage-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path-general
  resources:
    requests:
      storage: 10Gi

---
# Web application with persistent storage
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 2
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
        - name: web-content
          mountPath: /usr/share/nginx/html
        - name: logs
          mountPath: /var/log/nginx
      volumes:
      - name: web-content
        persistentVolumeClaim:
          claimName: app-storage-pvc
      - name: logs
        emptyDir: {}

---
# Services
apiVersion: v1
kind: Service
metadata:
  name: mysql-service
spec:
  selector:
    app: mysql-db
  ports:
  - port: 3306
    targetPort: 3306
  type: ClusterIP

---
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
```

---

## 📂 Step 3: Setup NFS for Shared Storage

### Install NFS Server (Ubuntu/Debian)
```bash
# On the NFS server node
sudo apt update
sudo apt install -y nfs-kernel-server

# Create shared directory
sudo mkdir -p /srv/nfs/shared
sudo chown nobody:nogroup /srv/nfs/shared
sudo chmod 777 /srv/nfs/shared

# Configure NFS exports
echo "/srv/nfs/shared *(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports

# Restart NFS service
sudo systemctl restart nfs-kernel-server
sudo exportfs -ra

# Check NFS exports
sudo exportfs -v
```

### Install NFS CSI Driver
```bash
# Install NFS CSI driver
curl -skSL https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/v4.6.0/deploy/install-driver.sh | bash -s v4.6.0 --

# Verify installation
kubectl get pods -n kube-system -l app=csi-nfs-controller
kubectl get pods -n kube-system -l app=csi-nfs-node
```

Save the following as `nfs-setup.yaml`:

```yaml
# NFS StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-shared
provisioner: nfs.csi.k8s.io
parameters:
  server: NFS_SERVER_IP          # Replace with your NFS server IP
  share: /srv/nfs/shared
volumeBindingMode: Immediate
reclaimPolicy: Delete
allowVolumeExpansion: false

---
# Shared storage PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-nfs-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-shared
  resources:
    requests:
      storage: 50Gi

---
# Multi-pod application using shared storage
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shared-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: shared-app
  template:
    metadata:
      labels:
        app: shared-app
    spec:
      containers:
      - name: worker
        image: busybox:1.35
        command: ["/bin/sh"]
        args: ["-c", "while true; do echo $(hostname): $(date) >> /shared/activity.log; sleep 30; done"]
        volumeMounts:
        - name: shared-storage
          mountPath: /shared
      volumes:
      - name: shared-storage
        persistentVolumeClaim:
          claimName: shared-nfs-pvc

---
# Log viewer pod
apiVersion: v1
kind: Pod
metadata:
  name: log-viewer
spec:
  containers:
  - name: viewer
    image: busybox:1.35
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo 'Recent activity:'; tail -20 /shared/activity.log; sleep 60; done"]
    volumeMounts:
    - name: shared-storage
      mountPath: /shared
  volumes:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: shared-nfs-pvc
```

---

## 🚀 Step 4: Deploy and Test

### Deploy Local Path Resources
```bash
# Apply local path configuration
kubectl apply -f local-path-setup.yaml

# Check resources
kubectl get storageclass
kubectl get pvc
kubectl get pods
```

### Deploy NFS Resources
```bash
# Get NFS server IP (if running on a cluster node)
NFS_SERVER_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Update NFS server IP in the YAML
sed -i "s/NFS_SERVER_IP/$NFS_SERVER_IP/g" nfs-setup.yaml

# Apply NFS configuration
kubectl apply -f nfs-setup.yaml

# Check shared storage
kubectl get pvc shared-nfs-pvc
kubectl get pods -l app=shared-app
```

---

## 🔍 Validation Steps

### 1. Test Local Path Storage
```bash
# Test MySQL database
MYSQL_POD=$(kubectl get pods -l app=mysql-db -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $MYSQL_POD -- mysql -u testuser -ptestpass testdb -e "
CREATE TABLE users (id INT PRIMARY KEY, name VARCHAR(50));
INSERT INTO users VALUES (1, 'Alice'), (2, 'Bob');
SELECT * FROM users;"

# Delete pod and verify data persistence
kubectl delete pod $MYSQL_POD
kubectl wait --for=condition=ready pod -l app=mysql-db --timeout=300s

# Verify data still exists
MYSQL_POD=$(kubectl get pods -l app=mysql-db -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $MYSQL_POD -- mysql -u testuser -ptestpass testdb -e "SELECT * FROM users;"
```

### 2. Test NFS Shared Storage
```bash
# Check shared activity logs
kubectl logs -l app=shared-app --tail=10

# View aggregated logs
kubectl logs log-viewer --tail=10

# Test file sharing between pods
kubectl exec log-viewer -- touch /shared/test-file.txt
SHARED_POD=$(kubectl get pods -l app=shared-app -o jsonpath='{.items[0].metadata.name}')
kubectl exec $SHARED_POD -- ls -la /shared/test-file.txt
```

### 3. Test Storage on Host
```bash
# Check local path storage on nodes
kubectl get nodes -o wide
kubectl describe pv $(kubectl get pv -o jsonpath='{.items[0].metadata.name}')

# SSH to node and check storage
# NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
# ssh user@$NODE_IP "sudo ls -la /opt/local-path-provisioner/"
```

---

## 📊 Performance Testing

### Local Storage Performance
```bash
# Test MySQL performance
kubectl exec $MYSQL_POD -- sh -c "
# Create performance test table
mysql -u testuser -ptestpass testdb -e '
CREATE TABLE perf_test (
  id INT AUTO_INCREMENT PRIMARY KEY,
  data TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);'

# Insert test data
for i in {1..1000}; do
  mysql -u testuser -ptestpass testdb -e \"INSERT INTO perf_test (data) VALUES ('test data $i');\"
done

# Query performance test
time mysql -u testuser -ptestpass testdb -e 'SELECT COUNT(*) FROM perf_test;'"
```

### NFS Performance Testing
```bash
# Test NFS throughput
kubectl exec log-viewer -- sh -c "
# Large file write test
dd if=/dev/zero of=/shared/test_1gb.dat bs=1M count=1024

# Multiple small files test
for i in \$(seq 1 100); do
  echo 'test content' > /shared/small_file_\$i.txt
done

# Read performance test
dd if=/shared/test_1gb.dat of=/dev/null bs=1M

# Cleanup
rm /shared/test_1gb.dat /shared/small_file_*.txt"
```

---

## 🔧 Advanced Configurations

### HostPath StorageClass for Specific Node Paths
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hostpath-ssd
provisioner: rancher.io/local-path
parameters:
  nodePath: /mnt/ssd-storage      # Point to SSD mount
volumeBindingMode: WaitForFirstConsumer
```

### Local Static Provisioning for High Performance
```yaml
# Pre-create PV for specific node and path
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-ssd-pv
spec:
  capacity:
    storage: 100Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-ssd
  local:
    path: /mnt/fast-ssd
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - your-fast-node

---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-ssd
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

### Custom NFS Mount Options
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-custom
provisioner: nfs.csi.k8s.io
parameters:
  server: NFS_SERVER_IP
  share: /srv/nfs/shared
  mountOptions: "nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2"
volumeBindingMode: Immediate
```

---

## 🧹 Cleanup

```bash
# Delete all resources
kubectl delete -f local-path-setup.yaml
kubectl delete -f nfs-setup.yaml

# Uninstall Local Path Provisioner
kubectl delete -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml

# Uninstall NFS CSI driver
curl -skSL https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/v4.6.0/deploy/uninstall-driver.sh | bash -s --

# Clean up NFS server (if needed)
# sudo rm -rf /srv/nfs/shared
# sudo sed -i '/\/srv\/nfs\/shared/d' /etc/exports
# sudo exportfs -ra
```

---

## 🔧 Troubleshooting

### Common Issues

1. **Local Path Provisioner not working**
   ```bash
   kubectl logs -n local-path-storage -l app=local-path-provisioner
   kubectl describe pods -n local-path-storage
   ```

2. **NFS mount failures**
   ```bash
   # Check NFS server accessibility
   kubectl run nfs-test --rm -it --image=busybox:1.35 -- sh
   # In the pod: telnet NFS_SERVER_IP 2049
   
   # Check NFS CSI driver logs
   kubectl logs -n kube-system -l app=csi-nfs-controller
   ```

3. **Storage not persisting**
   ```bash
   # Check PV and node binding
   kubectl get pv
   kubectl describe pv PV_NAME
   
   # Check node storage
   kubectl describe node NODE_NAME | grep -A 10 "Allocated resources"
   ```

4. **Permission issues**
   ```bash
   # Check pod security context
   kubectl get pod POD_NAME -o yaml | grep -A 10 securityContext
   
   # For NFS, check server permissions
   # On NFS server: ls -la /srv/nfs/shared
   ```

### Performance Optimization

```bash
# Monitor node storage usage
kubectl top nodes

# Check I/O performance on nodes
kubectl run iostat --rm -it --image=nicolaka/netshoot -- iostat -x 1 5

# Monitor NFS performance
kubectl exec log-viewer -- iostat -x 1 5
```

---

**Use Case**: Development environments, local testing, edge computing, air-gapped deployments  
**Best For**: Learning Kubernetes, development clusters, resource-constrained environments
