# Documentation du Projet Bernstein - Infrastructure Kubernetes

## Vue d'ensemble

Ce projet déploie une application de vote distribuée sur Kubernetes avec les composants suivants :
- **Poll** : Interface de vote
- **Worker** : Processeur de votes
- **Result** : Affichage des résultats
- **Redis** : Cache temporaire des votes
- **PostgreSQL** : Base de données persistante
- **Traefik** : Load balancer et reverse proxy
- **cAdvisor** : Monitoring des conteneurs

## Architecture

```
Internet → Traefik → Poll/Result Services → Applications
                  ↓
Worker ← Redis ← Poll
  ↓
PostgreSQL ← Result
```

---

## 📋 Fichiers de Configuration

### 🗳️ Application Poll (Interface de vote)

#### `poll.deployment.yaml`
**Rôle :** Déploie l'application de vote frontend
- **Image :** `epitechcontent/t-dop-600-poll:k8s`
- **Replicas :** 2 (haute disponibilité)
- **Limite mémoire :** 128Mi
- **Port :** 80
- **Anti-affinité :** Force les pods sur des nœuds différents
- **Variables d'environnement :**
  - `REDIS_HOST` : Connexion à Redis via ConfigMap

#### `poll.service.yaml`
**Rôle :** Expose l'application poll en interne
- **Type :** ClusterIP
- **Port :** 80 → 80
- **Selector :** app=poll

#### `poll.ingress.yaml`
**Rôle :** Expose l'application poll vers l'extérieur
- **Host :** poll.dop.io
- **Path :** / (tous les chemins)
- **Backend :** poll-service:80
- **Ingress Controller :** Traefik
- **⚠️ Correction appliquée :** Utilisation des annotations Traefik natives au lieu des annotations dépréciées

---

### 🔧 Worker (Processeur de votes)

#### `worker.deployment.yaml`
**Rôle :** Traite les votes de Redis vers PostgreSQL
- **Image :** `epitechcontent/t-dop-600-worker:k8s`
- **Replicas :** 1 (pas de réplication nécessaire)
- **Limite mémoire :** 256Mi
- **Variables d'environnement :**
  - Redis : `REDIS_HOST` (ConfigMap)
  - PostgreSQL : `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB` (ConfigMap)
  - Authentification : `POSTGRES_USER`, `POSTGRES_PASSWORD` (Secret)

---

### 📊 Application Result (Affichage des résultats)

#### `result.deployment.yaml`
**Rôle :** Affiche les résultats des votes
- **Image :** `epitechcontent/t-dop-600-result:k8s`
- **Replicas :** 2 (haute disponibilité)
- **Limite mémoire :** 128Mi
- **Port :** 80
- **Anti-affinité :** Force les pods sur des nœuds différents
- **Variables d'environnement :**
  - PostgreSQL : Configuration complète via ConfigMap et Secret

#### `result.service.yaml`
**Rôle :** Expose l'application result en interne
- **Type :** ClusterIP
- **Port :** 80 → 80
- **Selector :** app=result

#### `result.ingress.yaml`
**Rôle :** Expose l'application result vers l'extérieur
- **Host :** result.dop.io
- **Path :** / (tous les chemins)
- **Backend :** result-service:80
- **Ingress Controller :** Traefik
- **⚠️ Correction appliquée :** Utilisation des annotations Traefik natives au lieu des annotations dépréciées

---

### 💾 Base de données Redis (Cache)

#### `redis.deployment.yaml`
**Rôle :** Cache temporaire pour les votes
- **Image :** redis:5.0
- **Replicas :** 1
- **Port :** 6379
- **Restart Policy :** Always

#### `redis.service.yaml`
**Rôle :** Expose Redis en interne
- **Type :** ClusterIP
- **Port :** 6379 → 6379
- **Selector :** app=redis

#### `redis.configmap.yaml`
**Rôle :** Configuration Redis
- **REDIS_HOST :** "redis-service"

---

### 🐘 Base de données PostgreSQL (Persistante)

#### `postgres.deployment.yaml`
**Rôle :** Base de données principale pour les résultats
- **Image :** postgres:12
- **Replicas :** 1
- **Port :** 5432
- **Volume persistant :** /var/lib/postgresql/data
- **Variables d'environnement :** Configuration complète via ConfigMap et Secret

#### `postgres.service.yaml`
**Rôle :** Expose PostgreSQL en interne
- **Type :** ClusterIP
- **Port :** 5432 → 5432
- **Selector :** app=postgres

#### `postgres.volume.yaml`
**Rôle :** Stockage persistant pour PostgreSQL
- **PersistentVolume :** 1Gi, hostPath
- **PersistentVolumeClaim :** 1Gi, ReadWriteOnce
- **Path :** /var/lib/postgresql/data

#### `postgres.configmap.yaml`
**Rôle :** Configuration PostgreSQL (non-sensible)
- **POSTGRES_HOST :** "postgres-service"
- **POSTGRES_PORT :** "5432"
- **POSTGRES_DB :** "voting"

#### `postgres.secret.yaml`
**Rôle :** Données sensibles PostgreSQL (base64)
- **POSTGRES_USER :** postgres (encodé)
- **POSTGRES_PASSWORD :** postgres (encodé)

---

### 🌐 Load Balancer Traefik

#### `traefik.deployment.yaml`
**Rôle :** Reverse proxy et load balancer
- **Namespace :** kube-public
- **Image :** traefik:3.1
- **Replicas :** 1 (réduit pour éviter les problèmes d'anti-affinité sur cluster mono-nœud)
- **Service Account :** traefik-ingress-controller
- **Arguments :**
  - `--api.insecure=true` : Dashboard accessible
  - `--providers.kubernetesingress=true` : Support Kubernetes Ingress
  - `--entrypoints.web.address=:80` : Point d'entrée web
  - `--api.dashboard=true` : Dashboard activé
  - `--log.level=INFO` : Niveau de logs
- **Ports :** 80 (web), 8080 (admin)
- **Anti-affinité :** Force les pods sur des nœuds différents (problématique en mono-nœud)

#### `traefik.service.yaml`
**Rôle :** Expose Traefik vers l'extérieur
- **Namespace :** kube-public
- **Type :** NodePort
- **Ports :**
  - Web : 80 → 30021 (trafic applicatif)
  - Admin : 8080 → 30042 (dashboard)

#### `traefik.rbac.yaml`
**Rôle :** Permissions Kubernetes pour Traefik
- **ClusterRole :** Lecture des ingress, services, endpoints, nodes, endpointslices
- **ClusterRoleBinding :** Lie le rôle au ServiceAccount
- **ServiceAccount :** traefik-ingress-controller
- **⚠️ Correction appliquée :** Ajout des permissions pour `endpointslices` et `nodes`

---

### 📈 Monitoring cAdvisor

#### `cadvisor.daemonset.yaml`
**Rôle :** Monitoring des conteneurs sur tous les nœuds
- **Namespace :** kube-system
- **Image :** gcr.io/cadvisor/cadvisor:latest
- **Type :** DaemonSet (un pod par nœud)
- **Port :** 8080
- **Volumes montés :**
  - `/rootfs` : Système de fichiers racine
  - `/var/run` : Informations runtime
  - `/sys` : Informations système
  - `/var/lib/docker` : Données Docker
  - `/dev/disk` : Informations disque
- **Sécurité :** Mode privilégié requis
- **Réseau :** hostNetwork et hostPID activés
- **⚠️ Problème connu :** Échec de démarrage sur Minikube à cause des permissions du système de fichiers en lecture seule

---

## 🚀 Déploiement

### ⚠️ Corrections et Optimisations Appliquées

#### **Problèmes Traefik résolus :**
1. **Permissions RBAC insuffisantes** :
   - Ajout des permissions pour `endpointslices` dans l'API `discovery.k8s.io`
   - Ajout des permissions pour `nodes` dans l'API core
   
2. **Configuration Ingress** :
   - Remplacement des annotations dépréciées `kubernetes.io/ingress.class`
   - Utilisation des annotations Traefik natives : `traefik.ingress.kubernetes.io/router.entrypoints: web`

3. **Anti-affinité sur cluster mono-nœud** :
   - Réduction des replicas Traefik de 2 à 1 pour éviter les pods en Pending
   - Les autres applications (Poll, Result) gardent 2 replicas dont 1 en Pending (normal)

#### **Problèmes connus non critiques :**
- **cAdvisor** : Échec de démarrage sur Minikube (permissions filesystem)
- **Pods en Pending** : Dus à l'anti-affinité sur un cluster à nœud unique

### Ordre de déploiement recommandé :

0. **Démarrer Minikube**
   ```bash
   minikube start
   ```

1. **Secrets et ConfigMaps**
   ```bash
   kubectl apply -f postgres.secret.yaml
   kubectl apply -f postgres.configmap.yaml
   kubectl apply -f redis.configmap.yaml
   kubectl apply -f result.configmap.yaml
   kubectl apply -f poll.configmap.yaml
   ```

2. **Volumes persistants**
   ```bash
   kubectl apply -f postgres.volume.yaml
   ```

3. **Bases de données**
   ```bash
   kubectl apply -f redis.deployment.yaml -f redis.service.yaml
   kubectl apply -f postgres.deployment.yaml -f postgres.service.yaml
   ```

4. **Applications**
   ```bash
   kubectl apply -f worker.deployment.yaml
   kubectl apply -f poll.deployment.yaml -f poll.service.yaml
   kubectl apply -f result.deployment.yaml -f result.service.yaml
   ```

5. **Load balancer et Ingress**
   ```bash
   kubectl apply -f traefik.rbac.yaml
   kubectl apply -f traefik.deployment.yaml -f traefik.service.yaml
   # Réduire les replicas pour éviter les problèmes d'anti-affinité
   kubectl scale deployment traefik --replicas=1 -n kube-public
   kubectl apply -f poll.ingress.yaml -f result.ingress.yaml
   ```

6. **Monitoring**
   ```bash
   kubectl apply -f cadvisor.daemonset.yaml
   ```

### Initialisation de la base de données :
```bash
# Attendre que PostgreSQL soit prêt
kubectl wait --for=condition=ready pod -l app=postgres --timeout=60s

# Créer la table votes
echo "CREATE TABLE IF NOT EXISTS votes (id text PRIMARY KEY, vote text NOT NULL);" | \
kubectl exec -i $(kubectl get pod -l app=postgres -o jsonpath='{.items[0].metadata.name}') -c postgres -- psql -U postgres -d voting
```

### Configuration DNS locale :
```bash
echo "$(minikube ip) poll.dop.io result.dop.io" | sudo tee -a /etc/hosts
```

### Accès au Dashboard Traefik :
```bash
# Via port-forward (recommandé)
kubectl port-forward -n kube-public $(kubectl get pod -n kube-public -l app=traefik -o jsonpath='{.items[0].metadata.name}') 8080:8080

# Puis accéder à : http://localhost:8080/dashboard/
```

---

## 🌍 URLs d'accès

- **Application Poll** : ✅ http://poll.dop.io:30021
- **Application Result** : ✅ http://result.dop.io:30021
- **Dashboard Traefik** : http://localhost:8080/dashboard/ (via port-forward)
- **API Traefik** : http://localhost:8080/api/ (via port-forward)
- **cAdvisor** : ❌ Non fonctionnel sur Minikube (problème de permissions)

---

## 📝 Notes importantes

- **Haute disponibilité :** Les services Poll, Result et Traefik utilisent l'anti-affinité
- **⚠️ Cluster mono-nœud :** Sur Minikube, l'anti-affinité cause des pods en Pending (normal)
- **Sécurité :** Les mots de passe PostgreSQL sont stockés dans des Secrets Kubernetes
- **Persistance :** Seul PostgreSQL utilise un stockage persistant
- **Réseau :** Traefik gère tout le trafic entrant et la terminaison SSL
- **Monitoring :** cAdvisor fournit des métriques détaillées des conteneurs (non fonctionnel sur Minikube)

## 🔧 Commandes de Diagnostic

### Vérifier l'état des composants :
```bash
kubectl get all --all-namespaces
kubectl get ingress
kubectl get pv,pvc
```

### Diagnostiquer Traefik :
```bash
kubectl logs -n kube-public $(kubectl get pod -n kube-public -l app=traefik -o jsonpath='{.items[0].metadata.name}')
kubectl describe ingress poll-ingress
```

### Tester les applications :
```bash
# Test direct des services
kubectl port-forward service/poll-service 8081:80 &
curl http://localhost:8081

# Test via Ingress
curl -H "Host: poll.dop.io" http://$(minikube ip):30021
```

## 🗑️ Nettoyage complet

### Supprimer tous les composants :
```bash
kubectl delete ingress poll-ingress result-ingress
kubectl delete deployment traefik -n kube-public
kubectl delete service traefik-service -n kube-public
kubectl delete deployment poll result worker postgres redis
kubectl delete service poll-service result-service postgres-service redis-service
kubectl delete pvc postgres-pvc
kubectl delete pv postgres-pv
kubectl delete configmap postgres-config redis-config result-config poll-config
kubectl delete secret postgres-secret
kubectl delete clusterrolebinding traefik-ingress-controller
kubectl delete clusterrole traefik-ingress-controller
kubectl delete serviceaccount traefik-ingress-controller -n kube-public
kubectl delete daemonset cadvisor -n kube-system
```