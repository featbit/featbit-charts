{{- define "mongodb-env" }}
{{- if (include "featbit.mongodb.used" .) }}
- name: MongoDb__ConnectionString
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.mongodb.secretName" . }}
      key: {{ include "featbit.mongodb.secretKey" . }}

- name: MongoDb__Database
  value: {{ include "featbit.mongodb.db" . }}

- name: DbProvider
  value: MongoDb

{{- end }}
{{- end }}
