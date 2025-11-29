#!/bin/bash

PROD_SERVER="argocd-prod.example.com"
NPROD_SERVER="argocd-nprod.example.com"

PROD_TOKEN="$ARGOCD_PROD_TOKEN"
NPROD_TOKEN="$ARGOCD_NPROD_TOKEN"

PATTERN="nprod"
OUTPUT_FILE="inventaire-migration.csv"
EXPORT_DIR="export_migration"

mkdir -p "$EXPORT_DIR/projects" "$EXPORT_DIR/apps"

argocd login "$PROD_SERVER" --username admin --auth-token "$PROD_TOKEN" --grpc-web --insecure
argocd login "$NPROD_SERVER" --username admin --auth-token "$NPROD_TOKEN" --grpc-web --insecure

PROD_PROJECTS=$(argocd --server "$PROD_SERVER" proj list -o name | grep "$PATTERN")
NPROD_PROJECTS=$(argocd --server "$NPROD_SERVER" proj list -o name | grep "$PATTERN")

MISSING_PROJECTS=$(comm -23 <(echo "$PROD_PROJECTS" | sort) <(echo "$NPROD_PROJECTS" | sort))

echo "projet;applications" > "$OUTPUT_FILE"

for PROJECT in $MISSING_PROJECTS; do
    echo "Export projet $PROJECT"
    argocd --server "$PROD_SERVER" proj get "$PROJECT" -o json | yq -P \
        > "$EXPORT_DIR/projects/$PROJECT.yaml"

    APPS=$(argocd --server "$PROD_SERVER" app list --project "$PROJECT" -o json \
        | jq -r '.[].metadata.name')

    APP_LIST_CSV=$(echo "$APPS" | tr '\n' ',' | sed 's/,$//')
    echo "$PROJECT;$APP_LIST_CSV" >> "$OUTPUT_FILE"

    for APP in $APPS; do
        echo "  Export app $APP"
        argocd --server "$PROD_SERVER" app get "$APP" -o json | yq -P \
            > "$EXPORT_DIR/apps/$APP.yaml"
    done
done
