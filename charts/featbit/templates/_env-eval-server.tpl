{{- define "featbit.evaluation.env" -}}
{{- if .Values.isPro }}
- name: IS_PRO
  value: "true"
- name: Kafka__BootstrapServers
  value: {{ include "featbit.kafka.bootstrap_servers_string" . | quote }}
{{- end }}
{{- include "mongodb-env" . }}
{{- include "redis-env" . }}
{{- end -}}
