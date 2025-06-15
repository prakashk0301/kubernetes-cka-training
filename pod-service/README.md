# Kubernetes Pod Manifest and Networking Essentials

## 📄 Pod Manifest Basics

A Pod is the smallest deployable unit in Kubernetes, encapsulating one or more containers, shared storage, and network resources, and a specification for how to run the containers.

### 🔹 Example: `my-pod.yml`
```yaml
apiVersion: v1 # API version for Pod is always 'v1'
kind: Pod      # Declaring the resource kind as Pod
metadata:      # Metadata provides data about the object
  name: nginx  # Pod name
spec:          # Specifications of the Pod
  containers:
  - name: nginx        # Container name
    image: nginx:1.14.2 # Docker image
    ports:
    - containerPort: 80 # Application port exposed by the container
```

## 🚀 Apply the Manifest

To create the Pod defined in `my-pod.yml`, use the following command:

```bash
kubectl apply -f my-pod.yml
```

## 🧠 Understanding `apiVersion`

The `apiVersion` field specifies the version of the Kubernetes API you're using to create the object. It dictates how the Kubernetes API Server will interpret the object's definition. Different resource types belong to different API groups and versions.

| Resource Type               | Kind                    | API Version                   |
|-----------------------------|-------------------------|-------------------------------|
| Pod                         | Pod                     | v1                            |
| Deployment                  | Deployment              | apps/v1                       |
| Service                     | Service                 | v1                            |
| Ingress                     | Ingress                 | networking.k8s.io/v1          |
| Role                        | Role                    | rbac.authorization.k8s.io/v1  |
| ClusterRoleBinding          | ClusterRoleBinding      | rbac.authorization.k8s.io/v1  |
| HorizontalPodAutoscaler     | HorizontalPodAutoscaler | autoscaling/v2                |

## 🌐 Pod Networking and Services

Pods in a Kubernetes cluster can communicate with each other using their internal IP addresses. However, to expose a Pod (or a set of Pods) externally or internally using a stable DNS name, a Service is required.

### 🔹 Example: `my-service.yml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector: # Must match the labels defined in the Pods you want to expose
    name: MyApp
    env: prod
    app: web
  ports:
    - protocol: TCP
      port: 80       # Port exposed by the service
      targetPort: 80 # Port on the container that the service will forward traffic to
  type: NodePort     # Other options: ClusterIP, LoadBalancer, ExternalName
```
> **NodePort** exposes the service on a static port (in the range 30000–32767) on each Node's IP address. This makes the service accessible from outside the cluster using `<NodeIP>:<NodePort>`.

## ⚙️ Imperative Method: Command Line Based Resource Creation (Not Recommended for Production)

While YAML manifests (declarative method) are highly recommended for production environments due to their version control and reusability benefits, you can quickly create resources using imperative commands for testing or quick deployments.

### Creating a Pod Imperatively
```bash
kubectl run <pod-name> --image=<docker image name> [--port=<container-port>] [--labels="key1=value1,key2=value2"]

# Example:
kubectl run k21-nginx-pod --image=nginx:1.14.2 --port=80 --labels="app=nginx,env=dev"
```
This command creates a Pod named `k21-nginx-pod` using the `nginx:1.14.2` image, exposing port 80, and applying the labels `app=nginx` and `env=dev`.

### Creating a Service Imperatively
```bash
kubectl expose pod <pod name> --port=<app port> --target-port=<pod port> --name=<service name> --type=<service type>

# Example (ClusterIP - internal access):
kubectl expose pod k21-nginx-pod --port=80 --target-port=80 --name=k21-clusterip-service --type=ClusterIP

# Example (NodePort - external access via NodeIP:NodePort):
kubectl expose pod k21-nginx-pod --port=80 --target-port=80 --name=k21-nodeport-service --type=NodePort

# Example (LoadBalancer - external access via Cloud Load Balancer):
kubectl expose pod k21-nginx-pod --port=80 --target-port=80 --name=k21-loadbalancer-service --type=LoadBalancer
```

#### Service Types Explained
- **ClusterIP (Default):** Exposes the Service on an internal IP in the cluster. It's only reachable from within the cluster. This is the default Service type if you don't specify one.
- **NodePort:** Exposes the Service on a static port on each Node's IP. This makes the Service accessible from outside the cluster using `<NodeIP>:<NodePort>`. The port range for NodePort is typically 30000−32767.
- **LoadBalancer:** Exposes the Service externally using a cloud provider's load balancer (e.g., AWS ELB, Azure Load Balancer, Google Cloud Load Balancer). The cloud provider dynamically provisions a load balancer that routes external traffic to your Service.

## 📋 Viewing Resources

- **Get Pods:**
  ```bash
  kubectl get pod
  ```
- **Get Services:**
  ```bash
  kubectl get service
  ```
- **Describe a Resource (Detailed Information):**
  ```bash
  kubectl describe <resource-type> <resource-name>
  # Example:
  kubectl describe pod k21-nginx-pod
  kubectl describe service k21-nodeport-service
  ```
  This command provides detailed information about a specific resource, including its status, events, labels, and associated resources.

---

### 📦 What is a Pod?

A Pod is the smallest deployable unit in Kubernetes. It represents a single instance of a running process in your cluster. A Pod can contain:

- **One Primary Container:** The main application container.
- **One or Many Helping/Sidecar Containers:** Containers that support the primary application (e.g., log shippers, data synchronizers, proxy agents).
- **Init Containers:** Containers that run to completion before the application containers start, often used for setup or initialization tasks.

Containers within the same Pod share:
- **Network Namespace:** They share the same IP address and port space, allowing them to communicate via `localhost`.
- **Storage Volumes:** They can share mounted volumes to exchange data.

---

## 🏠 Namespaces: Virtual Clusters within a Physical Cluster

Namespaces provide a way to divide cluster resources among multiple users or teams. They are like virtual clusters residing within a single physical Kubernetes cluster. Namespaces help with:

- **Environment Segregation:** Separating development, QA, and production environments.
- **Team Isolation:** Providing dedicated spaces for different teams.
- **Application Grouping:** Organizing resources related to specific applications (e.g., internet banking, payment systems).

### Default Namespaces
- `default`: Reserved for user-created applications if no specific namespace is provided.
- `kube-system`: Reserved for resources created and managed by Kubernetes itself (e.g., etcd, kube-api-server, kube-proxy, scheduler).
  ```bash
  kubectl get pod -n kube-system
  ```
- `kube-node-lease`: Used to improve the performance of node heartbeats, especially in large clusters. It stores Lease objects for each node, indicating their health.
  ```bash
  kubectl get lease -n kube-node-lease
  ```
- `kube-public`: Contains publicly readable data, such as cluster information, accessible to all users.

### Custom Namespaces
- **Create a Custom Namespace:**
  ```bash
  kubectl create namespace <namespace name>
  # Example:
  kubectl create namespace qa
  ```
- **Create a Pod in a Specific Namespace:**
  ```bash
  kubectl run <pod-name> --image=<docker image> -n <namespace>
  # Example:
  kubectl run k21-pod-app2 --image=nginx:1.14.2 -n qa
  ```
- **View Resources in a Specific Namespace:**
  ```bash
  kubectl get <resource-type> -n <namespace>
  # Example:
  kubectl get pod -n qa
  kubectl get service -n qa
  ```

## 📝 How to Edit Deployed State (Modify Live Resources)

You can modify the configuration of a deployed Pod, Deployment, or Service directly using the `kubectl edit` command. This opens the resource's YAML definition in your default text editor, allowing you to make changes.

```bash
kubectl edit <resource-type> <name> [-n <namespace>]

# Example (edit a Pod in the 'qa' namespace):
kubectl edit pod k21-pod-app2 -n qa

# Example (edit a Service in the default namespace):
kubectl edit service k21-nodeport-service
```
> **Caution:** Editing resources directly can lead to inconsistencies if not managed carefully, especially in production environments. For production, it's generally recommended to update your YAML manifest files and then apply them (`kubectl apply -f <file.yml>`), as this approach is more declarative and version-controlled.

## 🗑️ Delete Namespace

Deleting a namespace will delete all resources within that namespace.

```bash
kubectl delete namespace <namespace name>
# Example:
kubectl delete namespace qa
```

## 📊 Monitoring Resources with Metrics Server

The Metrics Server is a cluster-wide aggregator of resource usage data. It collects CPU and memory metrics from nodes and pods, which are then used by tools like `kubectl top` and horizontal Pod autoscaling.

- **Deploy the Metrics Server:**
  ```bash
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
  ```

- **Memory/CPU Calculation (View Resource Usage):**

  After deploying the Metrics Server, you can use `kubectl top` to view resource usage for nodes and pods.

  - **Top Pods:**
    ```bash
    kubectl top pod [-n <namespace>]
    # Example (view CPU/Memory for k21-pod-app2 in 'qa' namespace):
    kubectl top pod k21-pod-app2 -n qa
    ```
  - **Top Nodes:**
    ```bash
    kubectl top node
    ```

## 🔄 Restarting a Pod

It's important to understand that Pods themselves are not directly "restarted" by Kubernetes in the traditional sense. If a Pod crashes or completes its task, it's gone. Kubernetes' strength lies in its controllers (like Deployments, StatefulSets, DaemonSets) that manage Pods.

- **If a Pod is part of a Deployment:** The Deployment controller will automatically create a new Pod to replace a failed one, ensuring the desired number of replicas is maintained. To "restart" a Pod managed by a Deployment, you would typically update the Deployment (e.g., change an environment variable, update the image), which triggers a rolling update and creates new Pods.
- **If a Pod is standalone (created directly with `kubectl run` or a Pod manifest without a controller):** If it dies, it will not be recreated. You would need to manually create it again.

## 🧪 Multi-Container Pods

You can define multiple containers within a single Pod's `spec.containers` array. These containers share the Pod's network namespace and can access shared volumes.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-pod
spec:
  containers:
  - name: primary-app
    image: my-app:1.0
    ports:
    - containerPort: 8080
  - name: sidecar-logger
    image: fluentd:latest # Example: a sidecar for logging
    volumeMounts:
    - name: app-logs
      mountPath: /var/log/app
  volumes:
  - name: app-logs
    emptyDir: {} # A temporary volume for sharing logs
```

## 🚪 Exposing Applications (Service Types Recap)

- **ClusterIP (Default):** Provides an internal IP address for the Service. Useful for inter-service communication within the cluster.
- **NodePort:** Exposes the Service on a specific port on each Node's IP. Allows external access to the Service via any Node's IP and the assigned NodePort.
- **LoadBalancer:** Integrates with cloud provider load balancers to expose the Service externally. Provides a highly available and scalable entry point for external traffic.
- **ExternalName:** Maps the Service to the contents of the `externalName` field (e.g., `my.database.example.com`) by returning a CNAME record. Useful for accessing external services within the cluster using a consistent DNS name.

## 🔗 Useful References

- [Kubernetes Pods](https://kubernetes.io/docs/concepts/workloads/pods/)
- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Software release life cycle](https://en.wikipedia.org/wiki/Software_release_life_cycle)