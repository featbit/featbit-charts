{{/* An alternate/empty Secret retains the dependency's own script precedence. */}}
{{- define "featbit.clickhouse.managedInitdbSecret" -}}
{{- if and .Values.clickhouse.enabled (eq .Values.clickhouse.initdbScriptsSecret "{{ include \"common.names.fullname\" . }}-featbit-initdb") -}}
true
{{- end -}}
{{- end -}}

{{- define "featbit.clickhouse.initdbScript" -}}
{{- if ne (upper (include "featbit.kafka.consumer.protocol" .)) "PLAINTEXT" -}}
{{- fail "Bundled FeatBit initialization uses local PLAINTEXT Kafka; use clickhouse.initdbScriptsSecret for custom Kafka authentication." -}}
{{- end -}}
{{- $database := include "featbit.clickhouse.database" . -}}
{{- $identifier := printf "`%s`" ($database | replace "\\" "\\\\" | replace "`" "\\`") -}}
{{- $literal := printf "'%s'" ($database | replace "\\" "\\\\" | replace "'" "\\'") -}}
{{- $brokers := include "featbit.kafka.consumer.brokers" . -}}
{{- if .Values.kafka.enabled -}}
{{- $brokers = printf "%s:%d" (include "common.names.fullname" .Subcharts.kafka) (.Values.kafka.service.ports.client | int) -}}
{{- end -}}
{{- $brokers = $brokers | replace "\\" "\\\\" | replace "'" "\\'" -}}
{{- $schema := .Files.Get "files/featbit-v6/clickhouse-v6.0.0.sql" -}}
{{- $schema = replace "CREATE DATABASE IF NOT EXISTS featbit;" (printf "CREATE DATABASE IF NOT EXISTS %s;" $identifier) $schema -}}
{{- $schema = replace "database = 'featbit'" (printf "database = %s" $literal) $schema -}}
{{- $schema = replace "featbit." (printf "%s." $identifier) $schema -}}
{{- $schema = replace "kafka_broker_list = 'kafka:9092'" (printf "kafka_broker_list = '%s'" $brokers) $schema -}}
#!/bin/bash
# The selected Bitnami image sources .sh files and ignores raw .sql files.
set -euo pipefail

featbit_clickhouse_client() {
  clickhouse-client --host 127.0.0.1 --port "${CLICKHOUSE_TCP_PORT:-9000}" \
    --user "${CLICKHOUSE_ADMIN_USER:-default}" --password "${CLICKHOUSE_ADMIN_PASSWORD:-}" "$@"
}

# An old PVC can lack the image's first-boot marker. Never migrate its data here.
featbit_existing_objects=$(featbit_clickhouse_client --query 'SELECT count() FROM system.tables WHERE database = {{ $literal | replace "'" "'\"'\"'" }}')
if [[ "$featbit_existing_objects" != "0" ]]; then
  echo "Nonempty ClickHouse database: migrate manually, then set clickhouse.initdbScriptsSecret to an empty string." >&2
  exit 1
fi

featbit_clickhouse_client --multiquery <<'FEATBIT_V6_SQL'
{{ $schema | trim }}
FEATBIT_V6_SQL
unset -f featbit_clickhouse_client
unset featbit_existing_objects
{{- end -}}
