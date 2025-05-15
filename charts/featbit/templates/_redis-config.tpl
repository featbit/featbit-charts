{{/*
-----REDIS-----
*/}}

{{- define "featbit.redis.used" -}}
{{- if ne "standalone" (include "featbit.tier" .) -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{- define "featbit.redis.cluster.enabled" -}}
{{- if and (not .Values.redis.enabled) .Values.externalRedis.cluster.enabled -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{- define "featbit.redis.sentinel.enabled" -}}
{{- if and (not .Values.redis.enabled) .Values.externalRedis.sentinel.enabled -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{- define "featbit.redis.standalone.enabled" -}}
{{- if and (not (include "featbit.redis.cluster.enabled" .)) (not (include "featbit.redis.sentinel.enabled" .)) -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return the Redis fullname
*/}}
{{- define "featbit.redis.fullname" -}}
{{- if .Values.redis.fullnameOverride -}}
{{- .Values.redis.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if .Values.redis.nameOverride -}}
{{- printf "%s-%s" .Release.Name .Values.redis.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" (include "featbit.fullname" .) "redis" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Return the Redis host
*/}}
{{- define "featbit.redis.host" -}}
{{- if .Values.redis.enabled -}}
    {{- printf "%s-master" (include "featbit.redis.fullname" .) -}}
{{- else if and (include "featbit.redis.standalone.enabled" .) (.Values.externalRedis.hosts) -}}
    {{- $parts:= splitList ":" (first .Values.externalRedis.hosts) -}}
    {{- printf "%s" (first $parts) -}}
{{- else if (include "featbit.redis.used" .) -}}
    {{- required "You need to provide a host-pair when using external redis" (join "," .Values.externalRedis.hosts) | printf "%s" -}}
{{- end -}}
{{- end -}}

{{/*
Return the Redis port
*/}}
{{- define "featbit.redis.port" -}}
{{- if .Values.redis.enabled }}
    {{- .Values.redis.master.service.ports.redis -}}
{{- else if and (include "featbit.redis.standalone.enabled" .) (.Values.externalRedis.hosts) -}}
    {{- $parts:= splitList ":" (first .Values.externalRedis.hosts) -}}
    {{- if gt (len $parts) 1 -}}
        {{- last $parts -}}
    {{- else -}}
        {{- 6379 -}}
    {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a secret object for Redis should be created
*/}}
{{- define "featbit.redis.createSecret" -}}
{{- if and (not .Values.redis.enabled) (not .Values.externalRedis.existingSecret) .Values.externalRedis.password (include "featbit.redis.used" .) }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return the Redis secret name
*/}}
{{- define "featbit.redis.secretName" -}}
{{- if .Values.redis.enabled }}
    {{- if .Values.redis.auth.existingSecret }}
        {{- printf "%s" .Values.redis.auth.existingSecret -}}
    {{- else -}}
        {{- printf "%s" (include "featbit.redis.fullname" .) -}}
    {{- end -}}
{{- else if .Values.externalRedis.existingSecret }}
    {{- printf "%s" .Values.externalRedis.existingSecret -}}
{{- else -}}
    {{- printf "%s-external" (include "featbit.redis.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the Redis secret password key
*/}}
{{- define "featbit.redis.secretPasswordKey" -}}
{{- if and .Values.redis.enabled .Values.redis.auth.existingSecret -}}
    {{- required "You need to provide existingSecretPasswordKey when an existingSecret is specified in redis" .Values.redis.auth.existingSecretPasswordKey | printf "%s" -}}
{{- else if and (not .Values.redis.enabled) .Values.externalRedis.existingSecret (include "featbit.redis.used" .) -}}
    {{- required "You need to provide existingSecretPasswordKey when an existingSecret is specified in external Redis" .Values.externalRedis.existingSecretPasswordKey | printf "%s" -}}
{{- else -}}
    {{- print "redis-password" -}}
{{- end -}}
{{- end -}}

{{- define "featbit.redis.db" -}}
{{- $db := "" -}}
{{- if and (not .Values.externalRedis.cluster.enabled) (not .Values.redis.enabled) -}}
    {{- $db = (default 0 (.Values.externalRedis.db | int) | printf "%d") -}}
{{- else if .Values.redis.enabled -}}
    {{- $db = "0" -}}
{{- end -}}
{{- printf "%s" $db -}}
{{- end -}}

{{/*
Return whether Redis uses password authentication or not
*/}}
{{- define "featbit.redis.auth.enabled" -}}
{{- if or (and .Values.redis.enabled .Values.redis.auth.enabled) (and (not .Values.redis.enabled) (or .Values.externalRedis.password .Values.externalRedis.existingSecret)) }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{- define "featbit.redis.ssl" -}}
{{- if and .Values.externalRedis.ssl (not .Values.redis.enabled) -}}
    {{- true -}}
{{- else -}}
    {{- false -}}
{{- end -}}
{{- end -}}


{{- define "featbit.redis.config.0" -}}
{{- if (include "featbit.redis.standalone.enabled" .) -}}
{{- printf "%s:%s" (include "featbit.redis.host" .) (include "featbit.redis.port" .) -}}
{{- else -}}
{{- printf "%s" (include "featbit.redis.host" .) -}}
{{- end -}}
{{- end -}}

{{- define "featbit.redis.config.1" -}}
{{- if and (include "featbit.redis.db" .) (include "featbit.redis.sentinel.enabled" .) -}}
{{- printf "%s,serviceName=%s,defaultDatabase=%s,abortConnect=false,ssl=%s" (include "featbit.redis.config.0" .) .Values.externalRedis.sentinel.masterSet (include "featbit.redis.db" .) (include "featbit.redis.ssl" .) -}}
{{- else if (include "featbit.redis.db" .) -}}
{{- printf "%s,defaultDatabase=%s,abortConnect=false,ssl=%s" (include "featbit.redis.config.0" .) (include "featbit.redis.db" .) (include "featbit.redis.ssl" .) -}}
{{- else -}}
{{- printf "%s,abortConnect=false,ssl=%s" (include "featbit.redis.config.0" .) (include "featbit.redis.ssl" .) -}}
{{- end -}}
{{- end -}}

{{- define "featbit.redis.config.2" -}}
{{- if and .Values.externalRedis.user (not .Values.redis.enabled) -}}
{{- printf "%s,user=%s" (include "featbit.redis.config.1" .) .Values.externalRedis.user -}}
{{- else -}}
{{- printf "%s" (include "featbit.redis.config.1" .) -}}
{{- end -}}
{{- end -}}