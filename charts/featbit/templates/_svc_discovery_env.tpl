{{- define "das.svc.port" -}}
{{- default 8200 .Values.das.service.port -}}
{{- end -}}

{{- define "das.svc.name" -}}
{{ include "featbit.fullname" . }}-das
{{- end -}}

{{- define "das.svc.fqdn" -}}
{{ include "das.svc.name" . }}.{{ .Release.Namespace }}.svc.cluster.local
{{- end -}}

{{- define "els.svc.port" -}}
{{- if .Values.els.ingress.enabled -}}
{{- 80 -}}
{{- else -}}
{{- default 5100 .Values.els.service.port -}}
{{- end -}}
{{- end -}}

{{- define "els.svc.name" -}}
{{ include "featbit.fullname" . }}-els
{{- end -}}

{{- define "els.svc.fqdn" -}}
{{ include "els.svc.name" . }}.{{ .Release.Namespace }}.svc.cluster.local
{{- end -}}

{{- define "api.svc.port" -}}
{{- if .Values.api.ingress.enabled -}}
{{- 80 -}}
{{- else -}}
{{- default 5000 .Values.api.service.port -}}
{{- end -}}
{{- end -}}

{{- define "api.svc.name" -}}
{{ include "featbit.fullname" . }}-api
{{- end -}}

{{- define "api.svc.fqdn" -}}
{{ include "api.svc.name" . }}.{{ .Release.Namespace }}.svc.cluster.local
{{- end -}}

{{- define "ui.svc.port" -}}
{{- if .Values.ui.ingress.enabled -}}
{{- 80 -}}
{{- else -}}
{{- default 8081 .Values.ui.service.port -}}
{{- end -}}
{{- end -}}

{{- define "ui.svc.name" -}}
{{ include "featbit.fullname" . }}-ui
{{- end -}}

{{- define "ui.svc.fqdn" -}}
{{ include "ui.svc.name" . }}.{{ .Release.Namespace }}.svc.cluster.local
{{- end -}}

{{- define "ui.svc.basehref" -}}
{{- .Values.uiBaseHref -}}
{{- end -}}

{{- define "ui.svc.displayapiurl" -}}
{{- .Values.uiDisplayApiUrl -}}
{{- end -}}

{{- define "ui.svc.displayevaluationurl" -}}
{{- .Values.uiDisplayEvaluationUrl -}}
{{- end -}}

{{- define "els.svc.streamingtrackclienthostname" -}}
{{- .Values.elsStreamingTrackClientHostName -}}
{{- end -}}

{{- define "els.svc.streamingtokenexpiryseconds" -}}
{{- .Values.elsStreamingTokenExpirySeconds -}}
{{- end -}}

{{- define "featbit.api.external.url" -}}
{{- if and .Values.autoDiscovery (eq .Values.api.service.type "LoadBalancer") -}}
{{- .Values.apiExternalUrl -}}
{{- else -}}
{{- required "The api url should be set before FeatBit starts" .Values.apiExternalUrl -}}
{{- end -}}
{{- end -}}

{{- define "featbit.els.external.url" -}}
{{- if and .Values.autoDiscovery (eq .Values.els.service.type "LoadBalancer") -}}
{{- .Values.evaluationServerExternalUrl -}}
{{- else -}}
{{- required "The evaluation server url should be set before FeatBit starts" .Values.evaluationServerExternalUrl -}}
{{- end -}}
{{- end -}}

{{- define "featbit.demo.external.url" -}}
{{- default "https://featbit-samples.vercel.app" .Values.demoExternalUrl -}}
{{- end -}}