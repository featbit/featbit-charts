---
name: upgrade-chart
description: "Upgrade FeatBit Helm chart version with migration checks"
tools: ["read_file", "grep_search", "run_in_terminal"]
agent: edit
---

# Upgrade FeatBit Helm Chart

Follow this checklist to upgrade the chart safely:

## 1. Check Migration Scripts
- Read `migration/RELEASE-v${input:targetVersion:0.9.1}.md`
- Verify database schema changes required
- **CRITICAL**: Share migration scripts with DBA team for manual execution

## 2. Update Chart Version
- Update `Chart.yaml`:
  - `version`: ${input:chartVersion}
  - `appVersion`: ${input:appVersion}

## 3. Test Changes
```bash
# Lint chart
helm lint charts/featbit

# Test rendering
helm template featbit charts/featbit -f charts/featbit/examples/aks/featbit-aks-values.local.yaml

# Dry-run upgrade
helm upgrade featbit charts/featbit --dry-run -f <values-file>
```

## 4. Execute Upgrade
```bash
# Update repo
helm repo update featbit

# Upgrade release
helm upgrade <release-name> featbit/featbit -f <values-file>

# Verify deployment
kubectl get pods -w
```

## Pre-requisites Checklist
- [ ] Migration scripts reviewed by DBA
- [ ] Database backup completed
- [ ] Rollback plan prepared
- [ ] External URLs configured correctly
- [ ] External managed services validated (if production)
