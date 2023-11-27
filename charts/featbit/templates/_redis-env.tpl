{{/* Common Redis ENV variables */}}
{{- define "redis-env" }}
- name: Redis__ConnectionString
  value: {{ include "featbit.redis.config.2" . }}
{{- if (include "featbit.redis.auth.enabled" .) }}
{{- if .Values.externalRedis.user }}
- name: REDIS_USER
  value: {{ .Values.externalRedis.user }}
{{- end }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.redis.secretName" . }}
      key: {{ include "featbit.redis.secretPasswordKey" . }}
- name: Redis__Password
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.redis.secretName" . }}
      key: {{ include "featbit.redis.secretPasswordKey" . }}
{{- end }}

- name: REDIS_SSL
  value: {{ (include "featbit.redis.ssl" .) | quote }}

- name: REDIS_DB
  value: {{ (include "featbit.redis.db" .) | quote }}

{{- if (include "featbit.redis.cluster.enabled" .) }}
- name: CACHE_TYPE
  value: RedisClusterCache
- name: REDIS_CLUSTER_HOST_PORT_PAIRS
  value: {{ include "featbit.redis.config.0" . }}
{{- else if (include "featbit.redis.sentinel.enabled" .) }}
- name: CACHE_TYPE
  value: RedisSentinelCache
- name: REDIS_SENTINEL_HOST_PORT_PAIRS
  value: {{ include "featbit.redis.config.0" . }}
{{- else }}
- name: REDIS_HOST
  value: {{ include "featbit.redis.host" . }}
- name: REDIS_PORT
  value: {{ (include "featbit.redis.port" .) | quote }}
{{- end }}
{{- end }}