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


{{- define "featbit.tier" -}}
{{- $tier := (lower .Values.architecture.tier) -}}
{{- if or (eq "standalone" $tier) (eq "standard" $tier) (eq "professional" $tier) -}}
    {{- print $tier -}}
{{- else -}}
    {{- fail "The tier should be standalone/standard/professional" -}}
{{- end -}}
{{- end -}}

{{- define "featbit.db" -}}
{{- $db := (lower .Values.architecture.database) -}}
{{- if or (eq "mongodb" $db) (eq "postgresql" $db) (eq "postgres" $db) -}}
    {{- print $db -}}
{{- else -}}
    {{- fail "The database should be mongodb/postgresql" -}}
{{- end -}}
{{- end -}}

{{- define "featbit.isPro" -}}
{{- if eq "professional" (include "featbit.tier" .) -}}
    {{- true -}}
{{- end -}}
{{- end -}}