#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
chart_directory="${repository_root}/charts/featbit"
rendered=""
script=""

assert_contains() {
  if ! grep -Fq -- "$2" <<< "$1"; then
    echo "Expected rendered initialization script to contain: $2" >&2
    exit 1
  fi
}

extract_script_after() {
  local previous_key="$1"
  local current_key="$2"
  local previous_line current_line
  previous_line="$(grep -nF "  ${previous_key}: |-" <<< "${rendered}" | cut -d: -f1)"
  current_line="$(grep -nF "  ${current_key}: |-" <<< "${rendered}" | cut -d: -f1)"
  if [[ "${current_line}" -le "${previous_line}" ]]; then
    echo "${current_key} must run after ${previous_key}." >&2
    exit 1
  fi
  script="$(awk -v key="${current_key}" '
    $0 == "  " key ": |-" { active = 1; next }
    active && /^  [^ ]/ { exit }
    active { print }
  ' <<< "${rendered}")"
}

for database_name in featbit customer-db; do
  echo "Checking PostgreSQL v6.1.0 initialization for ${database_name}..."
  rendered="$(helm template init-scripts-test "${chart_directory}" \
    --show-only templates/postgresql-init-scripts-configmap.yaml \
    --set-string "postgresql.auth.database=${database_name}" | sed 's/\r$//')"
  extract_script_after 12_v6.0.0.sql 13_v6.1.0.sql
  assert_contains "${script}" "\connect \"${database_name}\""
  assert_contains "${script}" 'ADD COLUMN IF NOT EXISTS insights_enabled boolean NOT NULL DEFAULT true'
  assert_contains "${script}" 'UPDATE policies p'
  assert_contains "${script}" 'UPDATE access_tokens t'
  assert_contains "${script}" 'ViewEnvSecret'
  assert_contains "${script}" 'ALTER TABLE audit_logs ALTER COLUMN env_id DROP NOT NULL'
  assert_contains "${script}" 'ix_audit_logs_workspace_id_organization_id_created_at_id'

  echo "Checking MongoDB v6.1.0 initialization for ${database_name}..."
  rendered="$(helm template init-scripts-test "${chart_directory}" \
    -f "${chart_directory}/examples/standard/featbit-standard-local-mongo.yaml" \
    --show-only templates/mongodb-init-scripts-configmap.yaml \
    --set-string "mongodb.userDatabase.name=${database_name}" | sed 's/\r$//')"
  extract_script_after 11_v6.0.0.js 12_v6.1.0.js
  assert_contains "${script}" "const dbName = \"${database_name}\";"
  assert_contains "${script}" 'db = db.getSiblingDB(dbName);'
  assert_contains "${script}" 'db.Policies.find('
  assert_contains "${script}" 'db.AccessTokens.find('
  assert_contains "${script}" 'ViewEnvSecret'
  assert_contains "${script}" 'db.AuditLogs.aggregate('
  assert_contains "${script}" 'db.AuditLogs.createIndex('
done

echo "Checking that external databases have no bundled initialization ConfigMaps..."
rendered="$(helm template init-scripts-test "${chart_directory}" \
  --set postgresql.enabled=false,redis.enabled=false \
  --set-string 'externalPostgresql.hosts[0]=db.example.com:5432' \
  --set-string 'externalRedis.hosts[0]=redis.example.com:6379')"
if grep -Eq 'name: featbit-(postgresql|mongodb)-init-scripts-configmap' <<< "${rendered}"; then
  echo "External databases must not render bundled initialization ConfigMaps." >&2
  exit 1
fi

echo "All v6.1.0 initialization rendering tests passed."
