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

{{- if or (eq "standalone" (include "featbit.tier" .)) (eq "standard" (include "featbit.tier" .)) }}
- name: DB_PROVIDER
  value: Postgres
- name: POSTGRES_HOST
  value: {{ include "featbit.postgresql.host" . }}
- name: POSTGRES_PORT
  value: {{ (include "featbit.postgresql.port" .) | quote }}
- name: POSTGRES_DATABASE
  value: {{ include "featbit.postgresql.db" . }}
- name: POSTGRES_USER
  value: {{ include "featbit.postgresql.user" . }}
{{- if (include "featbit.postgresql.auth.enabled" .) }}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.postgresql.secretName" . }}
      key: {{ include "featbit.postgresql.secretPasswordKey" . }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}