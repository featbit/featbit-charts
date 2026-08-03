{{/* Controlplane Redis ENV variables using Redis__Instances__N format */}}
{{- define "controlplane-redis-env" }}
{{- if (include "featbit.redis.used" .) }}
- name: CacheProvider
  value: Redis

{{- if .Values.redis.enabled }}
{{- $host := printf "%s-master" (include "featbit.redis.fullname" .) }}
{{- $port := .Values.redis.master.service.ports.redis }}
{{- $connStr := printf "%s:%v,defaultDatabase=0,abortConnect=false,ssl=false" $host $port }}
- name: Redis__Instances__0__ConnectionString
  value: {{ $connStr }}
{{- else }}
{{- $db := include "featbit.redis.db" . }}
{{- $ssl := include "featbit.redis.ssl" . }}
{{- $user := .Values.externalRedis.user }}
{{- $sentinelEnabled := include "featbit.redis.sentinel.enabled" . }}
{{- $masterSet := .Values.externalRedis.sentinel.masterSet }}
{{- if .Values.controlPlane.redis.instances }}
{{- range $i, $instance := .Values.controlPlane.redis.instances }}
{{- $hostStr := join "," $instance.hosts }}
{{- $connStr := "" }}
{{- if and $db $sentinelEnabled }}
{{- $connStr = printf "%s,serviceName=%s,defaultDatabase=%s,abortConnect=false,ssl=%s" $hostStr $masterSet $db $ssl }}
{{- else if $db }}
{{- $connStr = printf "%s,defaultDatabase=%s,abortConnect=false,ssl=%s" $hostStr $db $ssl }}
{{- else }}
{{- $connStr = printf "%s,abortConnect=false,ssl=%s" $hostStr $ssl }}
{{- end }}
{{- if $user }}
{{- $connStr = printf "%s,user=%s" $connStr $user }}
{{- end }}
- name: Redis__Instances__{{ $i }}__ConnectionString
  value: {{ $connStr }}
{{- if or $instance.secretName (include "featbit.redis.auth.enabled" $) }}
- name: Redis__Instances__{{ $i }}__Password
  valueFrom:
    secretKeyRef:
      name: {{ $instance.secretName | default (include "featbit.redis.secretName" $) }}
      key: {{ $instance.secretKey | default (include "featbit.redis.secretPasswordKey" $) }}
{{- end }}
{{- end }}
{{- else }}
{{- $hostStr := join "," .Values.externalRedis.hosts }}
{{- $connStr := "" }}
{{- if and $db $sentinelEnabled }}
{{- $connStr = printf "%s,serviceName=%s,defaultDatabase=%s,abortConnect=false,ssl=%s" $hostStr $masterSet $db $ssl }}
{{- else if $db }}
{{- $connStr = printf "%s,defaultDatabase=%s,abortConnect=false,ssl=%s" $hostStr $db $ssl }}
{{- else }}
{{- $connStr = printf "%s,abortConnect=false,ssl=%s" $hostStr $ssl }}
{{- end }}
{{- if $user }}
{{- $connStr = printf "%s,user=%s" $connStr $user }}
{{- end }}
- name: Redis__Instances__0__ConnectionString
  value: {{ $connStr }}
{{- if (include "featbit.redis.auth.enabled" .) }}
- name: Redis__Instances__0__Password
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.redis.secretName" . }}
      key: {{ include "featbit.redis.secretPasswordKey" . }}
{{- end }}
{{- end }}
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
