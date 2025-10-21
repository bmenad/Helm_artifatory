# 🚀 Démo complète : Helm + GitLab CI/CD + Artifactory + ArgoCD (Dépendance non packagée)

## 🎯 Objectif
Cette démo illustre un pipeline Kubernetes complet utilisant Helm, Artifactory, GitLab CI/CD et ArgoCD.  
Elle met en avant la gestion dynamique des dépendances Helm : la chart GitLab dépend d’une chart Tomcat stockée dans Artifactory **sans être packagée** localement, et Helm résout la dépendance à la volée.

## 🧱 Structure du projet
demo/
├── tomcat-app/             # Chart Helm Tomcat (hébergée dans Artifactory)
│   ├── Chart.yaml
│   ├── templates/
│   └── values.yaml
├── gitlab-app/             # Chart Helm GitLab (dans Git)
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── templates/
│   └── .gitlab-ci.yml
└── argocd/
    └── application.yaml    # Définition ArgoCD

## ⚙️ 1. Chart Helm Tomcat App
tomcat-app/Chart.yaml
apiVersion: v2
name: tomcat-app
description: Simple Tomcat application chart
type: application
version: 1.1.0
appVersion: "1.1.0"

tomcat-app/values.yaml
image:
  repository: artifactory.example.com/myproject/tomcat-app
  tag: "1.1.0"
replicaCount: 1

## 📦 2. Publication dans Artifactory (non packagée)
# Depuis tomcat-app/
helm lint .

# Pousser directement les fichiers YAML vers Artifactory
curl -u user:password -T Chart.yaml "https://artifactory.example.com/artifactory/helm-local/tomcat-app/Chart.yaml"
curl -u user:password -T values.yaml "https://artifactory.example.com/artifactory/helm-local/tomcat-app/values.yaml"
# Pour le dossier templates/, tu peux zipper et uploader ou utiliser un outil CI/CD pour copier le répertoire
# Artifactory indexera automatiquement les fichiers pour Helm

## 🔧 3. Chart GitLab App (dépendance non packagée)
gitlab-app/Chart.yaml
apiVersion: v2
name: gitlab-app
description: GitLab demo app using tomcat dependency from Artifactory
type: application
version: 0.1.0
appVersion: "1.0.0"
dependencies:
  - name: tomcat-app
    version: "1.1.0"
    repository: "https://artifactory.example.com/artifactory/helm-local"

gitlab-app/values.yaml
tomcat-app:
  replicaCount: 2
  image:
    tag: "1.1.0"

⚠️ Important : **Ne pas faire de `helm dependency update` ou packager la dépendance**.  
Helm (ou ArgoCD) résout la dépendance directement depuis Artifactory.

## 🧰 4. Pipeline GitLab CI/CD
.gitlab-ci.yml
stages:
  - lint
  - deploy
lint_chart:
  stage: lint
  image: alpine/helm:3.14.0
  script:
    - helm lint .
deploy_to_argocd:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - echo "Trigger ArgoCD sync via webhook"
    - curl -X POST "$ARGOCD_SYNC_WEBHOOK_URL"

## 🌐 5. Configuration ArgoCD
# Ajouter le repo Artifactory à ArgoCD
argocd repo add https://artifactory.example.com/artifactory/helm-local \
  --type helm \
  --username $ARTIFACTORY_USER \
  --password $ARTIFACTORY_PASSWORD

argocd/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gitlab-demo
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://gitlab.com/your-org/gitlab-helm-demo.git'
    targetRevision: main
    path: gitlab-app
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true

## 🔄 6. Scénario de démo
1. Le développeur met à jour la chart `tomcat-app` → version 1.1.0 → push direct dans Artifactory  
2. `gitlab-app/Chart.yaml` référence la version mise à jour  
3. ArgoCD (auto-sync activé) détecte le changement  
4. ArgoCD télécharge la dépendance directement depuis Artifactory et met à jour le déploiement automatiquement

## ✅ Résultat
- Aucun `.tgz` packagé ou versionné dans Git  
- ArgoCD récupère les dépendances à la volée depuis Artifactory  
- Pipeline plus léger et réactif  
- Déploiement automatisé et traçable via Git et ArgoCD



