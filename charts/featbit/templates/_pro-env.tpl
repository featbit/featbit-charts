{{- define "das-pro-env" -}}
{{- if .Values.isPro }}
- name: IS_PRO
  value: "true"
- name: KAFKA_HOSTS
  value: {{ include "featbit.kafka.brokers" . }}
- name: CLICKHOUSE_KAFKA_HOSTS
  value: {{ include "featbit.kafka.brokers" . }}
- name: CLICKHOUSE_HOST
  value: {{ include "featbit.clickhouse.host" . }}
- name: CLICKHOUSE_USER
  value: {{ include "featbit.clickhouse.user" . }}
- name: CLICKHOUSE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.clickhouse.secretName" . }}
      key: {{ include "featbit.clickhouse.secretPasswordKey" . }}
- name: CLICKHOUSE_DATABASE
  value: {{ include "featbit.clickhouse.database" . }}
{{- if (not .Values.clickhouse.enabled) -}}
- name: CLICKHOUSE_SECURE
  value: {{ .Values.externalClickhouse.secure | quote }}
- name: CLICKHOUSE_VERIFY
  value: {{ .Values.externalClickhouse.verify | quote }}
{{- if .Values.externalClickhouse.cluster -}}
- name: CLICKHOUSE_CLUSTER
  value: {{ .Values.externalClickhouse.cluster | quote }}
{{- else -}}
- name: CLICKHOUSE_REPLICATION
  value: "false"
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "kafka-bootstrapservers" -}}
{{- if .Values.isPro }}
- name: IS_PRO
  value: "true"
- name: Kafka__BootstrapServers
  value: {{ include "featbit.kafka.brokers" . }}
{{- end -}}
{{- end -}}

{{- define "clickhouse-usr-pass" -}}
{{- if .Values.isPro }}
- name: CLICKHOUSE_USER
  value: {{ include "featbit.clickhouse.user" . }}
- name: CLICKHOUSE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.clickhouse.secretName" . }}
      key: {{ include "featbit.clickhouse.secretPasswordKey" . }}
{{- end -}}
{{- end -}}