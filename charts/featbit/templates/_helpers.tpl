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
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
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

{{- define "featbit.mongodb.port" -}}
{{- if .Values.mongodb.enabled -}}
    {{- .Values.mongodb.service.ports.mongodb -}}
{{- end -}}
{{- end -}}

{{- define "featbit.mongodb.createSecret" -}}
{{- if and (not .Values.mongodb.enabled) (not .Values.externalMongodb.existingSecret) -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{- define "featbit.mongodb.connStr" -}}
{{- if .Values.mongodb.enabled -}}
    {{- printf "mongodb://%s:%s@%s:%s" .Values.mongodb.auth.rootUser .Values.mongodb.auth.rootPassword (include "featbit.mongodb.host" .) (include "featbit.mongodb.port" .) -}}
{{- else -}}
    {{- required "You need to provide a full connection string when using external mongodb" .Values.externalMongodb.fullConnectionString | printf "%s" -}}
{{- end -}}
{{- end -}}

{{/*
Return the Mongodb secret name
*/}}
{{- define "featbit.mongodb.secretName" -}}
{{- if and (not .Values.mongodb.enabled) .Values.externalMongodb.existingSecret -}}
{{- printf "%s" .Values.externalMongodb.existingSecret -}}
{{- else -}}
{{- printf "%s-conn-str" (include "featbit.mongodb.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the Mongodb secret key
*/}}
{{- define "featbit.mongodb.secretKey" -}}
{{- if and (not .Values.mongodb.enabled) .Values.externalMongodb.existingSecret -}}
{{- required "You need to provide existingSecretKey when an existingSecret is specified in external MongoDB" .Values.externalMongodb.existingSecretKey | printf "%s" -}}
{{- else -}}
{{- printf "mongodb-conn-str" -}}
{{- end -}}
{{- end -}}
{{/*
-----REDIS-----
*/}}

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
{{- else -}}
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

{*
   ------ KAFKA ------
*}

{{/* Return the Kafka fullname */}}
{{- define "featbit.kafka.fullname" }}
{{- if .Values.kafka.fullnameOverride }}
{{- .Values.kafka.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else if .Values.kafka.nameOverride }}
{{- printf "%s-%s" .Release.Name .Values.kafka.nameOverride | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{- printf "%s-%s" (include "featbit.fullname" .) "kafka" | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/* Return the Kafka hosts (brokers) as a comma separated list */}}
{{- define "featbit.kafka.producer.brokers"}}
{{- if .Values.kafka.enabled -}}
    {{- printf "%s:%d" (include "featbit.kafka.fullname" .) (.Values.kafka.service.ports.client | int) }}
{{- else if .Values.isPro -}}
    {{- required "You need to provide a producer broker list when using external kafka" (join "," .Values.externalKafka.brokers.producer.hosts) | printf "%s" -}}
{{- end }}
{{- end }}

{{/* Return the Kafka hosts (brokers) as a comma separated list */}}
{{- define "featbit.kafka.consumer.brokers"}}
{{- if .Values.kafka.enabled -}}
    {{- printf "%s:%d" (include "featbit.kafka.fullname" .) (.Values.kafka.service.ports.client | int) }}
{{- else if .Values.isPro -}}
    {{- required "You need to provide a consumer broker list when using external kafka" (join "," .Values.externalKafka.brokers.consumer.hosts) | printf "%s" -}}
{{- end }}
{{- end }}

{{- define "featbit.kafka.producer.auth.enabled" -}}
{{- if and (not .Values.kafka.enabled) (or .Values.externalKafka.brokers.producer.password .Values.externalKafka.brokers.producer.existingSecret) -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{- define "featbit.kafka.producer.createSecret" -}}
{{- if and (not .Values.kafka.enabled) (not .Values.externalKafka.brokers.producer.existingSecret) .Values.externalKafka.brokers.producer.password }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{- define "featbit.kafka.producer.secretName" -}}
{{- if .Values.externalKafka.brokers.producer.existingSecret }}
    {{- printf "%s" .Values.externalKafka.brokers.producer.existingSecret -}}
{{- else -}}
    {{- printf "%s-external-producer" (include "featbit.kafka.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "featbit.kafka.producer.secretPasswordKey" -}}
{{- if and (not .Values.kafka.enabled) .Values.externalKafka.brokers.producer.existingSecret -}}
    {{- required "You need to provide existingSecretPasswordKey when an existingSecret is specified in external kafka producer" .Values.externalKafka.brokers.producer.existingSecretPasswordKey | printf "%s" -}}
{{- else -}}
    {{- printf "kafka-external-producer-password" -}}
{{- end -}}
{{- end -}}

{{- define "featbit.kafka.consumer.auth.enabled" -}}
{{- if and (not .Values.kafka.enabled) (or .Values.externalKafka.brokers.consumer.password .Values.externalKafka.brokers.consumer.existingSecret) -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{- define "featbit.kafka.consumer.createSecret" -}}
{{- if and (not .Values.kafka.enabled) (not .Values.externalKafka.brokers.consumer.existingSecret) .Values.externalKafka.brokers.consumer.password }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{- define "featbit.kafka.consumer.secretName" -}}
{{- if .Values.externalKafka.brokers.consumer.existingSecret }}
    {{- printf "%s" .Values.externalKafka.brokers.consumer.existingSecret -}}
{{- else -}}
    {{- printf "%s-external-consumer" (include "featbit.kafka.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "featbit.kafka.consumer.secretPasswordKey" -}}
{{- if and (not .Values.kafka.enabled) .Values.externalKafka.brokers.consumer.existingSecret -}}
    {{- required "You need to provide existingSecretPasswordKey when an existingSecret is specified in external kafka consumer" .Values.externalKafka.brokers.consumer.existingSecretPasswordKey | printf "%s" -}}
{{- else -}}
    {{- printf "kafka-external-consumer-password" -}}
{{- end -}}
{{- end -}}

{*
   ------ CLICKHOUSE ------
*}

{{/*
Return clickhouse fullname
*/}}
{{- define "featbit.clickhouse.fullname" -}}
{{- if .Values.clickhouse.fullnameOverride -}}
{{- .Values.clickhouse.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if .Values.clickhouse.nameOverride }}
{{- printf "%s-%s" .Release.Name .Values.clickhouse.nameOverride | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{- printf "%s-%s" "clickhouse" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Return the Redis host
*/}}
{{- define "featbit.clickhouse.host" -}}
{{- if .Values.clickhouse.enabled -}}
    {{- printf "%s" (include "featbit.clickhouse.fullname" .) -}}
{{- else if .Values.isPro -}}
    {{- required "You need to provide a host when using external Clickhouse" .Values.externalClickhouse.host | printf "%s" -}}
{{- end -}}
{{- end -}}

{{- define "featbit.clickhouse.altHosts" -}}
{{- if and (not .Values.clickhouse.enabled) .Values.isPro .Values.externalClickhouse.altHosts  -}}
    {{- print "%s" (join "," .Values.externalClickhouse.altHosts) -}}
{{- end -}}
{{- end -}}

{{- define "featbit.clickhouse.port" -}}
{{- if .Values.clickhouse.enabled -}}
    {{- printf "%d" .Values.clickhouse.containerPorts.tcp -}}
{{- else if .Values.isPro -}}
    {{- required "You need to provide a host port when using external Clickhouse" (.Values.externalClickhouse.tcpPort | int) | printf "%d" -}}
{{- end -}}
{{- end -}}

{{- define "featbit.clickhouse.httpPort" -}}
{{- if .Values.clickhouse.enabled -}}
    {{- printf "%d" .Values.clickhouse.containerPorts.http -}}
{{- else if .Values.isPro -}}
    {{- required "You need to provide a host http port when using external Clickhouse" (.Values.externalClickhouse.httpPort | int) | printf "%d" -}}
{{- end -}}
{{- end -}}

{{- define "featbit.clickhouse.user" -}}
{{- if .Values.clickhouse.enabled }}
    {{- .Values.clickhouse.auth.username -}}
{{- else if .Values.isPro -}}
    {{- required "You need to provide a admin user when using external Clickhouse" .Values.externalClickhouse.user | printf "%s" -}}
{{- end -}}
{{- end -}}

{{- define "featbit.clickhouse.database" -}}
{{- if .Values.clickhouse.enabled }}
    {{- "featbit" -}}
{{- else if .Values.isPro -}}
    {{- default "featbit" .Values.externalClickhouse.database -}}
{{- end -}}
{{- end -}}


{{/*
Return true if a secret object for ClickHouse should be created
*/}}
{{- define "featbit.clickhouse.createSecret" -}}
{{- if and (not .Values.clickhouse.enabled) (not .Values.externalClickhouse.existingSecret) .Values.externalClickhouse.password }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return the ClickHouse secret name
*/}}
{{- define "featbit.clickhouse.secretName" -}}
{{- if .Values.clickhouse.enabled }}
    {{- if .Values.clickhouse.auth.existingSecret }}
        {{- printf "%s" .Values.clickhouse.auth.existingSecret -}}
    {{- else -}}
        {{- printf "%s" (include "featbit.clickhouse.fullname" .) -}}
    {{- end -}}
{{- else if .Values.externalClickhouse.existingSecret }}
    {{- printf "%s" .Values.externalClickhouse.existingSecret -}}
{{- else -}}
    {{- printf "%s-external" (include "featbit.clickhouse.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the ClickHouse secret key
*/}}
{{- define "featbit.clickhouse.secretPasswordKey" -}}
{{- if and .Values.clickhouse.enabled .Values.clickhouse.auth.existingSecret -}}
    {{- required "You need to provide existingSecretPasswordKey when an existingSecret is specified in Clickhouse" .Values.clickhouse.auth.existingSecretKey | printf "%s" -}}
{{- else if and (not .Values.clickhouse.enabled) .Values.externalClickhouse.existingSecret -}}
    {{- required "You need to provide existingSecretPasswordKey when an existingSecret is specified in external Clickhouse" .Values.externalClickhouse.existingSecretKey | printf "%s" -}}
{{- else -}}
    {{- printf "admin-password" -}}
{{- end -}}
{{- end -}}