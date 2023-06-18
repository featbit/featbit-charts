{{/* Common initContainers-wait-for-infrastructure-dependencies definition */}}
{{- define "initContainers-wait-for-infrastructure-dependencies" }}
- name: wait-for-infrastructure-dependencies
  image: {{ include "featbit.init-container.busybox.image" . }}
  imagePullPolicy: {{ .Values.busybox.image.pullPolicy }}
  command:
    - /bin/sh
    - -c
    - >
        {{ if .Values.redis.enabled }}
        until (nc -vz "{{ include "featbit.redis.host" . }}.$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace).svc.cluster.local" {{ include "featbit.redis.port" . }});
        do
            echo "waiting for Redis"; sleep 1;
        done
        {{ end }}

        {{ if .Values.mongodb.enabled }}
        until (nc -vz "{{ include "featbit.mongodb.host" . }}.$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace).svc.cluster.local" 27017);
        do
            echo "waiting for Mongodb"; sleep 1;
        done
        {{ end }}
{{- end }}
