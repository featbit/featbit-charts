#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
chart_directory="${repository_root}/charts/featbit"
release_name="postgresql-password-test"

deployment_templates=(
  --show-only templates/api-deployment.yaml
  --show-only templates/eval-server-deployment.yaml
  --show-only templates/da-server-deployment.yaml
)

external_postgresql_values=(
  --set postgresql.enabled=false
  --set-string "externalPostgresql.hosts[0]=db.example.com:5432"
  --set-string externalPostgresql.username=featbit
)

rendered=""

render_case() {
  local case_name="$1"
  shift

  echo "Rendering ${case_name}..."
  rendered="$(helm template "${release_name}" "${chart_directory}" "${deployment_templates[@]}" "$@")"
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

assert_password_environment_present() {
  assert_line_count 3 "- name: Postgres__Password"
  assert_line_count 3 "- name: POSTGRES_PASSWORD"
}

assert_password_environment_absent() {
  assert_line_count 0 "- name: Postgres__Password"
  assert_line_count 0 "- name: POSTGRES_PASSWORD"
}

assert_password_secret_reference() {
  local secret_name="$1"
  local secret_key="$2"

  # API, ELS, and DAS each render the .NET and uppercase password variables.
  assert_line_count 6 "name: ${secret_name}"
  assert_line_count 6 "key: ${secret_key}"
}

render_case "bundled PostgreSQL with default authentication"
assert_password_environment_present
assert_password_secret_reference "${release_name}-featbit-postgresql" "password"

render_case "bundled PostgreSQL with an existing Secret" \
  --set-string postgresql.auth.existingSecret=bundled-postgresql-secret
assert_password_environment_present
assert_password_secret_reference "bundled-postgresql-secret" "password"

render_case "external PostgreSQL with an inline password" \
  "${external_postgresql_values[@]}" \
  --set-string externalPostgresql.password=test-password
assert_password_environment_present
assert_password_secret_reference "${release_name}-featbit-postgresql-external" "password"

render_case "external PostgreSQL with an existing Secret" \
  "${external_postgresql_values[@]}" \
  --set-string externalPostgresql.existingSecret=external-postgresql-secret \
  --set-string externalPostgresql.existingSecretPasswordKey=application-password
assert_password_environment_present
assert_password_secret_reference "external-postgresql-secret" "application-password"

render_case "external PostgreSQL with credentials supplied outside the chart" \
  "${external_postgresql_values[@]}"
assert_password_environment_absent
assert_line_count 3 "- name: Postgres__ConnectionString"
assert_line_count 3 "- name: POSTGRES_USER"
assert_line_count 0 "name: ${release_name}-featbit-postgresql-external"

echo "All PostgreSQL password rendering tests passed."
