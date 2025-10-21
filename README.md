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

---------------------------------------------------------------------------------------------------------------------------------------------------------------



# 🚀 Démo : Helm + GitLab CI/CD + ArgoCD pour Tomcat + PostgreSQL (dépendances packagées et non packagées)

## 🎯 Objectif
Déployer simultanément une application Tomcat et une base PostgreSQL via Helm avec une chart Artifactory standard pour chaque composant. La chart parent GitLab gère les valeurs spécifiques et les templates additionnels. Le déploiement peut se faire depuis ArgoCD UI ou GitLab CI/CD, sans passer de commandes Helm manuelles.

---

## 🧱 Structure des repos

```
artifactory/
├── tomcat-app/           # Chart Helm standard Tomcat
│   ├── Chart.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── ingress.yaml
└── postgres-app/         # Chart Helm standard PostgreSQL
    ├── Chart.yaml
    └── templates/
        ├── deployment.yaml
        └── service.yaml

gitlab-app/               # Chart parent GitLab
├── Chart.yaml
├── values.yaml
└── templates/
    └── configmap.yaml    # pour Tomcat (ex: data.txt)
```

---

## 1️⃣ Chart Tomcat standard (Artifactory)

Chart.yaml
```
apiVersion: v2
name: tomcat-app
description: Chart Tomcat standard
type: application
version: 1.0.0
appVersion: "1.0.0"
```

templates/deployment.yaml
```
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
          envFrom:
            - configMapRef:
                name: tomcat-config
```

templates/service.yaml
```
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
```

templates/ingress.yaml
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "tomcat-app.fullname" . }}
spec:
  rules:
    - host: {{ .Values.ingress.host | default "example.com" }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ include "tomcat-app.fullname" . }}
                port:
                  number: {{ .Values.service.port | default 80 }}
```

> Pas de `values.yaml` nécessaire, toutes les valeurs sont fournies par la chart parent.

---

## 2️⃣ Chart PostgreSQL standard (Artifactory)

Chart.yaml
```
apiVersion: v2
name: postgres-app
description: Chart PostgreSQL standard
type: application
version: 1.0.0
appVersion: "13.4"
```

templates/deployment.yaml
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "postgres-app.fullname" . }}
spec:
  replicas: {{ .Values.replicaCount | default 1 }}
  selector:
    matchLabels:
      app: {{ include "postgres-app.name" . }}
  template:
    metadata:
      labels:
        app: {{ include "postgres-app.name" . }}
    spec:
      containers:
        - name: postgres
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          env:
            - name: POSTGRES_DB
              value: {{ .Values.postgresDatabase }}
            - name: POSTGRES_USER
              value: {{ .Values.postgresUser }}
            - name: POSTGRES_PASSWORD
              value: {{ .Values.postgresPassword }}
          ports:
            - containerPort: 5432
```

templates/service.yaml
```
apiVersion: v1
kind: Service
metadata:
  name: {{ include "postgres-app.fullname" . }}
spec:
  type: ClusterIP
  selector:
    app: {{ include "postgres-app.name" . }}
  ports:
    - protocol: TCP
      port: 5432
      targetPort: 5432
```

---

## 3️⃣ Chart parent GitLab (multi-dependencies)

Chart.yaml
```
apiVersion: v2
name: gitlab-app
version: 0.1.0
appVersion: "1.0.0"
dependencies:
  - name: tomcat-app
    version: "1.0.0"
    repository: "https://artifactory.example.com/artifactory/helm-local"
  - name: postgres-app
    version: "1.0.0"
    repository: "https://artifactory.example.com/artifactory/helm-local"
```

values.yaml
```
tomcat-app:
  image:
    repository: artifactory.example.com/docker/tomcat-app
    tag: "1.1.0"
  replicaCount: 2
  ingress:
    host: "tomcat.example.com"
  service:
    port: 80

postgres-app:
  image:
    repository: artifactory.example.com/docker/postgres-app
    tag: "13.4"
  replicaCount: 1
  postgresDatabase: mydb
  postgresUser: appuser
  postgresPassword: secret123

configMap:
  data_txt: |
    url=http://tomcat.example.com
    health=/live
```

templates/configmap.yaml
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: tomcat-config
data:
  data.txt: {{ .Values.configMap.data_txt | quote }}
```

---

## 4️⃣ Déploiement via ArgoCD

1. Ajouter les repos Artifactory Helm dans ArgoCD :
```
argocd repo add https://artifactory.example.com/artifactory/helm-local \
  --type helm --username $ARTIFACTORY_USER --password $ARTIFACTORY_PASSWORD
```

2. Déployer l’application via ArgoCD UI ou application manifest :
```
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
```

---

## 5️⃣ Déploiement via GitLab CI/CD

.gitlab-ci.yml
```
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
```

> CI déclenche automatiquement la synchronisation ArgoCD, aucun `helm install` manuel nécessaire.

---

## 6️⃣ Cas non packagé vs packagé

- **Non packagé** : GitLab parent référence directement le repo Artifactory Helm via `repository:` dans Chart.yaml. Helm télécharge les templates au moment du déploiement.  
- **Packagé** : les charts Tomcat et PostgreSQL sont packagées (`.tgz`) et stockées dans Artifactory. La chart parent référence la version packagée avec `version:` et `repository:`. Le déploiement reste identique pour ArgoCD ou CI/CD.

> L’avantage du non packagé est de toujours récupérer les dernières modifications de la chart Artifactory, mais tu peux stabiliser avec la version packagée pour la production.

---

## 7️⃣ Points clés

1. Charts Tomcat et PostgreSQL **standards** → réutilisables pour toutes les applications.  
2. GitLab parent fournit **les valeurs et templates additionnels** (`configmap`, secrets, DB).  
3. Déploiement possible via **ArgoCD UI** ou **GitLab CI/CD** sans commandes manuelles.  
4. Flexibilité totale : Docker tag, replicas, sources de données (`data.txt` ou PostgreSQL) configurables depuis GitLab.  
5. Peut gérer **multi-dependances** et **multi-applications** avec la même approche.  







