{{/* Professional API Insights query configuration; Standard defaults to DbProvider. */}}
{{- define "clickhouse-api-env" }}
{{- if (include "featbit.isPro" .) }}
- name: OLAPProvider
  value: "ClickHouse"
- name: ClickHouse__HttpEndpoint
  value: {{ include "featbit.clickhouse.httpEndpoint" . | quote }}
- name: ClickHouse__Database
  value: {{ include "featbit.clickhouse.database" . | quote }}
- name: ClickHouse__User
  value: {{ include "featbit.clickhouse.user" . | quote }}
- name: ClickHouse__Password
  {{- if or .Values.clickhouse.enabled .Values.externalClickhouse.existingSecret .Values.externalClickhouse.password }}
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.clickhouse.secretName" . | quote }}
      key: {{ include "featbit.clickhouse.secretPasswordKey" . | quote }}
  {{- else }}
  value: ""
  {{- end }}
{{- end }}
{{- end }}
