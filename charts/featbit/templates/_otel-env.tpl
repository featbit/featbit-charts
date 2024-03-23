{{- define "otel-common-env" }}
- name: ENABLE_OPENTELEMETRY
  value: {{ .Values.openTelemetry.enabled | quote }}
- name: OTEL_TRACES_EXPORTER
  value: oltp
- name: OTEL_METRICS_EXPORTER
  value: oltp
- name: OTEL_LOGS_EXPORTER
  value: oltp
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ .Values.openTelemetry.endpoint }}
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: {{ .Values.openTelemetry.protocol }}
- name: OTEL_EXPORTER_OTLP_TIMEOUT
  value: {{ .Values.openTelemetry.timeoutInMilliseconds | quote }}
- name: OTEL_EXPORTER_OTLP_INSECURE
  value: {{ .Values.openTelemetry.insecure | quote }}
{{- end }}

{{- define "api-otel-env" }}
- name: OTEL_SERVICE_NAME
  value: {{ include "featbit.fullname" . }}-api
{{- end }}

{{- define "els-otel-env" }}
- name: OTEL_SERVICE_NAME
  value: {{ include "featbit.fullname" . }}-els
{{- end }}

{{- define "das-otel-env" }}
- name: OTEL_SERVICE_NAME
  value: {{ include "featbit.fullname" . }}-das
{{- end }}