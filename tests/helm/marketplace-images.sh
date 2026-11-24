#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
chart_directory="${repository_root}/charts/featbit"
release_name="marketplace-images-test"

deployments=(
  --show-only templates/ui-deployment.yaml
  --show-only templates/api-deployment.yaml
  --show-only templates/eval-server-deployment.yaml
)

# Bitnami sub-charts are disabled, so only the FeatBit deployments are rendered.
external_infrastructure_values=(
  --set postgresql.enabled=false
  --set redis.enabled=false
  --set-string "externalPostgresql.hosts[0]=db.example.com:5432"
  --set-string "externalRedis.hosts[0]=redis.example.com:6379"
)

marketplace_values=(
  --set-string global.azure.images.ui.registry=marketplace.azurecr.io
  --set-string global.azure.images.ui.image=featbit/featbit-ui
  --set-string global.azure.images.ui.tag=1.0.0
  --set-string global.azure.images.api.registry=marketplace.azurecr.io
  --set-string global.azure.images.api.image=featbit/featbit-api-server
  --set-string global.azure.images.api.tag=1.0.0
  --set-string global.azure.images.els.registry=marketplace.azurecr.io
  --set-string global.azure.images.els.image=featbit/featbit-evaluation-server
  --set-string global.azure.images.els.tag=1.0.0
)

temporary_directory="$(mktemp -d)"
trap 'rm -rf "${temporary_directory}"' EXIT

custom_init_values="${temporary_directory}/custom-init.yaml"
cat > "${custom_init_values}" <<'EOF'
api:
  extraInitContainers: |
    - name: custom-init
      image: example.com/custom-init:1.0.0
EOF

rendered=""

render_case() {
  local case_name="$1"
  shift

  echo "Rendering ${case_name}..."
  rendered="$(helm template "${release_name}" "${chart_directory}" "${deployments[@]}" "${external_infrastructure_values[@]}" "$@")"
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

render_case "default images"
assert_line_count 1 "image: docker.io/featbit/featbit-ui:6.1.2"
assert_line_count 1 "image: docker.io/featbit/featbit-api-server:6.1.2"
assert_line_count 1 "image: docker.io/featbit/featbit-evaluation-server:6.1.2"
assert_line_count 3 "image: docker.io/busybox:1.34"

render_case "Marketplace images for all components" "${marketplace_values[@]}"
assert_line_count 1 "image: marketplace.azurecr.io/featbit/featbit-ui:1.0.0"
assert_line_count 1 "image: marketplace.azurecr.io/featbit/featbit-api-server:1.0.0"
assert_line_count 1 "image: marketplace.azurecr.io/featbit/featbit-evaluation-server:1.0.0"

render_case "Marketplace image for the API only" \
  --set-string global.azure.images.api.registry=marketplace.azurecr.io \
  --set-string global.azure.images.api.image=featbit/featbit-api-server \
  --set-string global.azure.images.api.tag=1.0.0
assert_line_count 1 "image: docker.io/featbit/featbit-ui:6.1.2"
assert_line_count 1 "image: marketplace.azurecr.io/featbit/featbit-api-server:1.0.0"
assert_line_count 1 "image: docker.io/featbit/featbit-evaluation-server:6.1.2"

render_case "Marketplace images take precedence over global.imageRegistry" \
  "${marketplace_values[@]}" \
  --set-string global.imageRegistry=mirror.example.com
assert_line_count 1 "image: marketplace.azurecr.io/featbit/featbit-ui:1.0.0"
assert_line_count 1 "image: marketplace.azurecr.io/featbit/featbit-api-server:1.0.0"
assert_line_count 1 "image: marketplace.azurecr.io/featbit/featbit-evaluation-server:1.0.0"
assert_line_count 3 "image: mirror.example.com/busybox:1.34"

render_case "BusyBox waits disabled, custom init container kept" \
  --set busybox.enabled=false \
  -f "${custom_init_values}"
assert_line_count 0 "image: docker.io/busybox:1.34"
assert_line_count 1 "- name: custom-init"
assert_line_count 1 "image: example.com/custom-init:1.0.0"

echo "All Marketplace image and BusyBox rendering tests passed."
