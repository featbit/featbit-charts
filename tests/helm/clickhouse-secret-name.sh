#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
chart_directory="${repository_root}/charts/featbit"
release_name="clickhouse-secret-test"

templates=(
  --show-only templates/api-deployment.yaml
  --show-only templates/clickhouse-external-secret.yaml
)

# Every Bitnami sub-chart is disabled, so the Bitnami common library templates are not loaded.
external_infrastructure_values=(
  --set-string architecture.tier=professional
  --set postgresql.enabled=false
  --set redis.enabled=false
  --set kafka.enabled=false
  --set clickhouse.enabled=false
  --set-string "externalPostgresql.hosts[0]=db.example.com:5432"
  --set-string "externalRedis.hosts[0]=redis.example.com:6379"
  --set-string "externalKafka.brokers.producer.hosts[0]=kafka.example.com:9092"
  --set-string "externalKafka.brokers.consumer.hosts[0]=kafka.example.com:9092"
  --set-string externalClickhouse.httpEndpoint=https://clickhouse.example.com:8443
  --set-string externalClickhouse.user=default
)

rendered=""

render_case() {
  local case_name="$1"
  shift

  echo "Rendering ${case_name}..."
  rendered="$(helm template "${release_name}" "${chart_directory}" "$@")"
}

count_line() {
  local expected_line="$1"
  local count

  count="$(printf '%s\n' "${rendered}" | sed -e 's/\r$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -Fxc -- "${expected_line}" || true)"
  printf '%s' "${count}"
}

assert_line_count() {
  local expected_count="$1"
  local expected_line="$2"
  local actual_count

  actual_count="$(count_line "${expected_line}")"
  if [[ "${actual_count}" -ne "${expected_count}" ]]; then
    echo "Expected ${expected_count} occurrence(s) of '${expected_line}', found ${actual_count}." >&2
    exit 1
  fi
}

render_case "external ClickHouse with an inline password" \
  "${templates[@]}" \
  "${external_infrastructure_values[@]}" \
  --set-string externalClickhouse.password=test-password
assert_line_count 1 "name: ${release_name}-featbit-clickhouse-external"
assert_line_count 1 "name: \"${release_name}-featbit-clickhouse-external\""
assert_line_count 1 "key: \"admin-password\""

render_case "external ClickHouse with an existing Secret" \
  --show-only templates/api-deployment.yaml \
  "${external_infrastructure_values[@]}" \
  --set-string externalClickhouse.existingSecret=external-clickhouse-secret \
  --set-string externalClickhouse.existingSecretKey=password
assert_line_count 1 "name: \"external-clickhouse-secret\""
assert_line_count 1 "key: \"password\""

render_case "external ClickHouse with a fullnameOverride" \
  "${templates[@]}" \
  "${external_infrastructure_values[@]}" \
  --set-string clickhouse.fullnameOverride=custom-clickhouse \
  --set-string externalClickhouse.password=test-password
assert_line_count 1 "name: custom-clickhouse-external"
assert_line_count 1 "name: \"custom-clickhouse-external\""

echo "All ClickHouse secret name rendering tests passed."
