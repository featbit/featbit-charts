{{/*
Expand the name of the chart.
*/}}
{{- define "featbit.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "featbit.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "featbit.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "featbit.labels" -}}
helm.sh/chart: {{ include "featbit.chart" . }}
{{ include "featbit.selectorLabels" . }}
{{- if .Chart.appVersion }}
app.kubernetes.io/version: {{ .Chart.appVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "featbit.selectorLabels" -}}
app.kubernetes.io/name: {{ include "featbit.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "featbit.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "featbit.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "featbit-metadata-annotations-common" -}}
meta.helm.sh/release-name: {{ .Release.Name }}
meta.helm.sh/release-namespace: {{ .Release.Namespace }}
{{- end }}

{{- define "featbit-metadata-labels-constants" -}}
app.kubernetes.io/name: {{ include "featbit.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "featbit-metadata-labels-common" -}}
{{- include "featbit-metadata-labels-constants" . }}
helm.sh/chart: {{ include "featbit.chart" . }}
{{- end }}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "featbit.imagePullSecrets" -}}
{{- include "featbit.images.pullSecrets" (dict "images" (list .Values.ui .Values.api .Values.els .Values.das .Values.busybox .Values.kubectl) "global" .Values.global) -}}
{{- end -}}

{{- define "featbit.init-container.busybox.image" -}}
{{- include "featbit.images.image" (dict "imageRoot" .Values.busybox.image "global" .Values.global) -}}
{{- end -}}

{{- define "featbit.ui.image" -}}
{{- include "featbit.images.image" (dict "imageRoot" .Values.ui.image "global" .Values.global) -}}
{{- end -}}

{{- define "featbit.api.image" -}}
{{- include "featbit.images.image" (dict "imageRoot" .Values.api.image "global" .Values.global) -}}
{{- end -}}

{{- define "featbit.els.image" -}}
{{- include "featbit.images.image" (dict "imageRoot" .Values.els.image "global" .Values.global) -}}
{{- end -}}

{{- define "featbit.das.image" -}}
{{- include "featbit.images.image" (dict "imageRoot" .Values.das.image "global" .Values.global) -}}
{{- end -}}

{{- define "featbit.init-container.kubectl.image" -}}
{{- include "featbit.images.image" (dict "imageRoot" .Values.kubectl.image "global" .Values.global) -}}
{{- end -}}


{{/*
-----Mongodb-----
*/}}

{{/*
Return the mongodb fullname
*/}}
{{- define "featbit.mongodb.fullname" -}}
{{- if .Values.mongodb.fullnameOverride -}}
{{- .Values.mongodb.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if .Values.mongodb.nameOverride -}}
{{- printf "%s-%s" .Release.Name .Values.mongodb.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" (include "featbit.fullname" .) "mongodb" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Return the Mongodb host
*/}}
{{- define "featbit.mongodb.host" -}}
{{- if .Values.mongodb.enabled -}}
    {{- printf "%s" (include "featbit.mongodb.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "featbit.mongodb.connStr" -}}
{{- if .Values.mongodb.enabled -}}
    {{- printf "mongodb://%s:%s@%s:27017" .Values.mongodb.auth.rootUser .Values.mongodb.auth.rootPassword (include "featbit.mongodb.host" .) -}}
{{- else -}}
    {{- required "You need to provide a full connection string when using external mongodb" .Values.externalMongodb.fullConnectionString | printf "%s" }}
{{- end -}}
{{- end -}}

{{/*
Return the Mongodb secret name
*/}}
{{- define "featbit.mongodb.secretName" -}}
{{- printf "%s-conn-str" (include "featbit.mongodb.fullname" .) -}}
{{- end -}}

{{/*
Return the Mongodb secret key
*/}}
{{- define "featbit.mongodb.secretKey" -}}
{{- printf "mongodb-conn-str" -}}
{{- end -}}

{{/*
-----REDIS-----
*/}}

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
{{- if .Values.redis.enabled }}
    {{- printf "%s-master" (include "featbit.redis.fullname" .) -}}
{{- else -}}
    {{- printf "%s" .Values.externalRedis.host -}}
{{- end -}}
{{- end -}}

{{/*
Return the Redis port
*/}}
{{- define "featbit.redis.port" -}}
{{- if .Values.redis.enabled }}
    {{- 6379 -}}
{{- else -}}
    {{- .Values.externalRedis.port -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a secret object for Redis should be created
*/}}
{{- define "featbit.redis.createSecret" -}}
{{- if and (not .Values.redis.enabled) (not .Values.externalRedis.existingSecret) .Values.externalRedis.password }}
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
{{- else if and (not .Values.redis.enabled) .Values.externalRedis.existingSecret -}}
    {{- required "You need to provide existingSecretPasswordKey when an existingSecret is specified in external Redis" .Values.externalRedis.existingSecretPasswordKey | printf "%s" -}}
{{- else -}}
    {{- printf "redis-password" -}}
{{- end -}}
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

{{- define "featbit.redis.config.1" -}}
{{- printf "%s:%s,abortConnect=false,ssl=%s" (include "featbit.redis.host" .) (include "featbit.redis.port" .) (include "featbit.redis.ssl" .) -}}
{{- end -}}

{{- define "featbit.redis.config.2" -}}
{{- if (include "featbit.redis.auth.enabled" .) -}}
{{- printf "%s,password=%s" (include "featbit.redis.config.1" .) (default .Values.redis.auth.password .Values.externalRedis.password) -}}
{{- else -}}
{{- printf "%s" (include "featbit.redis.config.1" .) -}}
{{- end -}}
{{- end -}}

{{- define "featbit.redis.config.3" -}}
{{- if and .Values.externalRedis.user (not .Values.redis.enabled) -}}
{{- printf "%s,user=" (include "featbit.redis.config.2" .) .Values.externalRedis.user -}}
{{- else -}}
{{- printf "%s" (include "featbit.redis.config.2" .) -}}
{{- end -}}
{{- end -}}


{{- define "featbit.redis.url" -}}
{{- $protocol := "redis://" -}}
{{- if and .Values.externalRedis.ssl (not .Values.redis.enabled) -}}
{{- $protocol = "rediss://" -}}
{{- end -}}
{{- $user := "" -}}
{{- if and .Values.externalRedis.user (not .Values.redis.enabled) -}}
{{- $user = .Values.externalRedis.user -}}
{{- end -}}
{{- $pass := "" -}}
{{- if (include "featbit.redis.auth.enabled" .) -}}
{{- $pass = (default .Values.redis.auth.password .Values.externalRedis.password) -}}
{{- end -}}
{{- $usrpass := "" -}}
{{- if or $pass $user -}}
{{- $usrpass = (printf "%s:%s@" $user $pass) -}}
{{- end -}}
{{- printf "%s%s%s:%s" $protocol $usrpass (include "featbit.redis.host" .) (include "featbit.redis.port" .) -}}
{{- end -}}

{{- define "featbit.redis.conn.secretName" -}}
{{- printf "%s-conn-str" (include "featbit.redis.fullname" .) -}}
{{- end -}}