#!/bin/bash

PROD_SERVER="argocd-prod.example.com"
NPROD_SERVER="argocd-nprod.example.com"

PROD_TOKEN="$ARGOCD_PROD_TOKEN"
NPROD_TOKEN="$ARGOCD_NPROD_TOKEN"

TMP_PROD="prod_fp.tmp"
TMP_NPROD="nprod_fp.tmp"

rm -f "$TMP_PROD" "$TMP_NPROD"

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

###########################################
# PROD : fingerprint → appname
###########################################
for APP in $(argocd --server "$PROD_SERVER" app list -o name); do
    JSON=$(argocd --server "$PROD_SERVER" app get "$APP" -o json)
    FP=$(echo "$JSON" | extract_fingerprint)
    echo "$FP|$APP" >> "$TMP_PROD"
done

###########################################
# NPROD : fingerprint → appname
###########################################
for APP in $(argocd --server "$NPROD_SERVER" app list -o name); do
    JSON=$(argocd --server "$NPROD_SERVER" app get "$APP" -o json)
    FP=$(echo "$JSON" | extract_fingerprint)
    echo "$FP|$APP" >> "$TMP_NPROD"
done


###########################################
# RESULTATS
###########################################
echo "app_prod;app_nprod;fingerprint" > apps_equivalentes.csv
echo "app_prod;fingerprint" > apps_manquantes.csv
echo "app_nprod;fingerprint" > apps_orphelines.csv

###########################################
# MATCH : PROD vs NPROD
###########################################
while IFS='|' read -r FP APP_PROD; do
    APP_NPROD=$(grep "^$FP|" "$TMP_NPROD" | cut -d '|' -f 6-)

    if [ -n "$APP_NPROD" ]; then
        echo "$APP_PROD;$APP_NPROD;$FP" >> apps_equivalentes.csv
    else
        echo "$APP_PROD;$FP" >> apps_manquantes.csv
    fi

done < "$TMP_PROD"

###########################################
# ORPHELINES : NPROD qui n’ont pas de match PROD
###########################################
while IFS='|' read -r FP APP_NPROD; do
    APP_PROD=$(grep "^$FP|" "$TMP_PROD" | cut -d '|' -f 6-)

    if [ -z "$APP_PROD" ]; then
        echo "$APP_NPROD;$FP" >> apps_orphelines.csv
    fi

done < "$TMP_NPROD"
