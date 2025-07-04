# Kubernetes Security: RBAC, Roles, RoleBindings, ClusterRoles, ClusterRoleBindings, and Service Accounts

This guide covers essential Kubernetes security concepts and resources, including detailed descriptions, YAML examples, commands, and use cases. It is tailored for clusters installed with kubeadm (not EKS).

---

## 1. RBAC (Role-Based Access Control)

RBAC is a method of regulating access to Kubernetes resources based on the roles of individual users or service accounts. It allows you to define who can do what within your cluster.

- **Role:** Grants access to resources within a specific namespace.
- **ClusterRole:** Grants access to resources cluster-wide (all namespaces).
- **RoleBinding:** Assigns a Role to a user or service account within a namespace.
- **ClusterRoleBinding:** Assigns a ClusterRole to a user or service account cluster-wide.

---

## 2. Example: Granting Read-Only Pod Access to User `jane` in the `dev` Namespace

This example demonstrates how to grant user `jane` read-only access to pods in the `dev` namespace using RBAC.

### Step 1: Create the Role
**pod-reader-role-dev.yaml**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: dev
  name: pod-reader
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
```

### Step 2: Create the RoleBinding
**pod-reader-rolebinding-dev.yaml**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods-in-dev
  namespace: dev
subjects:
- kind: User
  name: jane
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

### Step 3: Apply the Role and RoleBinding
```bash
kubectl apply -f pod-reader-role-dev.yaml
kubectl apply -f pod-reader-rolebinding-dev.yaml
```

---

## 3. User Authentication in Self-Managed Clusters

Kubernetes does not manage user accounts directly. For self-managed clusters, you typically use certificate-based authentication.

### Step-by-Step: Creating a User and Assigning RBAC Permissions

#### 1. Generate a Private Key and CSR for `jane`
```bash
openssl genrsa -out jane.key 2048
openssl req -new -key jane.key -out jane.csr -subj "/CN=jane/O=devs"
```

#### 2. Generate base64 CSR and create the Kubernetes CSR YAML
```bash
cat jane.csr | base64 | tr -d '\n'
```
Copy the output and use it in the `request` field below:

**csr.yaml**
```yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: jane-csr
  namespace: dev
spec:
  request: <base64-encoded-csr-content>
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
  - client auth
```
> Replace `<base64-encoded-csr-content>` with the base64 string from the previous command.

```bash
kubectl apply -f csr.yaml
```

#### 3. Approve the CSR and Retrieve the Certificate
```bash
kubectl certificate approve jane-csr
kubectl get csr jane-csr -o jsonpath='{.status.certificate}' | base64 -d > jane.crt
```

#### 4. Configure kubectl for User `jane`
```bash
kubectl config set-credentials jane --client-certificate=jane.crt --client-key=jane.key --embed-certs=true
kubectl config set-context jane-context --cluster=<your-cluster-name> --user=jane
kubectl config use-context jane-context
```
> Replace `<your-cluster-name>` with your actual cluster name (see `kubectl config get-clusters`).

---

## 4. Testing Access

1. Try to create a pod as `jane` (should fail):
   ```bash
   kubectl apply -f sample-pod.yml -n dev
   # Expect a permission error
   ```
2. Switch to admin context and create a pod:
   ```bash
   kubectl config use-context kubernetes-admin@kubernetes --cluster=kubernetes
   kubectl apply -f sample-pod.yml -n dev
   ```
3. Switch back to `jane` and verify pod access:
   ```bash
   kubectl config use-context jane-context --cluster=kubernetes
   kubectl get pod -n dev
   ```

---

## 4. ClusterRole

A ClusterRole defines permissions cluster-wide or for non-namespaced resources.

**YAML Example:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
```

**Use Case:**
- Allow users to read pods in all namespaces.

---

## 5. ClusterRoleBinding

A ClusterRoleBinding grants the permissions defined in a ClusterRole to a user or service account cluster-wide.

**YAML Example:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-pods-global
subjects:
- kind: User
  name: jane
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-pod-reader
  apiGroup: rbac.authorization.k8s.io
```

**Use Case:**
- Bind the `cluster-pod-reader` ClusterRole to user `jane` for all namespaces.

---

## 6. Service Account

A ServiceAccount provides an identity for processes running in a Pod. By default, Pods use the `default` ServiceAccount in their namespace, but you can create and assign custom ServiceAccounts.

**YAML Example:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-service-account
  namespace: dev
```

**Assign ServiceAccount to a Pod:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mypod
  namespace: dev
spec:
  serviceAccountName: my-service-account
  containers:
  - name: mycontainer
    image: nginx
```

**Use Case:**
- Run a Pod with a specific ServiceAccount for fine-grained access control.

---

## 7. Common Commands

- **List Roles and RoleBindings:**
  ```bash
  kubectl get roles -n <namespace>
  kubectl get rolebindings -n <namespace>
  ```
- **List ClusterRoles and ClusterRoleBindings:**
  ```bash
  kubectl get clusterroles
  kubectl get clusterrolebindings
  ```
- **List ServiceAccounts:**
  ```bash
  kubectl get serviceaccounts -n <namespace>
  ```
- **Create resources from YAML:**
  ```bash
  kubectl apply -f <file>.yaml
  ```
- **Describe resources:**
  ```bash
  kubectl describe role <role-name> -n <namespace>
  kubectl describe rolebinding <binding-name> -n <namespace>
  kubectl describe clusterrole <role-name>
  kubectl describe clusterrolebinding <binding-name>
  kubectl describe serviceaccount <sa-name> -n <namespace>
  ```

---

## 8. Use Cases

- **Namespace Isolation:** Use Roles and RoleBindings to restrict access to resources within a namespace.
- **Cluster-wide Access:** Use ClusterRoles and ClusterRoleBindings for permissions across all namespaces.
- **Least Privilege Principle:** Grant only the permissions required for a user or service account.
- **ServiceAccount for Automation:** Use ServiceAccounts for CI/CD pipelines, controllers, or applications needing API access.
- **Auditing:** Use `kubectl auth can-i` to check permissions:
  ```bash
  kubectl auth can-i get pods --as jane -n dev
  ```

---

## 9. References

- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Kubernetes Service Accounts](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/overview/)

---

## 10. RBAC Core Concepts and Best Practices

### RBAC Core Concepts

- **Subjects:** The "who" that needs to perform actions. Can be:
  - **Users:** Human users authenticated to the cluster (typically via certificates or OIDC in self-managed clusters).
  - **Groups:** Collections of users.
  - **Service Accounts:** Non-human accounts for processes running in Pods (namespaced).
- **Verbs:** The "what" action can be performed (e.g., get, list, watch, create, update, patch, delete, exec).
- **Resources:** The "which" objects the action applies to (e.g., pods, deployments, services, secrets, configmaps, nodes, namespaces, etc.). Resources can be further specified by apiGroups.
- **Roles/ClusterRoles:** Define a set of permissions (verbs on resources).
- **RoleBindings/ClusterRoleBindings:** Grant the permissions defined in a Role/ClusterRole to a Subject.

### Enabling RBAC

RBAC is enabled by default in kubeadm-based clusters. Verify with:
```bash
kubectl api-versions | grep rbac.authorization.k8s.io
```
If not enabled, ensure `--authorization-mode=Node,RBAC` is set in `/etc/kubernetes/manifests/kube-apiserver.yaml`.

---


## 11. Security Best Practices for Self-Managed Kubernetes

- **Principle of Least Privilege:** Grant only the minimum permissions required.
- **Regular Auditing:** Review RBAC policies regularly.
- **Default Service Accounts:** Avoid using the default ServiceAccount for applications; create specific ServiceAccounts with only necessary permissions.
- **Audit Logs:** Enable audit logging in the API server for tracking actions (configure in `/etc/kubernetes/manifests/kube-apiserver.yaml`).
- **Network Policies:** Use NetworkPolicies to control Pod-to-Pod and Pod-to-external communication.
- **Pod Security Standards (PSS):** Enforce Pod security requirements (e.g., restrict privileged containers, host access).
- **Secret Management:** Encrypt etcd at rest, use TLS for in-transit, restrict Secret access via RBAC, and consider external secret managers.
- **Keep Kubernetes Up-to-Date:** Regularly update your cluster for security patches.

---

## 12. Additional Use Cases and Examples

- **Developer Access:** Grant read-only access to pods in a namespace.
- **Application-Specific Permissions:** Allow an app to update only its own ConfigMaps.
- **Team Permissions:** Bind a Role to a group for namespace-scoped access.
- **Cluster Administrator:** Grant cluster-admin ClusterRole to a user for full control.
- **CI/CD Pipelines:** Use ServiceAccounts and ClusterRoleBindings for automation tools.
- **Monitoring Tools:** Grant ClusterRoles for access to nodes and metrics.
- **External Service Integration:** Allow a ServiceAccount to list all Pods for monitoring.
- **Image Pull Secrets:** Attach imagePullSecrets to ServiceAccounts for private registries.

---

## 13. References

- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Kubernetes Service Accounts](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/overview/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Kubernetes Audit Logging](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/)

---


