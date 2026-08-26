#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
chart_directory="${repository_root}/charts/featbit"
release_name="clickhouse-password-test"

deployment_templates=(
  --show-only templates/api-deployment.yaml
  --show-only templates/eval-server-deployment.yaml
  --show-only templates/da-server-deployment.yaml
)

# ClickHouse is only wired up for the professional tier, which also requires Kafka.
professional_values=(
  --set architecture.tier=professional
  --set kafka.enabled=true
  --set-string apiExternalUrl=https://api.example.com
  --set-string evaluationServerExternalUrl=https://els.example.com
)

external_clickhouse_values=(
  --set clickhouse.enabled=false
  --set-string externalClickhouse.host=clickhouse.example.com
  --set-string externalClickhouse.cluster=featbit_ch_cluster
  --set-string externalClickhouse.user=featbit
)

rendered=""

render_case() {
  local case_name="$1"
  shift

  echo "Rendering ${case_name}..."
  rendered="$(helm template "${release_name}" "${chart_directory}" "${deployment_templates[@]}" "${professional_values[@]}" "$@")"
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

# The API and evaluation server each render the ClickHouse variables once, in the
# infrastructure wait initContainer. The data analytics server renders them twice:
# once in that initContainer and once in its application container.
assert_user_environment_present() {
  assert_line_count 4 "- name: CLICKHOUSE_USER"
}

assert_password_environment_present() {
  assert_line_count 4 "- name: CLICKHOUSE_PASSWORD"
}

assert_password_environment_absent() {
  assert_line_count 0 "- name: CLICKHOUSE_PASSWORD"
}

assert_password_secret_reference() {
  local secret_name="$1"
  local secret_key="$2"

  assert_line_count 4 "name: ${secret_name}"
  assert_line_count 4 "key: ${secret_key}"
}

render_case "bundled ClickHouse with default authentication" \
  --set clickhouse.enabled=true
assert_user_environment_present
assert_password_environment_present
assert_password_secret_reference "${release_name}-featbit-clickhouse" "admin-password"

render_case "bundled ClickHouse with an existing Secret" \
  --set clickhouse.enabled=true \
  --set-string clickhouse.auth.existingSecret=bundled-clickhouse-secret \
  --set-string clickhouse.auth.existingSecretKey=clickhouse-password
assert_user_environment_present
assert_password_environment_present
assert_password_secret_reference "bundled-clickhouse-secret" "clickhouse-password"

render_case "external ClickHouse with an inline password" \
  "${external_clickhouse_values[@]}" \
  --set-string externalClickhouse.password=s3cret
assert_user_environment_present
assert_password_environment_present
assert_password_secret_reference "${release_name}-featbit-clickhouse-external" "admin-password"

render_case "external ClickHouse with an existing Secret" \
  "${external_clickhouse_values[@]}" \
  --set-string externalClickhouse.existingSecret=external-clickhouse-secret \
  --set-string externalClickhouse.existingSecretKey=application-password
assert_user_environment_present
assert_password_environment_present
assert_password_secret_reference "external-clickhouse-secret" "application-password"

render_case "external ClickHouse with credentials supplied outside the chart" \
  "${external_clickhouse_values[@]}"
assert_user_environment_present
assert_password_environment_absent
assert_line_count 0 "name: ${release_name}-featbit-clickhouse-external"

echo "All ClickHouse password rendering tests passed."
