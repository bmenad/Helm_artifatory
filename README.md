#!/bin/bash

PROD_SERVER="argocd-prod.example.com"
NPROD_SERVER="argocd-nprod.example.com"

PROD_TOKEN="$ARGOCD_PROD_TOKEN"
NPROD_TOKEN="$ARGOCD_NPROD_TOKEN"

argocd login "$PROD_SERVER" --username admin --auth-token "$PROD_TOKEN" --grpc-web --insecure
argocd login "$NPROD_SERVER" --username admin --auth-token "$NPROD_TOKEN" --grpc-web --insecure

extract_fingerprint() {
    jq -r '
        .spec.source.repoURL + "|" +
        (.spec.source.path // .spec.source.chart // "") + "|" +
        (.spec.source.targetRevision // "") + "|" +
        .spec.destination.server + "|" +
        .spec.destination.namespace
    '
}

declare -A PROD_FP
declare -A NPROD_FP

for APP in $(argocd --server "$PROD_SERVER" app list -o name); do
    JSON=$(argocd --server "$PROD_SERVER" app get "$APP" -o json)
    FP=$(echo "$JSON" | extract_fingerprint)
    PROD_FP["$FP"]="$APP"
done

for APP in $(argocd --server "$NPROD_SERVER" app list -o name); do
    JSON=$(argocd --server "$NPROD_SERVER" app get "$APP" -o json)
    FP=$(echo "$JSON" | extract_fingerprint)
    NPROD_FP["$FP"]="$APP"
done

echo "app_prod;app_nprod;fingerprint" > apps_equivalentes.csv
echo "app_prod;fingerprint" > apps_manquantes.csv
echo "app_nprod;fingerprint" > apps_orphelines.csv

for FP in "${!PROD_FP[@]}"; do
    if [[ -n "${NPROD_FP[$FP]}" ]]; then
        echo "${PROD_FP[$FP]};${NPROD_FP[$FP]};$FP" >> apps_equivalentes.csv
    else
        echo "${PROD_FP[$FP]};$FP" >> apps_manquantes.csv
    fi
done

for FP in "${!NPROD_FP[@]}"; do
    if [[ -z "${PROD_FP[$FP]}" ]]; then
        echo "${NPROD_FP[$FP]};$FP" >> apps_orphelines.csv
    fi
done
