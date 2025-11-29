#!/bin/bash

###########################################
# CONFIGURATION
###########################################
PROD_SERVER="argocd-prod.example.com"
NPROD_SERVER="argocd-nprod.example.com"

# Variables d’environnement contenant les tokens
PROD_TOKEN="$ARGOCD_PROD_TOKEN"
NPROD_TOKEN="$ARGOCD_NPROD_TOKEN"

PATTERN="nprod"   # Filtre des projets
OUTPUT_FILE="inventaire-migration-argocd.csv"
EXPORT_DIR="export_migration"

mkdir -p "$EXPORT_DIR/projects"
mkdir -p "$EXPORT_DIR/apps"

###########################################
# LOGIN VIA TOKEN
###########################################
echo "[INFO] Connexion à PROD via token..."
argocd login "$PROD_SERVER" \
    --grpc-web \
    --username admin \
    --auth-token "$PROD_TOKEN" \
    --insecure

echo "[INFO] Connexion à NPROD via token..."
argocd login "$NPROD_SERVER" \
    --grpc-web \
    --username admin \
    --auth-token "$NPROD_TOKEN" \
    --insecure


###########################################
# RECUPERATION DES LISTES DE PROJETS
###########################################
echo "[INFO] Récupération des projets matching '$PATTERN' dans PROD…"
PROD_PROJECTS=$(argocd --server "$PROD_SERVER" proj list -o name | grep "$PATTERN")

echo "[INFO] Récupération des projets matching '$PATTERN' dans NPROD…"
NPROD_PROJECTS=$(argocd --server "$NPROD_SERVER" proj list -o name | grep "$PATTERN")


###########################################
# DÉTECTION DES PROJETS À MIGRER
###########################################
echo "[INFO] Détermination des projets manquants…"
MISSING_PROJECTS=$(comm -23 <(echo "$PROD_PROJECTS" | sort) <(echo "$NPROD_PROJECTS" | sort))

echo "[INFO] Projets à migrer :"
echo "$MISSING_PROJECTS"
echo

###########################################
# INVENTAIRE + EXPORT YAML
###########################################
echo "projet;applications" > "$OUTPUT_FILE"

for PROJECT in $MISSING_PROJECTS; do
    echo "   - Traitement du projet : $PROJECT"

    ###################################
    # EXPORT YAML DU PROJET
    ###################################
    echo "[INFO] Export YAML du projet $PROJECT"
    argocd --server "$PROD_SERVER" proj get "$PROJECT" -o json | \
        yq -P > "$EXPORT_DIR/projects/$PROJECT.yaml"

    ###################################
    # RÉCUPÉRATION DES APPLIS DU PROJET
    ###################################
    APPS=$(argocd --server "$PROD_SERVER" app list \
            --project "$PROJECT" \
            -o json | jq -r '.[].metadata.name')

    APP_LIST_CSV=$(echo "$APPS" | tr '\n' ',' | sed 's/,$//')
    echo "$PROJECT;$APP_LIST_CSV" >> "$OUTPUT_FILE"

    ###################################
    # EXPORT YAML DES APPLICATIONS
    ###################################
    for APP in $APPS; do
        echo "      -> Export app : $APP"

        argocd --server "$PROD_SERVER" app get "$APP" -o json | \
            yq -P > "$EXPORT_DIR/apps/$APP.yaml"
    done
done

echo
echo "[OK] Inventaire généré : $OUTPUT_FILE"
echo "[OK] YAML exportés dans : $EXPORT_DIR"
