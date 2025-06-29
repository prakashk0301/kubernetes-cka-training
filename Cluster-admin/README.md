# Kubernetes Cluster Administration Guide

A comprehensive training guide for Kubernetes cluster administration, covering resource management, Quality of Service (QoS), admission control, and cluster security for Kubernetes 1.32+.

## 📋 Table of Contents

1. [Resource Management](#resource-management)
2. [Quality of Service (QoS)](#quality-of-service-qos)
3. [Resource Quotas](#resource-quotas)
4. [Limit Ranges](#limit-ranges)
5. [Pod Disruption Budgets](#pod-disruption-budgets)
6. [Admission Controllers](#admission-controllers)
7. [Security Policies](#security-policies)
8. [Node Management](#node-management)
9. [Monitoring & Observability](#monitoring--observability)
10. [Troubleshooting](#troubleshooting)

## 🎯 Learning Objectives

After completing this module, you will be able to:
- Configure and manage Kubernetes resource quotas and limits
- Understand and implement QoS classes for pods
- Set up admission controllers and security policies
- Monitor cluster resources and performance
- Troubleshoot cluster-level issues
- Implement best practices for cluster administration

## 🚀 Quick Start

### Prerequisites
- Kubernetes cluster 1.32+ with admin access
- kubectl configured with cluster-admin privileges
- Basic understanding of Kubernetes resources

### Verification Commands
```bash
# Check cluster version and status
kubectl version --short
kubectl cluster-info

# Verify admin permissions
kubectl auth can-i '*' '*' --all-namespaces

# Check node status and resources
kubectl top nodes
kubectl describe nodes
```

## 📚 Resource Management

### Overview
Resource management in Kubernetes ensures optimal utilization of cluster resources while preventing resource starvation and maintaining application performance.

### Key Concepts
- **Requests**: Minimum guaranteed resources
- **Limits**: Maximum allowed resources
- **QoS Classes**: Resource allocation priorities
- **Resource Quotas**: Namespace-level constraints
- **Limit Ranges**: Default and boundary values

### Resource Types
- **CPU**: Measured in millicores (m) or cores
- **Memory**: Measured in bytes (Ki, Mi, Gi, Ti)
- **Storage**: Persistent volume claims
- **Ephemeral Storage**: Container and pod temporary storage
- **Extended Resources**: GPUs, FPGAs, custom resources

## 🏆 Quality of Service (QoS)

### QoS Classes

#### 1. Guaranteed
- All containers have CPU and memory requests and limits
- Requests equal limits for all resources
- Highest priority for scheduling and eviction protection

#### 2. Burstable
- At least one container has CPU or memory requests
- Requests may differ from limits
- Medium priority for scheduling

#### 3. BestEffort
- No CPU or memory requests or limits defined
- Lowest priority for scheduling
- First to be evicted under resource pressure

### QoS Examples
See the following files for practical examples:
- `qos-guaranteed.yaml` - Guaranteed QoS class
- `qos-burstable.yaml` - Burstable QoS class
- `qos-besteffort.yaml` - BestEffort QoS class

## 📊 Resource Quotas

### Types of Quotas
1. **Compute Quotas**: CPU, memory, storage
2. **Object Count Quotas**: Pods, services, secrets
3. **Storage Quotas**: PVCs, storage classes
4. **Extended Resource Quotas**: GPUs, custom resources

### Quota Scopes
- **Terminating**: Pods with activeDeadlineSeconds
- **NotTerminating**: Pods without activeDeadlineSeconds
- **BestEffort**: Pods with BestEffort QoS
- **NotBestEffort**: Pods with Guaranteed or Burstable QoS

### Example Files
- `quota-cpu-memory.yaml` - Basic CPU and memory quotas
- `quota-object-count.yaml` - Object count limitations
- `quota-storage.yaml` - Storage quotas
- `quota-scoped.yaml` - Scoped quotas

## 🎛️ Limit Ranges

### Purpose
- Set default resource requests and limits
- Enforce minimum and maximum constraints
- Control resource ratios

### Types
- **Container**: Individual container limits
- **Pod**: Aggregate pod limits
- **PersistentVolumeClaim**: Storage limits

### Example Files
- `limits.yaml` - Comprehensive limit range
- `limits2.yaml` - Alternative configuration

## 🛡️ Admission Controllers

### Built-in Controllers
- **ResourceQuota**: Enforces resource quotas
- **LimitRanger**: Enforces limit ranges
- **PodSecurityPolicy**: Security policies (deprecated in 1.25+)
- **Pod Security Standards**: New security framework
- **NodeRestriction**: Restricts node permissions

### Custom Admission Controllers
- Validating Admission Webhooks
- Mutating Admission Webhooks
- OPA Gatekeeper policies

## 🔒 Security Policies

### Pod Security Standards
Replaces PodSecurityPolicy in Kubernetes 1.25+:
- **Privileged**: Unrestricted policy
- **Baseline**: Minimally restrictive policy
- **Restricted**: Heavily restricted policy

### Security Context
- Container security settings
- Pod security settings
- File system permissions
- User and group IDs

## 🖥️ Node Management

### Node Conditions
- **Ready**: Node can accept pods
- **DiskPressure**: Node disk usage high
- **MemoryPressure**: Node memory usage high
- **PIDPressure**: Too many processes running
- **NetworkUnavailable**: Network not configured

### Node Operations
- Cordon/Uncordon nodes
- Drain nodes for maintenance
- Add/remove taints and tolerations
- Manage node labels

## 📈 Monitoring & Observability

### Key Metrics
- Resource utilization (CPU, memory, storage)
- Pod scheduling and eviction events
- Quota usage and violations
- Node health and capacity

### Tools
- Kubernetes Dashboard
- Prometheus and Grafana
- kubectl top commands
- Cluster monitoring solutions

## 🔧 Troubleshooting

### Common Issues
1. **Pod Evictions**: Resource pressure, disk pressure
2. **Scheduling Failures**: Resource constraints, taints
3. **Quota Violations**: Exceeded namespace limits
4. **Performance Issues**: Resource contention

### Debugging Commands
```bash
# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Describe resources for events
kubectl describe node <node-name>
kubectl describe pod <pod-name>

# Check quotas and limits
kubectl describe quota --all-namespaces
kubectl describe limitrange --all-namespaces

# View events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

## 🧪 Hands-on Labs

### Lab 1: Resource Quotas
1. Create namespace with resource quota
2. Deploy pods within quota limits
3. Attempt to exceed quota and observe behavior

### Lab 2: QoS Classes
1. Create pods with different QoS classes
2. Simulate resource pressure
3. Observe eviction order

### Lab 3: Limit Ranges
1. Configure default limits
2. Deploy pods without resource specifications
3. Verify automatic limit assignment

### Lab 4: Pod Disruption Budgets
1. Create PDB for critical applications
2. Drain node with running pods
3. Verify PDB enforcement

### Lab 5: Admission Control
1. Configure admission webhooks
2. Test policy enforcement
3. Validate resource constraints

## 📖 Best Practices

### Resource Management
- Always set resource requests for production workloads
- Use appropriate QoS classes based on workload criticality
- Monitor resource utilization regularly
- Plan for peak usage patterns

### Security
- Enable Pod Security Standards
- Use least privilege principles
- Regular security audits
- Network policy enforcement

### Operations
- Implement monitoring and alerting
- Regular cluster health checks
- Backup and disaster recovery plans
- Documentation and runbooks

## 🔗 Related Documentation

- [Official Kubernetes Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Quality of Service Classes](https://kubernetes.io/docs/concepts/workloads/pods/pod-qos/)
- [Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)

## 🎓 Certification Notes

### CKA Exam Topics Covered
- Cluster maintenance and troubleshooting
- Resource management and optimization
- Security policy implementation
- Monitoring and logging

### Key Commands for Exam
```bash
# Resource management
kubectl top nodes/pods
kubectl describe quota/limitrange
kubectl get events

# Node operations
kubectl cordon/uncordon <node>
kubectl drain <node>
kubectl taint nodes <node> <taint>

# Security
kubectl get psp/podsecuritypolicy
kubectl auth can-i <verb> <resource>
```

---

**Happy Learning! 🚀**

For questions and support, refer to the [Kubernetes documentation](https://kubernetes.io/docs/) or community forums.
