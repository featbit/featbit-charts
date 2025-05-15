{{/*------ KAFKA ------*/}}

{{/* Return the Kafka fullname */}}
{{- define "featbit.kafka.fullname" }}
{{- if .Values.kafka.fullnameOverride }}
{{- .Values.kafka.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else if .Values.kafka.nameOverride }}
{{- printf "%s-%s" .Release.Name .Values.kafka.nameOverride | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{- printf "%s-%s" (include "featbit.fullname" .) "kafka" | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/* Return the Kafka hosts (brokers) as a comma separated list */}}
{{- define "featbit.kafka.producer.brokers"}}
{{- if .Values.kafka.enabled -}}
    {{- printf "%s:%d" (include "featbit.kafka.fullname" .) (.Values.kafka.service.ports.client | int) }}
{{- else if (include "featbit.isPro" .) -}}
    {{- required "You need to provide a producer broker list when using external kafka" (join "," .Values.externalKafka.brokers.producer.hosts) | printf "%s" -}}
{{- end }}
{{- end }}

{{/* Return the Kafka hosts (brokers) as a comma separated list */}}
{{- define "featbit.kafka.consumer.brokers"}}
{{- if .Values.kafka.enabled -}}
    {{- printf "%s:%d" (include "featbit.kafka.fullname" .) (.Values.kafka.service.ports.client | int) }}
{{- else if (include "featbit.isPro" .) -}}
    {{- required "You need to provide a consumer broker list when using external kafka" (join "," .Values.externalKafka.brokers.consumer.hosts) | printf "%s" -}}
{{- end }}
{{- end }}

{{- define "featbit.kafka.producer.auth.enabled" -}}
{{- if .Values.kafka.enabled -}}
{{- if ne "PLAINTEXT" (upper .Values.kafka.listeners.client.protocol) -}}
    {{- true -}}
{{- end -}}
{{- else if and (not .Values.kafka.enabled) (or .Values.externalKafka.brokers.producer.password .Values.externalKafka.brokers.producer.existingSecret) -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{- define "featbit.kafka.producer.createSecret" -}}
{{- if and (not .Values.kafka.enabled) (not .Values.externalKafka.brokers.producer.existingSecret) .Values.externalKafka.brokers.producer.password }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{- define "featbit.kafka.producer.secretName" -}}
{{- if .Values.kafka.enabled -}}
{{- if .Values.kafka.sasl.existingSecret -}}
    {{- printf "%s" .Values.kafka.sasl.existingSecret -}}
{{- else -}}
    {{- printf "%s-user-passwords" (include "featbit.kafka.fullname" .) -}}
{{- end -}}
{{- else if .Values.externalKafka.brokers.producer.existingSecret }}
    {{- printf "%s" .Values.externalKafka.brokers.producer.existingSecret -}}
{{- else -}}
    {{- printf "%s-external-producer" (include "featbit.kafka.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "featbit.kafka.producer.secretPasswordKey" -}}
{{- if .Values.kafka.enabled -}}
    {{- printf "client-passwords" -}}
{{- else if and (not .Values.kafka.enabled) .Values.externalKafka.brokers.producer.existingSecret -}}
    {{- required "You need to provide existingSecretPasswordKey when an existingSecret is specified in external kafka producer" .Values.externalKafka.brokers.producer.existingSecretPasswordKey | printf "%s" -}}
{{- else -}}
    {{- printf "kafka-external-producer-password" -}}
{{- end -}}
{{- end -}}

{{- define "featbit.kafka.consumer.auth.enabled" -}}
{{- if .Values.kafka.enabled -}}
{{- if ne "PLAINTEXT" (upper .Values.kafka.listeners.client.protocol) -}}
    {{- true -}}
{{- end -}}
{{- else if and (not .Values.kafka.enabled) (or .Values.externalKafka.brokers.consumer.password .Values.externalKafka.brokers.consumer.existingSecret) -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{- define "featbit.kafka.consumer.createSecret" -}}
{{- if and (not .Values.kafka.enabled) (not .Values.externalKafka.brokers.consumer.existingSecret) .Values.externalKafka.brokers.consumer.password }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{- define "featbit.kafka.consumer.secretName" -}}
{{- if .Values.kafka.enabled -}}
{{- if .Values.kafka.sasl.existingSecret -}}
    {{- printf "%s" .Values.kafka.sasl.existingSecret -}}
{{- else -}}
    {{- printf "%s-user-passwords" (include "featbit.kafka.fullname" .) -}}
{{- end -}}
{{- else if .Values.externalKafka.brokers.consumer.existingSecret }}
    {{- printf "%s" .Values.externalKafka.brokers.consumer.existingSecret -}}
{{- else -}}
    {{- printf "%s-external-consumer" (include "featbit.kafka.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "featbit.kafka.consumer.secretPasswordKey" -}}
{{- if .Values.kafka.enabled -}}
    {{- printf "client-passwords" -}}
{{- else if and (not .Values.kafka.enabled) .Values.externalKafka.brokers.consumer.existingSecret -}}
    {{- required "You need to provide existingSecretPasswordKey when an existingSecret is specified in external kafka consumer" .Values.externalKafka.brokers.consumer.existingSecretPasswordKey | printf "%s" -}}
{{- else -}}
    {{- printf "kafka-external-consumer-password" -}}
{{- end -}}
{{- end -}}

{{- define "featbit.kafka.producer.user" -}}
{{- if .Values.kafka.enabled -}}
    {{- printf "%s" (first .Values.kafka.sasl.client.users) -}}
{{- else -}}
    {{- printf "%s" .Values.externalKafka.brokers.producer.user -}}
{{- end -}}
{{- end -}}

{{- define "featbit.kafka.consumer.user" -}}
{{- if .Values.kafka.enabled -}}
    {{- printf "%s" (first .Values.kafka.sasl.client.users) -}}
{{- else -}}
    {{- printf "%s" .Values.externalKafka.brokers.consumer.user -}}
{{- end -}}
{{- end -}}

{{- define "featbit.kafka.producer.protocol" -}}
{{- if .Values.kafka.enabled -}}
    {{- printf "%s" (.Values.kafka.listeners.client.protocol) -}}
{{- else -}}
    {{- printf "%s" .Values.externalKafka.brokers.producer.protocol -}}
{{- end -}}
{{- end -}}

{{- define "featbit.kafka.consumer.protocol" -}}
{{- if .Values.kafka.enabled -}}
    {{- printf "%s" (.Values.kafka.listeners.client.protocol) -}}
{{- else -}}
    {{- printf "%s" .Values.externalKafka.brokers.consumer.protocol -}}
{{- end -}}
{{- end -}}

{{- define "featbit.kafka.producer.mechanism" -}}
{{- if .Values.kafka.enabled -}}
    {{- printf "PLAIN" -}}
{{- else -}}
    {{- printf "%s" .Values.externalKafka.brokers.producer.mechanism -}}
{{- end -}}
{{- end -}}

{{- define "featbit.kafka.consumer.mechanism" -}}
{{- if .Values.kafka.enabled -}}
    {{- printf "PLAIN" -}}
{{- else -}}
    {{- printf "%s" .Values.externalKafka.brokers.consumer.mechanism -}}
{{- end -}}
{{- end -}}