{{/*------ CLICKHOUSE ------*/}}
{{/*Return clickhouse fullname*/}}
{{/* Matches the bundled ClickHouse sub-chart's name; the Bitnami common library is unavailable when every sub-chart is disabled */}}
{{- define "featbit.clickhouse.fullname" -}}
{{- if .Values.clickhouse.fullnameOverride -}}
{{- .Values.clickhouse.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "clickhouse" .Values.clickhouse.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* The sole HTTP(S) connection address for the API and bundled startup wait. */}}
{{- define "featbit.clickhouse.httpEndpoint" -}}
{{- $endpoint := "" -}}
{{- if .Values.clickhouse.enabled -}}
    {{- if .Values.clickhouse.tls.enabled -}}
        {{- $endpoint = printf "https://%s:%d" (include "featbit.clickhouse.fullname" .) (.Values.clickhouse.service.ports.https | int) -}}
    {{- else -}}
        {{- $endpoint = printf "http://%s:%d" (include "featbit.clickhouse.fullname" .) (.Values.clickhouse.service.ports.http | int) -}}
    {{- end -}}
{{- else if (include "featbit.isPro" .) -}}
    {{- $endpoint = required "externalClickhouse.httpEndpoint is required for Professional with bundled ClickHouse disabled; migrate legacy host/httpPort/secure values to an absolute HTTP(S) URL" .Values.externalClickhouse.httpEndpoint -}}
{{- end -}}
{{- if not (regexMatch "^https?://[^/?#[:space:]]+(/[^?#[:space:]]*)?$" $endpoint) -}}
    {{- fail "ClickHouse requires an absolute HTTP(S) endpoint with a host, without credentials, query or fragment" -}}
{{- end -}}
{{- $url := urlParse $endpoint -}}
{{- if or (not $url.host) $url.userinfo -}}
    {{- fail "ClickHouse requires an absolute HTTP(S) endpoint with a host, without credentials, query or fragment" -}}
{{- end -}}
{{- $endpoint -}}
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
    {{- default "featbit" .Values.clickhouse.database -}}
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
Return true if a ClickHouse password is available from a Kubernetes secret.

When the bundled clickhouse sub-chart is enabled it always provisions a secret. When an
external ClickHouse is used, a secret only exists if a password is supplied inline or an
existingSecret is referenced. Deployments that source the password some other way (for
example a secret manager writing it into the container at runtime) leave both unset, in
which case no password environment variable should be rendered.
*/}}
{{- define "featbit.clickhouse.auth.enabled" -}}
{{- if .Values.clickhouse.enabled -}}
    {{- true -}}
{{- else if or .Values.externalClickhouse.password .Values.externalClickhouse.existingSecret -}}
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
    {{- required "You need to provide clickhouse.auth.existingSecretKey when an existingSecret is specified" .Values.clickhouse.auth.existingSecretKey | printf "%s" -}}
{{- else if and (not .Values.clickhouse.enabled) .Values.externalClickhouse.existingSecret -}}
    {{- required "You need to provide externalClickhouse.existingSecretKey when an existingSecret is specified" .Values.externalClickhouse.existingSecretKey | printf "%s" -}}
{{- else -}}
    {{- printf "admin-password" -}}
{{- end -}}
{{- end -}}
