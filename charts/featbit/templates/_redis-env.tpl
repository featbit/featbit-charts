{{/* Common Redis ENV variables */}}
{{- define "redis-env" }}
- name: Redis__ConnectionString
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.redis.conn.secretName" . }}
      key: featbit-redis-config
{{- if (include "featbit.redis.cluster.enabled" .) }}
- name: CACHE_TYPE
  value: RedisClusterCache
- name: REDIS_CLUSTER_HOST_PORT_PAIRS
  value: {{ include "featbit.redis.config.0" . }}
- name: REDIS_CLUSTER_SSL
  value: {{ (include "featbit.redis.ssl" .) | quote }}
{{- if (include "featbit.redis.auth.enabled" .) }}
- name: REDIS_CLUSTER_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.redis.secretName" . }}
      key: {{ include "featbit.redis.secretPasswordKey" . }}
{{- end }}
{{- if .Values.externalRedis.user }}
- name: REDIS_CLUSTER_USER
  value: {{ .Values.externalRedis.user }}
{{- end }}
{{- else }}
- name: REDIS_URL
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.redis.conn.secretName" . }}
      key: featbit-redis-url
{{- end }}
{{- end }}