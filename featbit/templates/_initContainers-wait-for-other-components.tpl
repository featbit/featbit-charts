{{/* ui waits for other components */}}
{{- define "initContainers-wait-for-other-components" }}
- name: wait-for-other-components
  image: {{ .Values.busybox.image }}
  imagePullPolicy: {{ .Values.busybox.pullPolicy }}
  command:
    - /bin/sh
    - -c
    - >
        {{ if (include "api.svc.fqdn" .) }}
        until (nc -vz {{ include "api.svc.fqdn" . }} {{ include "api.svc.port" . }});
        do
            echo "waiting for API"; sleep 1;
        done
        {{ end }}

        {{ if (include "els.svc.fqdn" .) }}
        until (nc -vz {{ include "els.svc.fqdn" . }} {{ include "els.svc.port" . }});
        do
            echo "waiting for Evaluation Server"; sleep 1;
        done
        {{ end }}

        {{ if (include "das.svc.fqdn" .) }}
        until (nc -vz {{ include "das.svc.fqdn" . }} {{ include "das.svc.port" . }});
        do
          echo "waiting for DA Server"; sleep 1;
        done
        {{ end }}
      
{{- end }}