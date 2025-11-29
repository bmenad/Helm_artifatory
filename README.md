#!/bin/bash

PROD_SERVER="argocd-prod.example.com"
NPROD_SERVER="argocd-nprod.example.com"

# Login (interactif ou via token si souhaité)
argocd --server $PROD_SERVER login --username admin --password "$PROD_PASSWORD" --grpc-web
argocd --server $NPROD_SERVER login --username admin --password "$NPROD_PASSWORD" --grpc-web

echo "[INFO] Récupération des projets nprod dans PROD…"
PROD_PROJECTS=$(argocd --server $PROD_SERVER proj list -o name | grep nprod)

echo "[INFO] Récupération des projets nprod dans NPROD…"
NPROD_PROJECTS=$(argocd --server $NPROD_SERVER proj list -o name | grep nprod)

echo "[INFO] Détermination des projets manquants…"
MISSING_PROJECTS=$(comm -23 <(echo "$PROD_PROJECTS" | sort) <(echo "$NPROD_PROJECTS" | sort))

echo "[INFO] Projets nprod à migrer :"
echo "$MISSING_PROJECTS"
echo

OUTPUT_FILE="inventaire-migration-argocd.csv"
echo "projet;applications" > $OUTPUT_FILE

echo "[INFO] Génération de l’inventaire…"

for PROJECT in $MISSING_PROJECTS; do
    echo "   - Projet $PROJECT"

    # Récupérer les applications associées au projet dans prod
    APPS=$(argocd --server $PROD_SERVER app list \
            --project "$PROJECT" \
            -o json | jq -r '.[].metadata.name' | tr '\n' ',' | sed 's/,$//')

    echo "$PROJECT;$APPS" >> $OUTPUT_FILE
done

echo
echo "[OK] Inventaire généré : $OUTPUT_FILE"
