{{- define "argocd.resources" -}}

{{- $cfg := .cfg }}
{{- $component := .component }}
{{- $overrides := .overrides | default dict }}

{{- $compKey := $component }}
{{- if eq $component "reposerver" }}
  {{- $compKey = "repo" }}
{{- end }}

{{- $base := index $cfg $compKey | default dict }}
{{- $ovr := index $overrides $component | default dict }}

{{- $baseRes := $base.resources | default dict }}
{{- $ovrRes := $ovr.resources | default dict }}

{{- $baseReq := $baseRes.requests | default dict }}
{{- $baseLim := $baseRes.limits | default dict }}

{{- $ovrReq := $ovrRes.requests | default dict }}
{{- $ovrLim := $ovrRes.limits | default dict }}

{{- $req := merge $baseReq $ovrReq }}
{{- $lim := merge $baseLim $ovrLim }}

resources:
  requests:
    cpu: {{ $req.cpu | default "" | quote }}
    memory: {{ $req.memory | default "" | quote }}
  limits:
    cpu: {{ $lim.cpu | default "" | quote }}
    memory: {{ $lim.memory | default "" | quote }}

{{- end }}
