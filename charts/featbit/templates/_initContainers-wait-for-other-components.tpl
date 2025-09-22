{{/* ui waits for other components */}}
{{- define "initContainers-wait-for-other-components" }}
{{- $ctx := .context }}
{{- $component := .component }}
- name: wait-for-other-components
  image: {{ include "featbit.init-container.busybox.image" $ctx }}
  imagePullPolicy: {{ $ctx.Values.busybox.image.pullPolicy }}
  {{- with (get $ctx.Values $component).securityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  command:
    - /bin/sh
    - -c
    - >
        {{ if (include "api.svc.fqdn" $ctx) }}
        until (nc -vz -w 1 {{ include "api.svc.fqdn" $ctx }} {{ include "api.svc.port" $ctx }});
        do
            echo "waiting for API"; sleep 1;
        done
        {{ end }}

        {{ if (include "els.svc.fqdn" $ctx) }}
        until (nc -vz -w 1 {{ include "els.svc.fqdn" $ctx }} {{ include "els.svc.port" $ctx }});
        do
            echo "waiting for Evaluation Server"; sleep 1;
        done
        {{ end }}

        {{ if (include "das.svc.fqdn" $ctx) }}
        until (nc -vz -w 1 {{ include "das.svc.fqdn" $ctx }} {{ include "das.svc.port" $ctx }});
        do
          echo "waiting for DA Server"; sleep 1;
        done
        {{ end }}
      
{{- end }}