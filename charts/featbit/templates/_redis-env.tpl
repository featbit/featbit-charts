{{/* Common Redis ENV variables */}}
{{- define "redis-env" }}

- name: REDIS_HOST
  value: {{ include "featbit.redis.host" . }}

- name: REDIS_PORT
  value: {{ include "featbit.redis.port" . | quote }}

{{- if (include "featbit.redis.auth.enabled" .) }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.redis.secretName" . }}
      key: {{ include "featbit.redis.secretPasswordKey" . }}
{{- end }}

- name: Redis__ConnectionString
  value: {{ include "featbit.redis.connStr" . }}

- name: REDIS_SSL
  value: {{ include "featbit.redis.ssl" . | quote }}

{{- end }}