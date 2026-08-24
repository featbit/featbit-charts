{{- define "otel-common-env" }}
{{- if .Values.openTelemetry.enabled }}
- name: ENABLE_OPENTELEMETRY
  value: {{ .Values.openTelemetry.enabled | quote }}
- name: OTEL_TRACES_EXPORTER
  value: otlp
- name: OTEL_METRICS_EXPORTER
  value: otlp
- name: OTEL_LOGS_EXPORTER
  value: otlp
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ .Values.openTelemetry.endpoint }}
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: {{ .Values.openTelemetry.protocol }}
- name: OTEL_EXPORTER_OTLP_TIMEOUT
  value: {{ .Values.openTelemetry.timeoutInMilliseconds | quote }}
- name: OTEL_EXPORTER_OTLP_INSECURE
  value: {{ .Values.openTelemetry.insecure | quote }}
{{- end }}
{{- end }}

{{- define "controlplane-otel-env" }}
{{- if .Values.openTelemetry.enabled }}
- name: OTEL_SERVICE_NAME
  value: {{ include "featbit.fullname" . }}-controlplane
{{- end }}
{{- end }}

{{- define "api-otel-env" }}
{{- if .Values.openTelemetry.enabled }}
- name: OTEL_SERVICE_NAME
  value: {{ include "featbit.fullname" . }}-api
{{- end }}
{{- end }}

{{- define "els-otel-env" }}
{{- if .Values.openTelemetry.enabled }}
- name: OTEL_SERVICE_NAME
  value: {{ include "featbit.fullname" . }}-els
{{- end }}
{{- end }}

{{- define "das-otel-env" }}
{{- if .Values.openTelemetry.enabled }}
- name: OTEL_SERVICE_NAME
  value: {{ include "featbit.fullname" . }}-das
{{- end }}
{{- end }}