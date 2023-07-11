### Set up dependency names

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "featbit.mongodb.fullname" -}}
{{- if .Values.mongodb.fullnameOverride -}}
{{- .Values.mongodb.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name "mongodb" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Set mongodb host
*/}}
{{- define "featbit.mongodb.host" -}}
{{- if .Values.mongodb.enabled -}}
{{- template "featbit.mongodb.fullname" . -}}
{{- else -}}
{{ required "A valid .Values.externalmongodb.host is required" .Values.externalmongodb.host }}
{{- end -}}
{{- end -}}

# {{/*
# Set mongodb secret
# */}}
# {{- define "featbit.mongodb.secret" -}}
# {{- if .Values.mongodb.enabled -}}
# {{- template "featbit.mongodb.fullname" . -}}
# {{- else -}}
# {{- template "featbit.fullname" . -}}
# {{- end -}}
# {{- end -}}

{{/*
Set mongodb password
*/}}
{{- define "featbit.mongodb.password" -}}
{{- if .Values.mongodb.enabled -}}
{{- default "password" .Values.mongodb.password }}
{{- else -}}
{{ required "A valid .Values.externalmongodb.password is required" .Values.externalmongodb.password }}
{{- end -}}
{{- end -}}

{{/*
Set mongodb port
*/}}
{{- define "featbit.mongodb.port" -}}
{{- if .Values.mongodb.enabled -}}
{{- default 27017 .Values.mongodb.service.port }}
{{- else -}}
{{- required "A valid .Values.externalmongodb.port is required" .Values.externalmongodb.port -}}
{{- end -}}
{{- end -}}

{{/**/}}
{{/*Set mongodb username*/}}
{{/**/}}
{{/*{{- define "featbit.mongodb.username" -}}*/}}
{{/*{{- if .Values.mongodb.enabled -}}*/}}
{{/*{{- default "admin" .Values.mongodb.username }}*/}}
{{/*{{- else -}}*/}}
{{/*{{ required "A valid .Values.externalmongodb.username is required" .Values.externalmongodb.username }}*/}}
{{/*{{- end -}}*/}}
{{/*{{- end -}}*/}}

{{/**/}}
{{/*Set mongodb database*/}}
{{/**/}}
{{/*{{- define "featbit.mongodb.database" -}}*/}}
{{/*{{- if .Values.mongodb.enabled -}}*/}}
{{/*{{- default "featbit" .Values.mongodb.database }}*/}}
{{/*{{- else -}}*/}}
{{/*{{ required "A valid .Values.externalmongodb.database is required" .Values.externalmongodb.database }}*/}}
{{/*{{- end -}}*/}}
{{/*{{- end -}}*/}}


{{- define "featbit.redis.fullname" -}}
{{- if .Values.redis.fullnameOverride -}}
{{- .Values.redis.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name "redis" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Set redis host
*/}}
{{- define "featbit.redis.host" -}}
{{- if .Values.redis.enabled -}}
{{- template "featbit.redis.fullname" . -}}-master
{{- else -}}
{{ required "A valid .Values.externalRedis.host is required" .Values.externalRedis.host }}
{{- end -}}
{{- end -}}

# {{/*
# Set redis secret
# */}}
# {{- define "featbit.redis.secret" -}}
# {{- if .Values.redis.enabled -}}
# {{- template "featbit.redis.fullname" . -}}
# {{- else -}}
# {{- template "featbit.fullname" . -}}
# {{- end -}}
# {{- end -}}

{{/*
Set redis port
*/}}
{{- define "featbit.redis.port" -}}
{{- if .Values.redis.enabled -}}
{{- default 6379 .Values.redis.redisPort }}
{{- else -}}
{{ required "A valid .Values.externalRedis.port is required" .Values.externalRedis.port }}
{{- end -}}
{{- end -}}

{{/*# */}}{{/**/}}
{{/*# Set redis password*/}}
{{/*# */}}
{{/*# {{- define "featbit.redis.password" -}}*/}}
{{/*# {{- if .Values.redis.enabled -}}*/}}
{{/*# {{ .Values.redis.password }}*/}}
{{/*# {{- else -}}*/}}
{{/*# {{ .Values.externalRedis.password }}*/}}
{{/*# {{- end -}}*/}}
{{/*# {{- end -}}*/}}