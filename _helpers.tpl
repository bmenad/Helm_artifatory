{{/*
Merge ONLY resources for a component:
Priority: defaults < sizes < overrides
*/}}
{{- define "argocd.resources" -}}
{{- $root := index . 0 -}}
{{- $comp := index . 1 -}}

{{- $sizeName := $root.Values.size | default "xs" -}}
{{- $sizes := $root.Values.sizes | default dict -}}

{{- if not (hasKey $sizes $sizeName) -}}
{{- fail (printf "Invalid size '%s'. Available sizes: %s" $sizeName (keys $sizes | join ", ")) -}}
{{- end -}}

{{- $sizeCfg := index $sizes $sizeName | default dict -}}
{{- $defaults := $root.Values.defaults | default dict -}}
{{- $overrides := $root.Values.overrides | default dict -}}

{{- $def := index $defaults $comp "resources" | default dict -}}
{{- $size := index $sizeCfg $comp "resources" | default dict -}}
{{- $ovr := index $overrides $comp "resources" | default dict -}}

{{- $merged := mergeOverwrite (deepCopy $def) $size $ovr -}}

{{- toYaml $merged -}}
{{- end -}}
