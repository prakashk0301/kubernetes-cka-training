# 📋 Dynamic Provisioning Quick Reference

## 🚀 Quick Commands

### Check Storage Resources
```bash
# List StorageClasses
kubectl get storageclass

# List PVCs
kubectl get pvc

# List PVs
kubectl get pv

# Check events
kubectl get events --field-selector type=Warning
```

### Test Dynamic Provisioning
```bash
# Run the test script
chmod +x test-dynamic-provisioning.sh
./test-dynamic-provisioning.sh

# Manual test with a simple PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: YOUR_STORAGE_CLASS
  resources:
    requests:
      storage: 1Gi
EOF
```

## 🛠️ Common StorageClass Examples

### AWS EKS
```yaml
# EBS GP3
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
```

### Azure AKS
```yaml
# Azure Disk Premium
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-premium
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_LRS
```

### Google GKE
```yaml
# SSD Persistent Disk
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
```

### Local/On-Premises
```yaml
# Local Path
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
provisioner: rancher.io/local-path
```

## 🔍 Troubleshooting Commands

### CSI Driver Issues
```bash
# Check CSI driver pods
kubectl get pods -n kube-system | grep csi

# Check CSI node driver logs (AWS EBS example)
kubectl logs -n kube-system -l app=ebs-csi-node

# Check CSI controller logs
kubectl logs -n kube-system -l app=ebs-csi-controller
```

### PVC Issues
```bash
# Describe PVC for events
kubectl describe pvc YOUR_PVC_NAME

# Check PV binding
kubectl get pv -o wide

# Check storage capacity
kubectl get nodes -o custom-columns=NAME:.metadata.name,CAPACITY:.status.capacity.storage
```

## 📦 Installation Commands

### Local Path Provisioner
```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.28/deploy/local-path-storage.yaml
```

### AWS EBS CSI Driver (EKS Add-on)
```bash
aws eks create-addon \
  --cluster-name YOUR_CLUSTER \
  --addon-name aws-ebs-csi-driver
```

### AWS EFS CSI Driver (EKS Add-on)
```bash
aws eks create-addon \
  --cluster-name YOUR_CLUSTER \
  --addon-name aws-efs-csi-driver
```

## 🧪 Validation Scripts

### Test Data Persistence
```bash
# Create test data
kubectl exec YOUR_POD -- echo "test data" > /mount/path/test.txt

# Delete pod
kubectl delete pod YOUR_POD

# Check data after pod restart
kubectl exec NEW_POD -- cat /mount/path/test.txt
```

### Performance Test
```bash
# Write test
kubectl exec YOUR_POD -- dd if=/dev/zero of=/mount/path/test bs=1M count=100

# Read test
kubectl exec YOUR_POD -- dd if=/mount/path/test of=/dev/null bs=1M
```

---

**Dynamic Provisioning Quick Reference - Kubernetes 1.32+**
