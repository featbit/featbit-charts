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

{{- if eq "standard" (include "featbit.tier" .) }}
- name: MONGO_URI
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.mongodb.secretName" . }}
      key: {{ include "featbit.mongodb.secretKey" . }}

- name: MONGO_INITDB_DATABASE
  value: {{ include "featbit.mongodb.db" . }}

- name: DB_PROVIDER
  value: MongoDb
{{- end }}
{{- end }}
{{- end }}