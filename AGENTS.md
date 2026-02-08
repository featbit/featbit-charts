---
applyTo: "**"
---
# FeatBit Helm Chart - Project Rules

## Tech Stack
- Kubernetes >= 1.23
- Helm >= 3.7.0
- App Version: 5.2.2 (Chart: 0.9.2)

## Architecture

**4 Core Services:**
- `ui` (8081) - Frontend
- `api` (5000) - API server  
- `els` (5100) - Evaluation server
- `da-server` - Analytics

**Infrastructure:**
- DB: PostgreSQL (default) or MongoDB
- Cache: Redis (required)
- Optional: Kafka, ClickHouse

**Tiers:** `standard` | `pro`

## File Structure

```
charts/featbit/
├── Chart.yaml              # Dependencies
├── values.yaml             # Default config
├── templates/
│   ├── _*-config.tpl       # Infra configs
│   ├── _*-env.tpl          # Environment vars
│   └── *.yaml              # K8s resources
└── examples/               # Sample deployments
```

## Deployment Rules

**AKS:**
- Values file: `charts/featbit/examples/aks/featbit-aks-values.local.yaml`
- Follow README.md for chart updates

**Local Docker K8s:**
- Use: `values.yaml` with local charts

## Tool Usage

**Azure Operations:**
When working with Azure services, always attempt to use these MCP servers:
- `azure/aks-mcp` - For Azure Kubernetes Service operations
- `com.microsoft/azure` - For general Azure resource management
- `microsoftdocs/mcp` - For Microsoft Learn documentation

## Critical Configuration

⚠️ **External URLs (REQUIRED for production):**
```yaml
apiExternalUrl: "https://api.featbit.com"
evaluationServerExternalUrl: "https://els.featbit.com"
```
**Without these, client SDKs cannot connect.**

## Constraints

- External URLs mandatory for production
- Database migrations NOT auto-executed - check `migration/RELEASE-v{version}.md` before upgrade
- Production MUST use external managed services (PostgreSQL/MongoDB, Redis, Kafka, ClickHouse)
- Built-in Bitnami dependencies for dev/test only
- HPA requires metrics-server
- Auto-discovery only with LoadBalancer type

---
**Repository:** https://github.com/featbit/featbit-charts
