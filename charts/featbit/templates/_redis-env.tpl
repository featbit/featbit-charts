{{/* Common Redis ENV variables */}}
{{- define "redis-env" }}
{{- if (include "featbit.redis.used" .) }}
- name: CacheProvider
  value: Redis

- name: Redis__ConnectionString
  value: {{ include "featbit.redis.config.2" . }}


{{- if (include "featbit.redis.auth.enabled" .) }}
- name: Redis__Password
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.redis.secretName" . }}
      key: {{ include "featbit.redis.secretPasswordKey" . }}
{{- end }}

{{- if eq "standard" (include "featbit.tier" .) }}
- name: MqProvider
  value: Redis
{{- end }}

{{- else }}
- name: CacheProvider
  value: None

{{- end }}
{{- end }}