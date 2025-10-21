# 🚀 Démo complète : Helm + GitLab CI/CD + Artifactory + ArgoCD

## 🎯 Objectif
Cette démo illustre un pipeline Kubernetes complet utilisant Helm, Artifactory, GitLab CI/CD et ArgoCD. Elle met en avant la gestion dynamique des dépendances Helm — où une application GitLab dépend d’une chart Tomcat hébergée dans Artifactory.

## 🧱 Architecture globale
demo/
├── tomcat-app/             # Chart Helm Tomcat (stockée et publiée dans Artifactory)
├── gitlab-app/             # Chart Helm GitLab (stockée dans un repo Git)
└── argocd/                 # Application ArgoCD déployant gitlab-app

## ⚙️ 1. Chart Helm Tomcat App
tomcat-app/Chart.yaml
apiVersion: v2
name: tomcat-app
description: Simple Tomcat application chart
type: application
version: 1.0.0
appVersion: "1.0.0"

tomcat-app/values.yaml
image:
  repository: artifactory.local/myproject/tomcat-app
  tag: "1.0.0"
replicaCount: 1

tomcat-app/templates/deployment.yaml
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

## 🔧 2. Chart Helm GitLab App (dépendance dynamique)
gitlab-app/Chart.yaml
apiVersion: v2
name: gitlab-app
description: GitLab demo app using tomcat dependency
type: application
version: 0.1.0
appVersion: "1.0.0"
dependencies:
  - name: tomcat-app
    version: "1.0.0"
    repository: "https://artifactory.local/artifactory/helm-local"

gitlab-app/values.yaml
tomcat-app:
  image:
    tag: "1.1.0"
  replicaCount: 2

## 🧰 3. Pipeline GitLab CI/CD
.gitlab-ci.yml
stages:
  - package
  - publish
variables:
  CHART_NAME: "tomcat-app"
  CHART_VERSION: "1.1.0"
  ARTIFACTORY_URL: "https://artifactory.local/artifactory/helm-local"
  ARTIFACTORY_USER: "$ARTIFACTORY_USER"
  ARTIFACTORY_PASSWORD: "$ARTIFACTORY_PASSWORD"
package_chart:
  stage: package
  image: alpine/helm:3.14.0
  script:
    - helm lint .
    - helm package . --version ${CHART_VERSION}
  artifacts:
    paths:
      - ${CHART_NAME}-${CHART_VERSION}.tgz
publish_chart:
  stage: publish
  image: curlimages/curl:latest
  script:
    - curl -u ${ARTIFACTORY_USER}:${ARTIFACTORY_PASSWORD} -T ${CHART_NAME}-${CHART_VERSION}.tgz "${ARTIFACTORY_URL}/${CHART_NAME}-${CHART_VERSION}.tgz"
  needs:
    - job: package_chart

## 🌐 4. Configuration ArgoCD
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

## 🔄 5. Scénario de démo
1. Un développeur met à jour tomcat-app  
2. GitLab CI package & push vers Artifactory  
3. gitlab-app référence la nouvelle version dans Chart.yaml  
4. ArgoCD détecte le changement et déploie automatiquement la nouvelle dépendance

