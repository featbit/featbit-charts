---
name: add-service
description: "Add a new service to FeatBit Helm chart"
tools: ["read_file", "create_file", "grep_search"]
agent: edit
---

# Add New Service to FeatBit

Generate templates for a new service: **${input:serviceName:my-service}**

## 1. Create Service Templates

Generate these files in `charts/featbit/templates/`:

### `${serviceName}-deployment.yaml`
- Use existing service deployments as reference (api-deployment.yaml, els-deployment.yaml)
- Include:
  - Init containers for infrastructure dependencies (if needed)
  - Resource requests/limits
  - Health checks (liveness/readiness probes)
  - Environment variables from `_helpers.tpl`

### `${serviceName}-service.yaml`
- Service type: ClusterIP (default)
- Port configuration
- Selector labels

### `${serviceName}-ingress.yaml` (optional)
- Enable with condition: `{{- if .Values.${serviceName}.ingress.enabled }}`
- Use `global.ingressClassName`
- Support TLS configuration

### `${serviceName}-hpa.yaml` (optional)
- Enable with condition: `{{- if .Values.${serviceName}.autoscaling.enabled }}`
- Target CPU/Memory utilization

## 2. Update values.yaml

Add service configuration block:
```yaml
${serviceName}:
  enabled: true
  replicaCount: 1
  image:
    registry: docker.io
    repository: featbit/${serviceName}
    tag: "5.2.1"
    pullPolicy: IfNotPresent
  
  service:
    type: ClusterIP
    port: ${input:servicePort:8080}
  
  resources:
    requests:
      cpu: "250m"
      memory: "256Mi"
    limits:
      cpu: "1000m"
      memory: "1Gi"
  
  autoscaling:
    enabled: false
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 80
  
  ingress:
    enabled: false
    host: ""
    annotations: {}
    tls:
      enabled: false
      secretName: ""
```

## 3. Update _helpers.tpl

Add helper templates if needed:
- Service name: `{{- define "featbit.${serviceName}.fullname" -}}`
- Labels: `{{- define "featbit.${serviceName}.labels" -}}`
- Selector: `{{- define "featbit.${serviceName}.selectorLabels" -}}`

## 4. Validation

```bash
# Lint chart
helm lint charts/featbit

# Test rendering
helm template featbit charts/featbit -f values.yaml

# Check generated manifests
helm template featbit charts/featbit | grep -A 10 "kind: Deployment" | grep ${serviceName}
```

## Dependencies Checklist
- [ ] Does service need database? → Update init containers
- [ ] Does service need Redis/Kafka? → Add environment variables
- [ ] Does service need external URL? → Add to Critical Configuration
- [ ] Is this for Pro tier only? → Wrap with `{{- if eq .Values.architecture.tier "pro" }}`
