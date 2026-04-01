{{- printf "DEX ROOT = %v" .Values.dex | fail }}
{{- printf "DEX SSO = %v" .Values.configs.sso.dex | fail }}

{{/*
Merge resources for a component
Priority: base < size < overrides
Safe against nil values everywhere
*/}}
{{- define "argocd.resources" -}}

{{- $root := index . 0 -}}
{{- $comp := index . 1 -}}

{{- /* ---------------------------
      SIZE
---------------------------- */ -}}
{{- $sizeName := default "xs" $root.Values.size -}}
{{- $sizes := default dict $root.Values.sizes -}}
{{- $sizeCfg := index $sizes $sizeName | default dict -}}

{{- /* ---------------------------
      BASE (values.yaml global)
---------------------------- */ -}}
{{- $compBase := index $root.Values $comp | default dict -}}
{{- $base := index $compBase "resources" | default dict -}}

{{- /* ---------------------------
      SIZE RESOURCES
---------------------------- */ -}}
{{- $compSize := index $sizeCfg $comp | default dict -}}
{{- $size := index $compSize "resources" | default dict -}}

{{- /* ---------------------------
      OVERRIDES (instance level)
---------------------------- */ -}}
{{- $overrides := default dict $root.Values.overrides -}}
{{- $compOverrides := index $overrides $comp | default dict -}}
{{- $over := index $compOverrides "resources" | default dict -}}

{{- /* ---------------------------
      MERGE (deep)
---------------------------- */ -}}
{{- $merged := mergeOverwrite (deepCopy $base) $size $over -}}

{{- /* ---------------------------
      OUTPUT
---------------------------- */ -}}
{{- toYaml $merged -}}

{{- end -}}
