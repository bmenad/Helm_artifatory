{{/*
Merge resources for a component:
Priority: base < size < overrides
*/}}
{{- define "argocd.resources" -}}

{{- $root := index . 0 -}}
{{- $comp := index . 1 -}}

{{- $sizeName := default "xs" $root.Values.size -}}
{{- $sizes := default dict $root.Values.sizes -}}
{{- $sizeCfg := index $sizes $sizeName | default dict -}}

{{- $base := index $root.Values $comp "resources" | default dict -}}
{{- $size := index $sizeCfg $comp "resources" | default dict -}}
{{- $over := index $root.Values.overrides $comp "resources" | default dict -}}

{{- $merged := mergeOverwrite (deepCopy $base) $size $over -}}

{{- toYaml $merged -}}

{{- end -}}
