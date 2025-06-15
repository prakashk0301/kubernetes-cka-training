# Using AWS EBS (Elastic Block Store) Volumes in Kubernetes

## ✅ Use Case
**Stateful workloads** (e.g., databases) that need persistent storage.

- Kubernetes can dynamically provision EBS volumes using the **aws-ebs-csi-driver**.
- These volumes are attached to the node where the pod runs, and move with the pod if rescheduled.
- You use a **StorageClass + PVC**, and Kubernetes handles the rest.

---

## 🧱 Static Provisioning with Pre-created EBS Volume

If you want to create the EBS volume manually (e.g., via AWS Console), note the **volume ID** and **availability zone**.

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