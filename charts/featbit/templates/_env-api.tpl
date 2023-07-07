{{- define "featbit.api.env" -}}
{{- if .Values.isPro }}
- name: IS_PRO
  value: "true"
- name: Kafka__BootstrapServers
  value: {{ include "featbit.kafka.bootstrap_servers_string" . | quote }}
{{- end }}
{{- include "mongodb-env" . }}
- name: OLAP__ServiceHost
{{- if .Values.useSSLInCluster }}
  value: {{ printf "http://%s:%s" (include "das.svc.name" .) (include "das.svc.port" .) }}
{{- end }}
{{- include "redis-env" . }}
{{- end -}}