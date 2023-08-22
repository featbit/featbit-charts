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
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.redis.conn.secretName" . }}
      key: featbit-redis-config

- name: REDIS_URL
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.redis.conn.secretName" . }}
      key: featbit-redis-url
{{- end }}