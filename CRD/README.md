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

## Example: Widget CRD

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: widgets.example.com
spec:
  group: example.com
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
              properties:
                size:
                  type: string
                color:
                  type: string
  scope: Namespaced
  names:
    plural: widgets
    singular: widget
    kind: Widget
    shortNames:
    - wdgt
```

---

## References
- [Kubernetes CRD Documentation](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/)
- [Kubernetes Operator Pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)
