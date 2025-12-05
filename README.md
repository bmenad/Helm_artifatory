Voici un README UNIQUE, COMPLET, FINAL, intégrant TOUT ce que tu demandes :
✔ scripts
✔ GitLab CI
✔ sécurité des tokens
✔ e-mails par instance
✔ envoi automatique tous les lundis à 09h00
✔ arrêt automatique à une date limite
✔ planning GitLab Schedules expliqué
✔ tout dans un seul fichier prêt à mettre sur GitHub

📘 README – Automatisation ArgoCD : Inventaire, Statistiques & Notifications Hebdomadaires

Ce projet automatise :

l’extraction des applications nprod dans plusieurs instances ArgoCD

la génération de JSON d’inventaire et statistiques

l’envoi automatique d’emails chaque lundi à 09h00

jusqu’à une date limite définie

tout en sécurisant les accès grâce à des tokens ArgoCD stockés dans GitLab CI

📁 Arborescence du dépôt
.
├── README.md
├── .gitlab-ci.yml
├── scripts/
│   ├── generate_stats.sh
│   └── send_email.py
└── config/
    └── mailing-lists.yaml

🔐 Sécurisation : Tokens ArgoCD (méthode recommandée)
1. Générer un token pour chaque instance
argocd login argocd-<instance>-devops.group.echonet --username admin --password <PWD>
argocd account generate-token --expires-in 90d

2. Ajouter les tokens dans GitLab CI

Settings → CI/CD → Variables

KEY	VALUE	MASKED	PROTECTED
ARGOCD_TOKEN_ETNA	<token>	✔	✔
ARGOCD_TOKEN_HELIOS	<token>	✔	✔
ARGOCD_TOKEN_CALLIOPE	<token>	✔	✔
📄 config/mailing-lists.yaml

Liste des emails par instance ArgoCD :

instances:
  etna:
    emails:
      - "alice@company.com"
      - "bob@company.com"
      - "team-etna@company.com"

  helios:
    emails:
      - "team-helios@company.com"

  calliope:
    emails:
      - "calliope-dev@company.com"

🧰 scripts/generate_stats.sh
#!/bin/bash
set -euo pipefail

INS="$1"
DATE_LIMIT="$2"   # format YYYY-MM-DD

# Vérification de la date limite
TODAY=$(date +%Y-%m-%d)
if [[ "$TODAY" > "$DATE_LIMIT" ]]; then
  echo "[INFO] Date limite dépassée. Aucune notification envoyée."
  exit 0
fi

TOKEN_VAR="ARGOCD_TOKEN_${INS^^}"
TOKEN="${!TOKEN_VAR}"

OUTPUT_FILE="prod_argocd_list_applications_by_nprod_project_${INS}.json"
STAT_FILE="prod_argocd_stat_applications_nprod_project_${INS}.json"
PROD_SERVER="argocd-${INS}-devops.group.echonet"

argocd login "$PROD_SERVER" --grpc-web --auth-token "$TOKEN"

DATA=$(argocd app list -o json | jq '
  group_by(.spec.project)
  | map({ project: .[0].spec.project, applications: map(.metadata.name) })
  | map(select(.project | contains("nprod")))
')

echo "$DATA" > "$OUTPUT_FILE"

PROJECTS=$(echo "$DATA" | jq 'map({project: .project, nb_applis: (.applications | length)})')
TOTAL=$(echo "$DATA" | jq '[.[].applications | length] | add')

jq -n \
  --arg ins "$INS" \
  --argjson prj "$PROJECTS" \
  --argjson total "$TOTAL" \
  '{instance: $ins, projects: $prj, total_applis: $total}' \
  > "$STAT_FILE"

echo "[OK] Fichier statistique généré : $STAT_FILE"

📧 scripts/send_email.py

import yaml
import json
import smtplib
import argparse
from email.mime.text import MIMEText

parser = argparse.ArgumentParser()
parser.add_argument("--instance", required=True)
parser.add_argument("--json", required=True)
args = parser.parse_args()

# Chargement des emails depuis YAML
with open("config/mailing-lists.yaml") as f:
    config = yaml.safe_load(f)

# Chargement des statistiques JSON
with open(args.json) as f:
    stats = json.load(f)

# Vérifier s'il reste des applications à migrer
total = stats.get("total_applis", 0)

if total == 0:
    print("[INFO] Aucune application à migrer. Aucun mail envoyé.")
    exit(0)

# Récupérer la liste des emails pour l'instance
emails = config["instances"][args.instance]["emails"]

# Contenu du mail
body = f"""
Bonjour,

Voici les applications restantes à migrer pour l'instance {args.instance} :

{json.dumps(stats, indent=2)}

Merci de finaliser la migration avant la date limite.

Cordialement,
L’équipe DevOps
"""

# Construction du message email
msg = MIMEText(body)
msg["Subject"] = f"[MIGRATION] Applications restantes - {args.instance}"
msg["From"] = "no-reply-devops@company.com"
msg["To"] = ", ".join(emails)

# Envoi SMTP (mode non authentifié ou via relai interne)
try:
    with smtplib.SMTP("smtp.company.com") as s:
        s.sendmail(msg["From"], emails, msg.as_string())
    print("[OK] Email envoyé avec succès")
except Exception as e:
    print(f"[ERROR] Échec de l'envoi du mail : {e}")
    exit(1)

🧩 .gitlab-ci.yml
stages:
  - inventory
  - notify

variables:
  DATE_LIMIT: "2025-03-31"   # 🔥 MODIFIABLE : date de fin d'envoi automatique

inventory:
  stage: inventory
  image: cdtools:latest
  script:
    - bash scripts/generate_stats.sh "$INSTANCE" "$DATE_LIMIT"
  artifacts:
    paths:
      - "*.json"
  rules:
    - if: '$CI_PIPELINE_SCHEDULED == "true"'

notify:
  stage: notify
  image: python:3.11
  script:
    - pip install pyyaml
    - python scripts/send_email.py \
        --instance "$INSTANCE" \
        --json "prod_argocd_stat_applications_nprod_project_${INSTANCE}.json"
  rules:
    - if: '$CI_PIPELINE_SCHEDULED == "true"'
    - exists:
        - "prod_argocd_stat_applications_nprod_project_${INSTANCE}.json"

🗓️ Envoi automatique tous les lundis à 09h00
1. Aller dans GitLab → CI/CD → Schedules

Créer un schedule par instance :

🔹 ETNA
Champ	Valeur
Description	notify-etna
Interval	Custom
Crontab	0 9 * * 1
Run for	Main branch
Variable	INSTANCE=etna
🔹 HELIOS
Champ	Valeur
Description	notify-helios
Interval	Custom
Crontab	0 9 * * 1
Variable	INSTANCE=helios
🔹 CALLIOPE
Champ	Valeur
Description	notify-calliope
Interval	Custom
Crontab	0 9 * * 1
Variable	INSTANCE=calliope

📌 Signification de la crontab :

0 9 * * 1  →  Tous les lundis à 09h00

2. Arrêt automatique

Grâce à :

if [[ "$TODAY" > "$DATE_LIMIT" ]]; then exit 0; fi


AUCUNE notification n’est envoyée après la date limite.

🎯 Résultat final

Le système :

s'exécute automatiquement chaque lundi à 09:00

collecte les applications nprod par instance

génère les JSON d’inventaire et de statistiques

envoie les emails aux bonnes équipes

arrête automatiquement l’envoi quand la DATE_LIMIT est dépassée

fonctionne avec des tokens ArgoCD sécurisés

est entièrement automatisé dans GitLab CI/CD

Si tu veux, je peux aussi générer :
✔ un fichier JSON global fusionnant toutes les instances
✔ un tableau de bord Grafana/HTML
✔ un merge automatique de toutes les stats dans un seul rapport
