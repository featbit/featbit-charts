{{- define "das-pro-env" -}}
{{- if .Values.isPro }}
- name: IS_PRO
  value: "true"
- name: KAFKA_HOSTS
  value: {{ include "featbit.kafka.producer.brokers" . }}
- name: CLICKHOUSE_KAFKA_HOSTS
  value: {{ include "featbit.kafka.consumer.brokers" . }}
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
  value: {{ .Values.externalKafka.brokers.producer.protocol }}
- name: KAFKA_SASL_MECHANISM
  value: {{ .Values.externalKafka.brokers.producer.mechanism }}
- name: KAFKA_SASL_USER
  value: {{ .Values.externalKafka.brokers.producer.user }}
- name: KAFKA_SASL_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.kafka.producer.secretName" . }}
      key: {{ include "featbit.kafka.producer.secretPasswordKey" . }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "kafka-bootstrapservers" -}}
{{- if .Values.isPro }}
- name: IS_PRO
  value: "true"
- name: Kafka__Producer__bootstrap.servers
  value: {{ include "featbit.kafka.producer.brokers" . }}
- name: Kafka__Consumer__bootstrap.servers
  value: {{ include "featbit.kafka.consumer.brokers" . }}

{{- if (include "featbit.kafka.producer.auth.enabled" .) }}
- name: Kafka__Producer__sasl.username
  value: {{ .Values.externalKafka.brokers.producer.user }}
- name: Kafka__Producer__sasl.password
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.kafka.producer.secretName" . }}
      key: {{ include "featbit.kafka.producer.secretPasswordKey" . }}
- name: Kafka__Producer__sasl.mechanism
  value: {{ .Values.externalKafka.brokers.producer.mechanism }}
- name: Kafka__Producer__security.protocol
  value: {{ .Values.externalKafka.brokers.producer.protocol }}
{{- end }}

{{- if (include "featbit.kafka.consumer.auth.enabled" .) }}
- name: Kafka__Consumer__sasl.username
  value: {{ .Values.externalKafka.brokers.consumer.user }}
- name: Kafka__Consumer__sasl.password
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.kafka.consumer.secretName" . }}
      key: {{ include "featbit.kafka.consumer.secretPasswordKey" . }}
- name: Kafka__Consumer__sasl.mechanism
  value: {{ .Values.externalKafka.brokers.consumer.mechanism }}
- name: Kafka__Consumer__security.protocol
  value: {{ .Values.externalKafka.brokers.consumer.protocol }}
{{- end }}
{{- end }}
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
{{- end }}
{{- end -}}