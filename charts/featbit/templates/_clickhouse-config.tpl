{{/*------ CLICKHOUSE ------*/}}
{{/*Return clickhouse fullname*/}}
{{- define "featbit.clickhouse.fullname" -}}
{{- if .Values.clickhouse.fullnameOverride -}}
{{- .Values.clickhouse.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if .Values.clickhouse.nameOverride }}
{{- printf "%s-%s" .Release.Name .Values.clickhouse.nameOverride | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{- printf "%s-%s" "clickhouse" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*Return the clickhouse host*/}}
{{- define "featbit.clickhouse.host" -}}
{{- if .Values.clickhouse.enabled -}}
    {{- printf "%s" (include "featbit.clickhouse.fullname" .) -}}
{{- else if (include "featbit.isPro" .) -}}
    {{- required "You need to provide a host when using external Clickhouse" .Values.externalClickhouse.host | printf "%s" -}}
{{- end -}}
{{- end -}}

{{- define "featbit.clickhouse.altHosts" -}}
{{- if and (not .Values.clickhouse.enabled) (include "featbit.isPro" .) .Values.externalClickhouse.altHosts  -}}
    {{- print "%s" (join "," .Values.externalClickhouse.altHosts) -}}
{{- end -}}
{{- end -}}

{{- define "featbit.clickhouse.port" -}}
{{- if .Values.clickhouse.enabled -}}
    {{- printf "%d" (.Values.clickhouse.containerPorts.tcp | int) -}}
{{- else if (include "featbit.isPro" .) -}}
    {{- required "You need to provide a host port when using external Clickhouse" (.Values.externalClickhouse.tcpPort | int) | printf "%d" -}}
{{- end -}}
{{- end -}}

{{- define "featbit.clickhouse.httpPort" -}}
{{- if .Values.clickhouse.enabled -}}
    {{- printf "%d" (.Values.clickhouse.containerPorts.http | int) -}}
{{- else if (include "featbit.isPro" .) -}}
    {{- required "You need to provide a host http port when using external Clickhouse" (.Values.externalClickhouse.httpPort | int) | printf "%d" -}}
{{- end -}}
{{- end -}}

{{- define "featbit.clickhouse.user" -}}
{{- if .Values.clickhouse.enabled }}
    {{- .Values.clickhouse.auth.username -}}
{{- else if (include "featbit.isPro" .) -}}
    {{- required "You need to provide a admin user when using external Clickhouse" .Values.externalClickhouse.user | printf "%s" -}}
{{- end -}}
{{- end -}}

{{- define "featbit.clickhouse.database" -}}
{{- if .Values.clickhouse.enabled }}
    {{- "featbit" -}}
{{- else if (include "featbit.isPro" .) -}}
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