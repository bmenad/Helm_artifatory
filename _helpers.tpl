{{/*
Merge ONLY resources:
Priority: base (.Values.<comp>) < sizes < overrides
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
{{- $overrides := $root.Values.overrides | default dict -}}

{{- /* base = valeurs globales */ -}}
{{- $baseComp := index $root.Values $comp | default dict -}}
{{- $sizeComp := index $sizeCfg $comp | default dict -}}
{{- $ovrComp := index $overrides $comp | default dict -}}

{{- $base := index $baseComp "resources" | default dict -}}
{{- $size := index $sizeComp "resources" | default dict -}}
{{- $ovr := index $ovrComp "resources" | default dict -}}

{{- $merged := mergeOverwrite (deepCopy $base) $size $ovr -}}

{{- toYaml $merged -}}
{{- end -}}
