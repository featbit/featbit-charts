{{- define "clickhouse-usr-pass" -}}
- name: CLICKHOUSE_USER
  value: {{ include "featbit.clickhouse.user" . | quote }}
- name: CLICKHOUSE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.clickhouse.secretName" . | quote }}
      key: {{ include "featbit.clickhouse.secretPasswordKey" . | quote }}
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
