{{/*
-----Mongodb-----
*/}}

{{- define "featbit.mongodb.used" -}}
{{- if and (ne "standalone" (include "featbit.tier" .)) (eq "mongodb" (include "featbit.db" .)) -}}
    {{- true -}}
{{- end -}}
{{- end -}}

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
    {{- .Values.mongodb.service.port -}}
{{- end -}}
{{- end -}}

{{- define "featbit.mongodb.createSecret" -}}
{{- if and (not .Values.externalMongodb.existingSecret) (include "featbit.mongodb.used" .) -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{- define "featbit.mongodb.connStr" -}}
{{- if .Values.mongodb.enabled -}}
    {{- printf "mongodb://%s:%s@%s:%s" .Values.mongodb.settings.rootUsername .Values.mongodb.settings.rootPassword (include "featbit.mongodb.host" .) (include "featbit.mongodb.port" .) -}}
{{- else if and (not .Values.externalMongodb.existingSecret) (include "featbit.mongodb.used" .) -}}
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
{{- if and (not .Values.mongodb.enabled) .Values.externalMongodb.existingSecret (include "featbit.mongodb.used" .) -}}
{{- required "You need to provide existingSecretKey when an existingSecret is specified in external MongoDB" .Values.externalMongodb.existingSecretKey | printf "%s" -}}
{{- else -}}
{{- printf "mongodb-conn-str" -}}
{{- end -}}
{{- end -}}