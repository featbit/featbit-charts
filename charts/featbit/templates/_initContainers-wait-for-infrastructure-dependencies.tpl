{{/* Common initContainers-wait-for-infrastructure-dependencies definition */}}
{{- define "initContainers-wait-for-infrastructure-dependencies" }}
- name: wait-for-infrastructure-dependencies
  image: {{ include "featbit.init-container.busybox.image" . }}
  imagePullPolicy: {{ .Values.busybox.image.pullPolicy }}
  {{- if .Values.isPro }}
  env:
    {{- include "clickhouse-usr-pass" . | nindent 4 }}
  {{- end }}
  command:
    - /bin/sh
    - -c
    - >
        {{ if .Values.redis.enabled }}
        until (nc -vz -w 1 "{{ include "featbit.redis.host" . }}.$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace).svc.cluster.local" {{ include "featbit.redis.port" . }});
        do
            echo "waiting for Redis"; sleep 1;
        done
        {{ end }}

        {{ if .Values.mongodb.enabled }}
        until (nc -vz -w 1 "{{ include "featbit.mongodb.host" . }}.$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace).svc.cluster.local" 27017);
        do
            echo "waiting for Mongodb"; sleep 1;
        done
        {{ end }}

        {{ if and .Values.kafka.enabled .Values.isPro }}

        KAFKA_BROKERS="{{ include "featbit.kafka.consumer.brokers" . }}"

        KAFKA_HOST=$(echo $KAFKA_BROKERS | cut -f1 -d:)
        KAFKA_PORT=$(echo $KAFKA_BROKERS | cut -f2 -d:)

        until (nc -vz -w 1 "$KAFKA_HOST.$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace).svc.cluster.local" $KAFKA_PORT);
        do
            echo "waiting for Kafka"; sleep 1;
        done
        {{ end }}

        {{ if and .Values.clickhouse.enabled .Values.isPro }}
        until (
            NODES_COUNT=$(wget -qO- \
                "http://$CLICKHOUSE_USER:$CLICKHOUSE_PASSWORD@{{ include "featbit.clickhouse.host" . }}.$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace).svc.cluster.local:8123" \
                --post-data "SELECT count() FROM clusterAllReplicas('featbit_ch_cluster', system, one)"
            )
            test ! -z $NODES_COUNT && test $NODES_COUNT -eq {{ mul .Values.clickhouse.shards .Values.clickhouse.replicaCount }}
        );
        do
            echo "waiting for all ClickHouse nodes to be available"; sleep 1;
        done
        {{ end }}
{{- end }}
