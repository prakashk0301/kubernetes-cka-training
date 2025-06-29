# Kubernetes CustomResourceDefinition (CRD)

## What is a CRD?
A **CustomResourceDefinition (CRD)** allows you to extend Kubernetes by defining your own resource types. With CRDs, you can create, manage, and interact with custom objects just like built-in Kubernetes resources (e.g., Pods, Services).

---

## Purpose
- Enable Kubernetes-native management of custom application configurations or domain-specific objects.
- Allow teams to define APIs tailored to their needs, using Kubernetes as a platform.

---

## Use Case
- Operator pattern: Automate complex application management (e.g., databases, message queues) using custom controllers and CRDs.
- Platform engineering: Expose custom APIs for internal tools or workflows.
- Third-party integrations: Vendors can provide Kubernetes-native APIs for their products.

---

## When to Use a CRD
- When you need to manage custom resources declaratively in Kubernetes.
- When you want to build controllers/operators that automate lifecycle of non-standard resources.
- When extending Kubernetes without modifying its core codebase.

**Do NOT use a CRD if:**
- Your use case is already covered by built-in resources.
- You only need simple configuration (use ConfigMap or Secret instead).

---

## Enhanced Widget CRD Example

The updated CRD includes modern best practices for Kubernetes 1.32+:

### Features Added:
- ✅ **Validation Schema** - Enum values and pattern matching
- ✅ **Required Fields** - Enforced validation
- ✅ **Status Subresource** - Proper status handling
- ✅ **Scale Subresource** - HPA support
- ✅ **Additional Printer Columns** - Better kubectl output
- ✅ **Proper Labels** - Following k8s conventions

### Validation Features:
- **Size**: Only allows "small", "medium", "large"
- **Color**: Pattern validation for specific colors
- **Replicas**: Integer with min/max constraints
- **Status Phase**: Enum for lifecycle states

---

## Deploying and Testing the CRD

### 1. Apply the CRD
```bash
kubectl apply -f crd-example.yaml
```

### 2. Verify CRD Creation
```bash
# Check if CRD is created
kubectl get crd widgets.example.com

# Get detailed information
kubectl describe crd widgets.example.com

# List all CRDs
kubectl get crd
```

### 3. Create Custom Resource Instances

**Valid Widget Example:**
```yaml
apiVersion: example.com/v1
kind: Widget
metadata:
  name: my-widget
  namespace: default
spec:
  size: "medium"
  color: "blue"
  replicas: 3
  enabled: true
```

**Apply the Widget:**
```bash
kubectl apply -f - <<EOF
apiVersion: example.com/v1
kind: Widget
metadata:
  name: my-widget
  namespace: default
spec:
  size: "medium"
  color: "blue"
  replicas: 3
  enabled: true
EOF
```

### 4. Manage Custom Resources
```bash
# List widgets
kubectl get widgets
kubectl get wdgt  # using short name

# Get detailed widget information
kubectl describe widget my-widget

# Edit widget
kubectl edit widget my-widget

# Delete widget
kubectl delete widget my-widget
```

---

## Validation Testing

### Test Valid Values
```bash
# Test with valid size and color
kubectl apply -f - <<EOF
apiVersion: example.com/v1
kind: Widget
metadata:
  name: valid-widget
spec:
  size: "large"
  color: "red"
  replicas: 5
EOF
```

### Test Invalid Values (Should Fail)
```bash
# Test with invalid size (should fail)
kubectl apply -f - <<EOF
apiVersion: example.com/v1
kind: Widget
metadata:
  name: invalid-widget
spec:
  size: "extra-large"  # Not in enum
  color: "red"
EOF

# Test with invalid color (should fail)
kubectl apply -f - <<EOF
apiVersion: example.com/v1
kind: Widget
metadata:
  name: invalid-color-widget
spec:
  size: "small"
  color: "pink"  # Not matching pattern
EOF

# Test with missing required fields (should fail)
kubectl apply -f - <<EOF
apiVersion: example.com/v1
kind: Widget
metadata:
  name: incomplete-widget
spec:
  replicas: 2
  # Missing required size and color
EOF
```

---

## Status Subresource Example

When you have a controller managing widgets, it can update the status:

```yaml
# Example of widget with status (typically set by controller)
apiVersion: example.com/v1
kind: Widget
metadata:
  name: widget-with-status
spec:
  size: "medium"
  color: "green"
  replicas: 2
status:
  phase: "Running"
  observedGeneration: 1
  conditions:
    - type: "Ready"
      status: "True"
      lastTransitionTime: "2024-12-29T10:00:00Z"
      reason: "AllReplicasReady"
      message: "All widget replicas are ready"
```

---

## Scale Subresource Example

With the scale subresource, you can use kubectl scale:

```bash
# Scale widget replicas
kubectl scale widget my-widget --replicas=5

# Check scaling
kubectl get widget my-widget -o jsonpath='{.spec.replicas}'
```

---

## Advanced CRD Features

### OpenAPI Schema Validation
The enhanced CRD includes comprehensive validation:
- **Type validation** (string, integer, boolean)
- **Enum constraints** for predefined values
- **Pattern matching** using regex
- **Range validation** (minimum/maximum)
- **Required fields** enforcement

### Custom Printer Columns
The CRD defines custom columns for better `kubectl get` output:
```bash
kubectl get widgets
# Output shows: NAME, SIZE, COLOR, REPLICAS, PHASE, AGE
```

### Categories
The widget is included in the "all" category:
```bash
kubectl get all  # Will include widgets
```

---

## Cleanup

```bash
# Delete all widget instances
kubectl delete widgets --all

# Delete the CRD (this will also delete all instances)
kubectl delete crd widgets.example.com
```

---

## Best Practices

### 1. Naming Conventions
- Use clear, descriptive names
- Follow DNS naming conventions
- Include organization domain in group name

### 2. Versioning
- Start with v1 for production-ready APIs
- Use v1alpha1, v1beta1 for experimental features
- Plan version migration strategies

### 3. Validation
- Always include comprehensive validation schemas
- Use required fields appropriately
- Provide clear error messages through validation

### 4. Status Management
- Use status subresource for operational state
- Include conditions for detailed status information
- Separate spec (desired) from status (observed)

### 5. Documentation
- Include descriptions in schema properties
- Use examples and comments
- Maintain API documentation

---

## Real-World Examples

### Database CRD
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databases.db.example.com
spec:
  group: db.example.com
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required: ["type", "storage"]
            properties:
              type:
                type: string
                enum: ["mysql", "postgresql", "mongodb"]
              storage:
                type: string
                pattern: "^[0-9]+Gi$"
              backup:
                type: object
                properties:
                  enabled:
                    type: boolean
                  schedule:
                    type: string
  scope: Namespaced
  names:
    plural: databases
    singular: database
    kind: Database
```

### Application CRD
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: applications.app.example.com
spec:
  group: app.example.com
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required: ["image", "replicas"]
            properties:
              image:
                type: string
              replicas:
                type: integer
                minimum: 1
                maximum: 100
              environment:
                type: object
                additionalProperties:
                  type: string
  scope: Namespaced
  names:
    plural: applications
    singular: application
    kind: Application
```

---

## References
- [Kubernetes CRD Documentation](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/)
- [Kubernetes Operator Pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)
- [OpenAPI v3 Schema](https://swagger.io/specification/)
- [Kubernetes API Conventions](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md)
