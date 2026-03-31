{{/*
Helper générique pour merger les resources (base size + override)
*/}}
{{- define "argocd.resources" -}}

{{- $cfg := .cfg }}
{{- $component := .component }}
{{- $overrides := .overrides | default dict }}

{{- /* mapping si repo vs reposerver */}}
{{- $compKey := $component }}
{{- if eq $component "reposerver" }}
  {{- $compKey = "repo" }}
{{- end }}

{{- $base := index $cfg $compKey | default dict }}
{{- $ovr := index $overrides $component | default dict }}

{{- $req := merge ($base.resources.requests | default dict) ($ovr.resources.requests | default dict) }}
{{- $lim := merge ($base.resources.limits | default dict) ($ovr.resources.limits | default dict) }}

resources:
  requests:
    cpu: {{ $req.cpu | default "" | quote }}
    memory: {{ $req.memory | default "" | quote }}
  limits:
    cpu: {{ $lim.cpu | default "" | quote }}
    memory: {{ $lim.memory | default "" | quote }}

{{- end }}
