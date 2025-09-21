{{/* Common initContainers-wait-for-infrastructure-dependencies definition */}}
{{- define "initContainers-wait-for-infrastructure-dependencies" }}
{{- $ctx := .context }}
{{- $component := .component }}
- name: wait-for-infrastructure-dependencies
  image: {{ include "featbit.init-container.busybox.image" $ctx }}
  imagePullPolicy: {{ $ctx.Values.busybox.image.pullPolicy }}
  {{- with (get $ctx.Values $component).securityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if (include "featbit.isPro" $ctx) }}
  env:
    {{- include "clickhouse-usr-pass" $ctx | nindent 4 }}
  {{- end }}
  command:
    - /bin/sh
    - -c
    - >
        {{ if and $ctx.Values.postgresql.enabled (include "featbit.postgresql.used" $ctx) }}
        until (nc -vz -w 1 "{{ include "featbit.postgresql.host" $ctx }}.$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace).svc.cluster.local" {{ include "featbit.postgresql.port" $ctx }});
        do
            echo "waiting for Postgresql"; sleep 1;
        done
        {{ end }}

        {{ if and $ctx.Values.redis.enabled (include "featbit.redis.used" $ctx) }}
        until (nc -vz -w 1 "{{ include "featbit.redis.host" $ctx }}.$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace).svc.cluster.local" {{ include "featbit.redis.port" $ctx }});
        do
            echo "waiting for Redis"; sleep 1;
        done
        {{ end }}

        {{ if and $ctx.Values.mongodb.enabled (include "featbit.mongodb.used" $ctx) }}
        until (nc -vz -w 1 "{{ include "featbit.mongodb.host" $ctx }}.$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace).svc.cluster.local" {{ include "featbit.mongodb.port" $ctx }});
        do
            echo "waiting for Mongodb"; sleep 1;
        done
        {{ end }}

        {{ if and $ctx.Values.kafka.enabled (include "featbit.isPro" $ctx) }}

        KAFKA_BROKERS="{{ include "featbit.kafka.consumer.brokers" $ctx }}"

        KAFKA_HOST=$(echo $KAFKA_BROKERS | cut -f1 -d:)
        KAFKA_PORT=$(echo $KAFKA_BROKERS | cut -f2 -d:)

        until (nc -vz -w 1 "$KAFKA_HOST.$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace).svc.cluster.local" $KAFKA_PORT);
        do
            echo "waiting for Kafka"; sleep 1;
        done
        {{ end }}

        {{ if and $ctx.Values.clickhouse.enabled (include "featbit.isPro" $ctx) }}
        until (
            NODES_COUNT=$(wget -qO- \
                "http://$CLICKHOUSE_USER:$CLICKHOUSE_PASSWORD@{{ include "featbit.clickhouse.host" $ctx }}.$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace).svc.cluster.local:8123" \
                --post-data "SELECT count() FROM clusterAllReplicas('featbit_ch_cluster', system, one)"
            )
            test ! -z $NODES_COUNT && test $NODES_COUNT -eq {{ mul $ctx.Values.clickhouse.shards $ctx.Values.clickhouse.replicaCount }}
        );
        do
            echo "waiting for all ClickHouse nodes to be available"; sleep 1;
        done
        {{ end }}
{{- end }}
