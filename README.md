# 🚀 Démo complète : Helm + GitLab CI/CD + Artifactory + ArgoCD (Dépendance non packagée)

## 🎯 Objectif
Cette démo illustre un pipeline Kubernetes complet utilisant Helm, Artifactory, GitLab CI/CD et ArgoCD. La chart GitLab dépend d’une chart Tomcat stockée dans Artifactory sans être packagée localement, et Helm résout la dépendance à la volée.

## 🧱 Structure des repos
demo/
├── tomcat-app/             # Chart Helm Tomcat
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/deployment.yaml
├── gitlab-app/             # Chart Helm GitLab
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── templates/configmap.yaml
│   └── .gitlab-ci.yml
└── argocd/
    └── application.yaml

## ⚙️ 1. Chart Helm tomcat-app
Chart.yaml
apiVersion: v2
name: tomcat-app
description: Tomcat app
type: application
version: 1.1.0
appVersion: "1.1.0"

values.yaml
image:
  repository: artifactory.example.com/docker/tomcat-app
  tag: "1.0.0"  # ou 1.1.0
replicaCount: 1

templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "tomcat-app.fullname" . }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ include "tomcat-app.name" . }}
  template:
    metadata:
      labels:
        app: {{ include "tomcat-app.name" . }}
    spec:
      containers:
        - name: tomcat
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports:
            - containerPort: 8080

## 📦 2. Publication tomcat-app dans Artifactory (non packagée)
helm lint .

# Pousser directement les fichiers YAML vers Artifactory
curl -u user:password -T Chart.yaml "https://artifactory.example.com/artifactory/helm-local/tomcat-app/Chart.yaml"
curl -u user:password -T values.yaml "https://artifactory.example.com/artifactory/helm-local/tomcat-app/values.yaml"
# Pour templates/, copier le dossier complet ou via CI/CD
# Helm indexe automatiquement la chart pour être résolue à la volée

## 🔧 3. Chart Helm gitlab-app (dépendance non packagée)
Chart.yaml
apiVersion: v2
name: gitlab-app
description: GitLab app with Tomcat dependency
type: application
version: 0.1.0
appVersion: "1.0.0"
dependencies:
  - name: tomcat-app
    version: "1.1.0"
    repository: "https://artifactory.example.com/artifactory/helm-local"

values.yaml
tomcat-app:
  replicaCount: 2
  image:
    tag: "1.1.0"

templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: gitlab-config
data:
  welcome: "GitLab demo app using Tomcat dependency"

⚠️ Important : Ne pas faire de `helm dependency update` ou packager la dépendance. Helm/ArgoCD résout directement depuis Artifactory.

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
  image: curlimages/curl:latest
  script:
    - curl -X POST "$ARGOCD_SYNC_WEBHOOK_URL"

## 🌐 5. ArgoCD configuration
argocd repo add https://artifactory.example.com/artifactory/helm-local --type helm --username $ARTIFACTORY_USER --password $ARTIFACTORY_PASSWORD

application.yaml
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
1. Build Docker Tomcat v1.0.0 et v1.1.0 → push dans Artifactory
2. Mettre à jour `gitlab-app/values.yaml` si changement de version
3. ArgoCD détecte les changements et synchronise automatiquement
4. Helm résout la dépendance non packagée depuis Artifactory → déploiement automatique

## ✅ Résultat attendu
- Aucun `.tgz` packagé ou versionné
- ArgoCD récupère la dépendance directement depuis Artifactory
- Pipeline plus léger et réactif
- Déploiement automatisé et traçable via Git et ArgoCD
