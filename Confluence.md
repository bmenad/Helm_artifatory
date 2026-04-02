# 📊 ArgoCD Resizing Multi-Couches basé sur Analyse Réelle (OpenShift)

---

## 🎯 Objectif

Mettre en place une stratégie de **resizing ArgoCD basée sur des données réelles (monitoring OpenShift)** afin de :

* Adapter dynamiquement l’offre ArgoCD aux usages clients
* Standardiser les tailles d’instances (**XS → XL**)
* Optimiser l’utilisation des ressources cluster
* Garantir performance, stabilité et scalabilité

---

## 📈 Méthodologie Globale

La démarche repose sur **3 piliers** :

1. **Analyse réelle de la consommation (14 jours)**
2. **Modélisation d’une offre standardisée par taille**
3. **Application d’une logique de configuration multi-couches (layering)**

---

## 🔍 1. Analyse préalable (basée sur données réelles)

### 📅 Périmètre

* Source : OpenShift Monitoring (Prometheus / Grafana)
* Période : **04 mars → 18 mars (14 jours)**
* Métriques :

  * Consommation moyenne CPU / mémoire
  * Pics CPU / mémoire
  * Nombre d’applications
  * Nombre de repositories
  * Nombre de clusters

---

### 🧪 Instances analysées

| Instance | Apps | Repos | Clusters | Taille |
| -------- | ---- | ----- | -------- | ------ |
| IZARU    | 2167 | 983   | 14       | XL     |
| TAAL     | 1467 | 112   | 24       | L      |
| FUDJI    | 759  | 506   | 35       | M      |
| ATLAS    | 314  | 106   | 8        | S      |
| ETNA     | 41   | 25    | 19       | XS     |

---

### 📊 Observations clés

#### 🧠 Controller

* Forte corrélation avec le nombre d’applications
* Pics CPU élevés (jusqu’à ~4 CPU)
* Composant dimensionnant principal

#### 📦 Repo Server

* Sensible au volume et taille des repos
* Pics mémoire importants (jusqu’à ~6 Go)

#### 🌐 Server / Redis / Dex

* Consommation stable et prévisible

---

## 🧩 2. Modélisation des tailles

| Taille | Nb Apps   | Nb Repos |
| ------ | --------- | -------- |
| XS     | <100      | <50      |
| S      | 100–500   | 50–200   |
| M      | 500–1000  | 200–500  |
| L      | 1000–2000 | 500–1000 |
| XL     | >2000     | >1000    |

---

## ⚙️ 3. Stratégie de Resizing Multi-Couches (Layering)

### 🎯 Objectif

Mettre en place une **configuration flexible, factorisée et maintenable** basée sur une logique de priorité :

```
BASE < SIZE < OVERRIDES
```

---

### 🥇 Couche 1 — Base (socle commun)

Définit :

* Les valeurs par défaut
* Le minimum garanti
* La cohérence globale de la plateforme

👉 Exemple :

```yaml
global:
  resources:
    controller:
      requests:
        cpu: 200m
        memory: 2Gi
      limits:
        cpu: 1
        memory: 4Gi
```

---

### 🥈 Couche 2 — Taille (XS → XL)

Spécialise les ressources en fonction du **profil de charge**

👉 Exemple (taille M) :

```yaml
sizes:
  M:
    controller:
      requests:
        cpu: 1
        memory: 6Gi
      limits:
        cpu: 3
        memory: 8Gi
```

👉 Cette couche :

* surcharge la base
* reflète le dimensionnement issu de l’analyse réelle

---

### 🥉 Couche 3 — Overrides (spécifique instance)

Permet d’adapter finement pour :

* un client spécifique
* un comportement atypique
* un besoin temporaire

👉 Exemple :

```yaml
overrides:
  controller:
    limits:
      cpu: 4
```

---

### 🔄 Logique de fusion

Priorité d’application :

1. Base (valeurs par défaut)
2. Taille (standardisation)
3. Overrides (exception)

👉 Résultat final = **merge des 3 couches**

---

### 🧠 Avantages de cette approche

* ✅ Standardisation forte
* ✅ Réduction du duplication YAML
* ✅ Flexibilité maximale
* ✅ Adaptation rapide sans refactor global
* ✅ Compatible GitOps / Helm

---

## 📊 4. Matrice de dimensionnement cible

### 🧠 Controller

| Taille | CPU Req | CPU Lim | Mem Req | Mem Lim | Sharding |
| ------ | ------- | ------- | ------- | ------- | -------- |
| XS     | 200m    | 1       | 2Gi     | 4Gi     | 1        |
| S      | 500m    | 2       | 4Gi     | 6Gi     | 1        |
| M      | 1       | 3       | 6Gi     | 8Gi     | 2        |
| L      | 2       | 4       | 8Gi     | 10Gi    | 2        |
| XL     | 3       | 5       | 10Gi    | 12Gi    | 3        |

---

### 📦 Repo Server

| Taille | CPU Req | CPU Lim | Mem Req | Mem Lim | Replicas |
| ------ | ------- | ------- | ------- | ------- | -------- |
| XS     | 100m    | 500m    | 1Gi     | 2Gi     | 1        |
| S      | 250m    | 1       | 2Gi     | 4Gi     | 1        |
| M      | 500m    | 2       | 4Gi     | 8Gi     | 2        |
| L      | 1       | 3       | 6Gi     | 12Gi    | 2        |
| XL     | 2       | 4       | 8Gi     | 16Gi    | 3        |

---

### 🌐 Server

| Taille | CPU Req | CPU Lim | Mem Req | Mem Lim |
| ------ | ------- | ------- | ------- | ------- |
| XS     | 100m    | 500m    | 256Mi   | 512Mi   |
| S      | 200m    | 1       | 512Mi   | 1Gi     |
| M      | 300m    | 1.5     | 1Gi     | 2Gi     |
| L      | 500m    | 2       | 1.5Gi   | 3Gi     |
| XL     | 1       | 3       | 2Gi     | 4Gi     |

---

## 🚀 5. Implémentation

```bash
helm upgrade argocd ./chart -f values.yaml
```

---

## 🔍 6. Vérification

```bash
oc get pods
oc top pods
```

---

## 📉 7. Gains observés

* Réduction du surdimensionnement
* Meilleure absorption des pics
* Optimisation cluster OpenShift

---

## 🔄 8. Stratégie d’évolution

* Revue trimestrielle
* Ajustement selon croissance
* Possibilité d’automatisation future

---

## 🧠 Conclusion

Le passage à une logique **BASE < SIZE < OVERRIDES** permet :

* 🧩 Une architecture configurable et propre
* 📊 Une cohérence avec les données terrain
* 🚀 Une scalabilité maîtrisée

👉 Le resizing devient un **modèle industriel et réutilisable**
