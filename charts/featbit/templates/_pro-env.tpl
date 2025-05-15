{{- define "clickhouse-usr-pass" -}}
- name: CLICKHOUSE_USER
  value: {{ include "featbit.clickhouse.user" . }}
- name: CLICKHOUSE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.clickhouse.secretName" . }}
      key: {{ include "featbit.clickhouse.secretPasswordKey" . }}
{{- end -}}


{{- define "das-pro-env" -}}
{{- if (include "featbit.isPro" .) }}
- name: DB_PROVIDER
  value: ClickHouse
- name: KAFKA_HOSTS
  value: {{ include "featbit.kafka.producer.brokers" . }}
- name: CLICKHOUSE_KAFKA_HOSTS
  value: {{ include "featbit.kafka.consumer.brokers" . }}
- name: CLICKHOUSE_HOST
  value: {{ include "featbit.clickhouse.host" . }}

{{ include "clickhouse-usr-pass" . }}

- name: CLICKHOUSE_DATABASE
  value: {{ include "featbit.clickhouse.database" . }}
- name: CLICKHOUSE_PORT
  value: {{ (include "featbit.clickhouse.port" .) | quote }}
- name: CLICKHOUSE_HTTP_PORT
  value: {{ (include "featbit.clickhouse.httpPort" .) | quote }}
{{- if (not .Values.clickhouse.enabled) }}
- name: CLICKHOUSE_SECURE
  value: {{ .Values.externalClickhouse.secure | quote }}
- name: CLICKHOUSE_VERIFY
  value: {{ .Values.externalClickhouse.verify | quote }}
{{- if .Values.externalClickhouse.cluster }}
- name: CLICKHOUSE_CLUSTER
  value: {{ .Values.externalClickhouse.cluster }}
{{- else }}
- name: CLICKHOUSE_REPLICATION
  value: "false"
{{- end }}
{{- if (include "featbit.clickhouse.altHosts" .) }}
- name: CLICKHOUSE_ALT_HOST
  value: {{ include "featbit.clickhouse.altHosts" . }}
{{- end }}
{{- end }}
{{- if (include "featbit.kafka.producer.auth.enabled" .) }}
- name: KAFKA_SECURITY_PROTOCOL
  value: {{ include "featbit.kafka.producer.protocol" . }}
- name: KAFKA_SASL_MECHANISM
  value: {{ include "featbit.kafka.producer.mechanism" . }}
- name: KAFKA_SASL_USER
  value: {{ include "featbit.kafka.producer.user" . }}
- name: KAFKA_SASL_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.kafka.producer.secretName" . }}
      key: {{ include "featbit.kafka.producer.secretPasswordKey" . }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "kafka-bootstrapservers" -}}
{{- if (include "featbit.isPro" .) }}
- name: MqProvider
  value: Kafka
- name: Kafka__Producer__bootstrap.servers
  value: {{ include "featbit.kafka.producer.brokers" . }}
- name: Kafka__Consumer__bootstrap.servers
  value: {{ include "featbit.kafka.consumer.brokers" . }}

{{- if (include "featbit.kafka.producer.auth.enabled" .) }}
- name: Kafka__Producer__sasl.username
  value: {{ include "featbit.kafka.producer.user" . }}
- name: Kafka__Producer__sasl.password
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.kafka.producer.secretName" . }}
      key: {{ include "featbit.kafka.producer.secretPasswordKey" . }}
- name: Kafka__Producer__sasl.mechanism
  value: {{ include "featbit.kafka.producer.mechanism" . }}
- name: Kafka__Producer__security.protocol
  value: {{ include "featbit.kafka.producer.protocol" . }}
{{- end }}

{{- if (include "featbit.kafka.consumer.auth.enabled" .) }}
- name: Kafka__Consumer__sasl.username
  value: {{ include "featbit.kafka.consumer.user" . }}
- name: Kafka__Consumer__sasl.password
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.kafka.consumer.secretName" . }}
      key: {{ include "featbit.kafka.consumer.secretPasswordKey" . }}
- name: Kafka__Consumer__sasl.mechanism
  value: {{ include "featbit.kafka.consumer.mechanism" . }}
- name: Kafka__Consumer__security.protocol
  value: {{ include "featbit.kafka.consumer.protocol" . }}
{{- end }}
{{- end }}
{{- end -}}