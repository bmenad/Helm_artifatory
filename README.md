# 🚀 Démo : Helm + GitLab CI/CD + Artifactory + ArgoCD (Dépendance non packagée, ConfigMap Git)

## 🎯 Objectif
Déployer une application Tomcat Docker via une chart Helm Artifactory (v1.0.0) tout en utilisant une chart GitLab parent (v1.1.0) pour surcharger l’image Docker et injecter une configuration via ConfigMap. Helm résout la dépendance Artifactory à la volée, sans packager la chart, et sans `values.yaml` dans Artifactory.

## 🧱 Structure des repos

demo/
├── tomcat-app/             
│   ├── Chart.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── ingress.yaml
├── gitlab-app/             
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/configmap.yaml
└── argocd/
    └── application.yaml

---

## 1️⃣ Chart Helm tomcat-app (Artifactory, v1.0.0)

Chart.yaml
apiVersion: v2
name: tomcat-app
description: Tomcat Helm chart
type: application
version: 1.0.0
appVersion: "1.0.0"

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

templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "tomcat-app.fullname" . }}
spec:
  type: ClusterIP
  selector:
    app: {{ include "tomcat-app.name" . }}
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080

templates/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "tomcat-app.fullname" . }}
spec:
  rules:
    - host: myservice.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ include "tomcat-app.fullname" . }}
                port:
                  number: 80

> Remarque : pas de `values.yaml` nécessaire. Les valeurs sont fournies par la chart parent.

---

## 2️⃣ Chart Helm gitlab-app (parent, v1.1.0)

Chart.yaml
apiVersion: v2
name: gitlab-app
description: GitLab Helm chart parent utilisant tomcat-app depuis Artifactory
type: application
version: 0.1.0
appVersion: "1.1.0"
dependencies:
  - name: tomcat-app
    version: "1.0.0"
    repository: "https://artifactory.example.com/artifactory/helm-local"

values.yaml
tomcat-app:
  image:
    repository: artifactory.example.com/docker/tomcat-app
    tag: "1.1.0"
  replicaCount: 2

configMap:
  url: "http://myservice-v1-1.example.com"
  health: "/live"

templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tomcat-config
data:
  url: {{ .Values.configMap.url }}
  health: {{ .Values.configMap.health }}

> Helm merge les valeurs pour surcharger le Docker tag et injecter le ConfigMap. Les templates Artifactory restent inchangés.

---

## 3️⃣ Pipeline GitLab CI/CD

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

- Pas de `.tgz` nécessaire.  
- CI déclenche la synchronisation ArgoCD.

---

## 4️⃣ ArgoCD application

Ajouter le repo Artifactory :
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

---

## 5️⃣ Déploiement étape par étape

1. Build Docker Tomcat :
docker build -t artifactory.example.com/docker/tomcat-app:1.0.0 .
docker push artifactory.example.com/docker/tomcat-app:1.0.0
docker build -t artifactory.example.com/docker/tomcat-app:1.1.0 .
docker push artifactory.example.com/docker/tomcat-app:1.1.0

2. Pousser chart tomcat-app non packagée dans Artifactory.  
3. Mettre à jour `gitlab-app/values.yaml` si nécessaire pour Docker v1.1.0 et ConfigMap.  
4. ArgoCD synchronise automatiquement le déploiement.

---

## 6️⃣ Points clés pour la démo

- Artifactory chart stable : tous les templates (`deployment`, `service`, `ingress`) inclus.  
- GitLab chart : values.yaml + configmap.yaml seulement.  
- Helm merge automatiquement les valeurs et ArgoCD applique la mise à jour.  
- Illustre clairement la flexibilité des dépendances non packagées et la gestion de versions différentes.
