{{- define "mongodb-env" }}

- name: MongoDb__ConnectionString
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.mongodb.secretName" . }}
      key: {{ include "featbit.mongodb.secretKey" . }}

- name: MongoDb__Database
  value: featbit

- name: MONGO_URI
  valueFrom:
    secretKeyRef:
      name: {{ include "featbit.mongodb.secretName" . }}
      key: {{ include "featbit.mongodb.secretKey" . }}

- name: MONGO_INITDB_DATABASE
  value: featbit

- name: MONGO_HOST
  value: {{ include "featbit.mongodb.host" . }}

{{- end }}