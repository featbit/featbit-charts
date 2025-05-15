{{/*
  -----Postgresql-----
*/}}

{{- define "featbit.postgresql.used" -}}
{{- $db := (include "featbit.db" .) -}}
{{- if or (eq "postgresql" $db) (eq "postgres" $db) -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/* Return the Postgresql fullname */}}
{{- define "featbit.postgresql.fullname" }}
{{- if .Values.postgresql.fullnameOverride }}
{{- .Values.postgresql.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else if .Values.postgresql.nameOverride }}
{{- printf "%s-%s" .Release.Name .Values.postgresql.nameOverride | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{- printf "%s-%s" (include "featbit.fullname" .) "postgresql" | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/* Return the postgresql host */}}
{{- define "featbit.postgresql.host" -}}
{{- if .Values.postgresql.enabled -}}
    {{- printf "%s" (include "featbit.postgresql.fullname" .) -}}
{{- else if (include "featbit.postgresql.used" .) -}}
    {{- $hosts := list -}}
    {{- $pairs := (required "You need to provide postgresql hosts when using external postgresql" .Values.externalPostgresql.hosts) -}}
    {{- range $pairs -}}
        {{- $parts := splitList ":" . -}}
        {{- $hosts = append $hosts (first $parts) -}}
    {{- end -}}
    {{- join "," $hosts | printf "%s" -}}
{{- end -}}
{{- end -}}

{{/* Return the postgresql port */}}
{{- define "featbit.postgresql.port" -}}
{{- if .Values.postgresql.enabled -}}
    {{- .Values.postgresql.primary.service.ports.postgresql -}}
{{- else if (include "featbit.postgresql.used" .) -}}
    {{- $ports := list -}}
    {{- $pairs := (required "You need to provide postgresql hosts when using external postgresql" .Values.externalPostgresql.hosts) -}}
    {{- range $pairs -}}
        {{- $parts := splitList ":" . -}}
        {{- if gt (len $parts) 1 -}}
            {{- $ports = append $ports (last $parts) -}}
        {{- else -}}
            {{- $ports = append $ports "5432" -}}
        {{- end -}}
    {{- end -}}
    {{- join "," $ports | printf "%s" -}}
{{- end -}}
{{- end -}}

{{- define "featbit.postgresql.user" -}}
{{- if .Values.postgresql.enabled -}}
    {{- .Values.postgresql.auth.username -}}
{{- else  -}}
    {{- .Values.externalPostgresql.username -}}
{{- end -}}
{{- end -}}

{{- define "featbit.postgresql.db" -}}
{{- $db := "featbit" -}}
{{- if and .Values.postgresql.enabled .Values.postgresql.auth.database -}}
    {{- $db = .Values.postgresql.auth.database -}}
{{- else if .Values.externalPostgresql.database -}}
    {{- $db = .Values.externalPostgresql.database -}}
{{- end -}}
{{- printf "%s" $db -}}
{{- end -}}

{{/*Return true if a secret object for postgresql should be created*/}}
{{- define "featbit.postgresql.createSecret" -}}
{{- if and (not .Values.postgresql.enabled) (not .Values.externalPostgresql.existingSecret) .Values.externalPostgresql.password (include "featbit.postgresql.used" .) }}
    {{- true -}}
{{- end -}}
{{- end -}}


{{/*Return the postgresql secret name*/}}
{{- define "featbit.postgresql.secretName" -}}
{{- if .Values.postgresql.enabled }}
    {{- if .Values.postgresql.auth.existingSecret }}
        {{- printf "%s" .Values.postgresql.auth.existingSecret -}}
    {{- else -}}
        {{- printf "%s" (include "featbit.postgresql.fullname" .) -}}
    {{- end -}}
{{- else if .Values.externalPostgresql.existingSecret }}
    {{- printf "%s" .Values.externalPostgresql.existingSecret -}}
{{- else -}}
    {{- printf "%s-external" (include "featbit.postgresql.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "featbit.postgresql.secretPasswordKey" -}}
{{- if and .Values.postgresql.enabled .Values.postgresql.auth.existingSecret -}}
    {{- required "You need to provide userPasswordKey when an existingSecret is specified in postgresql" .Values.postgresql.auth.secretKeys.userPasswordKey | printf "%s" -}}
{{- else if and (not .Values.postgresql.enabled) .Values.externalPostgresql.existingSecret (include "featbit.postgresql.used" .) -}}
    {{- required "You need to provide existingSecretPasswordKey when an existingSecret is specified in external postgresql" .Values.externalPostgresql.existingSecretPasswordKey | printf "%s" -}}
{{- else -}}
    {{- print "password" -}}
{{- end -}}
{{- end -}}


{{- define "featbit.postgresql.config" -}}
{{- printf "Host=%s;Port=%s;Username=%s;Database=%s" (include "featbit.postgresql.host" .) (include "featbit.postgresql.port" .) (include "featbit.postgresql.user" .) (include "featbit.postgresql.db" .) -}}
{{- end -}}