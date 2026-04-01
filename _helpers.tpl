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

{{- if or $req $lim }}
resources:
  {{- if $req }}
  requests:
    {{- if $req.cpu }}
    cpu: {{ $req.cpu | quote }}
    {{- end }}
    {{- if $req.memory }}
    memory: {{ $req.memory | quote }}
    {{- end }}
  {{- end }}

  {{- if $lim }}
  limits:
    {{- if $lim.cpu }}
    cpu: {{ $lim.cpu | quote }}
    {{- end }}
    {{- if $lim.memory }}
    memory: {{ $lim.memory | quote }}
    {{- end }}
  {{- end }}
{{- end }}

{{- end }}
