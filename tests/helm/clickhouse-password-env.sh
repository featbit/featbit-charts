#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
chart_directory="${repository_root}/charts/featbit"
release_name="clickhouse-password-test"

deployment_templates=(
  --show-only templates/api-deployment.yaml
  --show-only templates/eval-server-deployment.yaml
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
  --set-string externalClickhouse.httpEndpoint=https://clickhouse.example.com:8443
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

# Bundled ClickHouse uses uppercase variables in the API and evaluation server's
# startup waits. External ClickHouse skips those waits and their environment variables.
# The API renders its .NET ClickHouse settings in professional deployments; its password
# entry depends on whether a credential source is configured.
assert_user_environment_present() {
  local init_container_count="${1:-0}"

  assert_line_count "${init_container_count}" "- name: CLICKHOUSE_USER"
  assert_line_count 1 "- name: ClickHouse__User"
}

assert_password_environment_present() {
  local init_container_count="${1:-0}"

  assert_line_count "${init_container_count}" "- name: CLICKHOUSE_PASSWORD"
  assert_line_count 1 "- name: ClickHouse__Password"
}

assert_password_environment_absent() {
  assert_line_count 0 "- name: CLICKHOUSE_PASSWORD"
  # Even an explicit empty env entry would override a password supplied through envFrom.
  assert_line_count 0 "- name: ClickHouse__Password"
}

assert_password_secret_reference() {
  local secret_name="$1"
  local secret_key="$2"
  local reference_count="${3:-1}"

  assert_line_count "${reference_count}" "name: \"${secret_name}\""
  assert_line_count "${reference_count}" "key: \"${secret_key}\""
}

render_case "bundled ClickHouse with default authentication" \
  --set clickhouse.enabled=true
assert_user_environment_present 2
assert_password_environment_present 2
assert_password_secret_reference "${release_name}-featbit-clickhouse" "admin-password" 3

render_case "bundled ClickHouse with an existing Secret" \
  --set clickhouse.enabled=true \
  --set-string clickhouse.auth.existingSecret=bundled-clickhouse-secret \
  --set-string clickhouse.auth.existingSecretKey=clickhouse-password
assert_user_environment_present 2
assert_password_environment_present 2
assert_password_secret_reference "bundled-clickhouse-secret" "clickhouse-password" 3

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
assert_line_count 0 "name: \"${release_name}-featbit-clickhouse-external\""

render_case "external ClickHouse with a password supplied through api.env" \
  "${external_clickhouse_values[@]}" \
  --set-string 'api.env[0].name=ClickHouse__Password' \
  --set-string 'api.env[0].valueFrom.secretKeyRef.name=injected-clickhouse-secret' \
  --set-string 'api.env[0].valueFrom.secretKeyRef.key=injected-password'
assert_user_environment_present
assert_password_environment_present
assert_line_count 1 "name: injected-clickhouse-secret"
assert_line_count 1 "key: injected-password"
assert_line_count 0 "name: \"${release_name}-featbit-clickhouse-external\""

echo "All ClickHouse password rendering tests passed."
