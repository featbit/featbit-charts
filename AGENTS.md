# FeatBit Helm Chart - Agent Instructions

This Helm chart bootstraps a [FeatBit](https://github.com/featbit/featbit) installation on a [Kubernetes](https://kubernetes.io/) cluster using the [Helm](https://helm.sh/) package manager.

## Prerequisites
* Kubernetes >=1.23
* Helm >= 3.7.0

## System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     FeatBit Platform                     │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐│
│  │    UI    │  │   API    │  │   ELS    │  │DA Server││
│  │  :8081   │  │  :5000   │  │  :5100   │  │         ││
│  └──────────┘  └──────────┘  └──────────┘  └─────────┘│
│       │              │              │            │      │
└───────┼──────────────┼──────────────┼────────────┼──────┘
        │              │              │            │
        └──────────────┴──────────────┴────────────┘
                       │
        ┌──────────────┴──────────────┐
        │   Infrastructure Layer       │
        ├──────────────────────────────┤
        │ PostgreSQL/MongoDB (Primary) │
        │ Redis (Cache)                │
        │ Kafka (Messaging)            │
        │ ClickHouse (Analytics)       │
        └──────────────────────────────┘
```

### Core Components

| Component | Port | Purpose | Critical Config |
|-----------|------|---------|-----------------|
| **ui** | 8081 | Frontend interface | `apiExternalUrl` |
| **api** | 5000 | API server | `apiExternalUrl` |
| **els** | 5100 | Evaluation & sync | `evaluationServerExternalUrl` |
| **da-server** | - | Data analytics | - |

### Deployment Tiers
- **Standard**: Basic deployment with essential components
- **Pro**: Enhanced tier with additional features (`_pro-env.tpl`)

### Database Strategy
- **Primary**: PostgreSQL (default) or MongoDB
- **Cache**: Redis (required)
- **Streaming**: Kafka (optional)
- **Analytics**: ClickHouse (optional)

## File Structure

```
charts/featbit/
├── Chart.yaml              # Chart metadata & dependencies
├── values.yaml             # Default configuration
├── templates/
│   ├── _helpers.tpl        # Shared template functions
│   ├── _*-config.tpl       # Infrastructure configs
│   ├── _*-env.tpl          # Environment variables
│   ├── *-deployment.yaml   # Service deployments
│   ├── *-service.yaml      # Service definitions
│   ├── *-ingress.yaml      # Ingress rules
│   └── *-hpa.yaml          # Auto-scaling
└── examples/
    ├── standard/           # Standard deployment examples
    └── pro/                # Pro tier examples
```

## Configuration Patterns

### Service Exposure (4 Methods)

```yaml
# 1. Ingress (Recommended for production)
<service>.ingress:
  enabled: true
  host: "app.example.com"
  tls:
    enabled: true
    secretName: "tls-secret"

# 2. LoadBalancer (Cloud environments)
<service>.service:
  type: LoadBalancer
  staticIP: "x.x.x.x"  # Or use autoDiscovery: true

# 3. NodePort (Development/testing)
<service>.service:
  type: NodePort
  nodePort: 30025  # Fixed port

# 4. ClusterIP (Internal only)
<service>.service:
  type: ClusterIP
  # Access via kubectl port-forward
```

### Standard Service Configuration

```yaml
<service>:
  replicaCount: 1
  image:
    registry: docker.io
    repository: featbit/<service>
    tag: "5.1.0"
  
  service:
    type: ClusterIP
    port: <port>
  
  resources:
    requests:
      cpu: "250m"
      memory: "256Mi"
  
  autoscaling:
    enabled: false
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 80
```

### Infrastructure Dependencies

```yaml
# Chart.yaml - Define dependencies
dependencies:
  - name: postgresql
    condition: postgresql.enabled
  - name: mongodb
    condition: mongodb.enabled
  - name: redis
    condition: redis.enabled

# values.yaml - Select database
architecture:
  tier: "standard"  # or "pro"
  database: "postgres"  # or "mongodb"
```

## Critical Configuration

### External URLs (REQUIRED for non-localhost)

```yaml
apiExternalUrl: "https://api.featbit.com"
evaluationServerExternalUrl: "https://els.featbit.com"
```

**⚠️ These MUST be set correctly for client SDKs to connect**

### Init Container Dependencies

Services start in order:
1. Infrastructure (DB, Redis, Kafka)
2. Core services (API)
3. Dependent services (UI, ELS, DA)

Controlled by:
- `_initContainers-wait-for-infrastructure-dependencies.tpl`
- `_initContainers-wait-for-other-components.tpl`

### Auto-Discovery (LoadBalancer only)

```yaml
autoDiscovery: true  # Enables automatic IP discovery
# Requires RBAC: auto-discovery-role.yaml + rolebinding
```

## Modifying the Chart

### Adding a New Service

1. **Create template files**:
   - `templates/<service>-deployment.yaml`
   - `templates/<service>-service.yaml`
   - `templates/<service>-ingress.yaml` (optional)

2. **Add to values.yaml**:
   ```yaml
   <service>:
     enabled: true
     replicaCount: 1
     image: {...}
     service: {...}
   ```

3. **Update helpers** (`_helpers.tpl`) if needed

### Modifying Infrastructure

1. **Update dependency** in `Chart.yaml`
2. **Add config template**: `_<infra>-config.tpl`
3. **Add env template**: `_<infra>-env.tpl`
4. **Update init containers** to wait for new dependency

### Example Files

Create in `examples/standard/` or `examples/pro/`:
- `expose-services-via-<method>.yaml`
- `featbit-<variant>.yaml`

## Important Constraints

| Constraint | Impact |
|------------|--------|
| External URLs | MUST be set for production deployments |
| Auto-discovery | Only works with `LoadBalancer` service type |
| Init containers | Enforces startup order, can delay deployment |
| HPA | Requires metrics-server in cluster |
| arm64 support | Requires chart version >= 0.2.1 |
| Min Kubernetes | >= 1.23 |

## Best Practices

1. **Always test with**: `helm template featbit charts/featbit -f values.yaml`
2. **Validate syntax**: `helm lint charts/featbit`
3. **Version updates**: Follow semantic versioning in `Chart.yaml`
4. **External secrets**: Use `*-external-secret.yaml` for sensitive data
5. **Resource limits**: Always set in production deployments
6. **TLS**: Use cert-manager for automatic certificate management

## References

- Main repository: https://github.com/featbit/featbit
- Chart repository: https://github.com/featbit/featbit-charts
- Current version: 0.7.0 (App: 5.1.0)
