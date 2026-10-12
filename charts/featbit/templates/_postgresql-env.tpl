{{- define "postgresql-env" }}
{{- if (include "featbit.postgresql.used" .) }}
- name: DbProvider
  value: Postgres
- name: Postgres__ConnectionString
  value: {{ include "featbit.postgresql.config" . }}
{{- if (include "featbit.postgresql.auth.enabled" .) }}
- name: Postgres__Password
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.postgresql.secretName" . }}
      key: {{ include "featbit.postgresql.secretPasswordKey" . }}
{{- end }}

{{- if eq "standalone" (include "featbit.tier" .) }}
- name: MqProvider
  value: Postgres
{{- end }}

{{- end }}
{{- end -}}
