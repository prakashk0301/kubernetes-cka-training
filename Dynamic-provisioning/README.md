
# 📦 Dynamic Volume Provisioning in Amazon EKS with EFS

Dynamic provisioning in Kubernetes allows volumes to be created on-demand when a `PersistentVolumeClaim` (PVC) is requested. In Amazon EKS, this is commonly implemented using the **Amazon EFS CSI driver**, which supports dynamically creating access points within an existing EFS file system.

---

## 🔧 What Is Dynamic Provisioning?

Dynamic provisioning eliminates the need for pre-creating `PersistentVolumes` (PVs). When a user creates a PVC, the configured **StorageClass** handles automatic volume creation in the background—ideal for workloads that need scalable and persistent shared storage like Amazon EFS.

---

## 📁 Use Case for EFS with Dynamic Provisioning

Amazon EFS supports the `ReadWriteMany` access mode, which allows multiple Pods across different nodes to read and write to the same volume—perfect for distributed applications, content management systems, and shared file storage.

---

## 🚀 YAML Example: Dynamic Provisioning Using EFS CSI Driver

```yaml
# Define a StorageClass for dynamic EFS provisioning
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-05ff8378afea6c10c     # Your EFS File System ID
  directoryPerms: "700"                  # Permissions on the created directory
  gidRangeStart: "1000"                  # Optional: GID range for access points
  gidRangeEnd: "2000"                    # Optional
  basePath: "/dynamic_provisioning"     # Optional base directory
  subPathPattern: "${.PVC.namespace}/${.PVC.name}"  # Dynamic sub-path creation
  ensureUniqueDirectory: "true"          # Ensures a unique directory for each PVC
  reuseAccessPoint: "false"              # Create new access point every time
```

```yaml
# PersistentVolumeClaim (PVC) to request storage using the above StorageClass
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: efs-claim
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: 5Gi   # Size requested is symbolic for EFS (it grows elastically)
```

```yaml
# Pod that uses the dynamically provisioned volume
apiVersion: v1
kind: Pod
metadata:
  name: efs-app
spec:
  containers:
    - name: app
      image: centos:7
      command: ["/bin/sh"]
      args: ["-c", "while true; do echo $(date -u) >> /data/out; sleep 5; done"]
      volumeMounts:
        - name: persistent-storage
          mountPath: /data
  volumes:
    - name: persistent-storage
      persistentVolumeClaim:
        claimName: efs-claim
```

---

## 🔍 How It Works

1. **StorageClass**: Triggers dynamic provisioning of an EFS access point when a PVC is created.
2. **PVC**: Requests storage, which in turn instructs the EFS CSI driver to create the necessary resources.
3. **Pod**: Mounts the dynamically created EFS volume at `/data`.

This setup allows seamless and scalable use of Amazon EFS with EKS, enabling persistent shared storage across nodes.

---

## 🧪 Validate Setup (Pod Access)

```bash
# Get Pod name
kubectl get pods

# Access Pod shell
kubectl exec -it <pod-name> -- /bin/bash  # or -- /bin/sh

# Check file system access
cd /data
touch abx.txt
ls -l

# Exit the Pod
exit
```

---

## 🧹 Cleanup

```bash
# Delete the Pod (PVC and volume stay unless explicitly removed)
kubectl delete pod <pod-name>
```

> 💡 **Tip:** Deleting the PVC will also delete the dynamically created EFS access point and its directory, if `reuseAccessPoint: false` and `ensureUniqueDirectory: true` are set.


you can recreate pod, make sure you attach the same pvc. you can access the pod's terminal and validate the data.
---

## 📚 Reference

- GitHub Repo: [AWS EFS CSI Driver - Dynamic Provisioning](https://github.com/kubernetes-sigs/aws-efs-csi-driver/tree/master/examples/kubernetes/dynamic_provisioning)
