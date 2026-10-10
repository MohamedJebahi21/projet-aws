# RAPPORTS D'INCIDENT TYPES — ÉPREUVE D'EXPLOITATION (SEMAINE 13)
**Modèles de diagnostic et remédiation pour chaque panne de l'Annexe C**

---

### INCIDENT 01 : Terminaison Manuelle d'une Instance Applicative
* **Composant affecté** : Auto Scaling Group / Instances EC2 applicatives.
* **Symptôme observé** :
  * Dans la console EC2, une des 2 instances passe à l'état `shutting-down` puis `terminated`.
  * L'application reste 100% accessible via l'ALB pour les utilisateurs (aucun code 502/503 observé).
* **Méthode de diagnostic** :
  1. Tableau de bord CloudWatch -> Widget "Santé des Cibles ALB" : passage temporaire de `HealthyHostCount` de 2 à 1.
  2. Auto Scaling Group -> Historique des activités : événement `Terminating EC2 instance: i-xxxx` visible.
* **Cause racine** : Arrêt manuel ou défaillance matérielle sous-jacente de l'instance dans la zone `us-east-1a`.
* **Action corrective** : Aucune intervention manuelle nécessaire. L'Auto Scaling Group a automatiquement détecté l'écart entre la capacité souhaitée (2) et la capacité réelle (1), et a immédiatement lancé une nouvelle instance de remplacement.
* **Temps de rétablissement (MTTR)** : 2 minutes 35 secondes (initialisation + user data).
* **Mesure préventive** : Architecture multi-AZ et `min_size = 2` garantissent la tolérance de panne sans impact utilisateur.

---

### INCIDENT 02 : Altération du Chemin de Contrôle de Santé ALB
* **Composant affecté** : Target Group de l'Application Load Balancer (`biblio-dev-tg`).
* **Symptôme observé** :
  * L'accès au site renvoie une erreur HTTP 503 "Service Unavailable".
  * L'alarme CloudWatch `biblio-dev-alarm-unhealthy-hosts` passe à l'état `ALARM`.
* **Méthode de diagnostic** :
  1. Notification CloudWatch Alarms : `UnHealthyHostCount >= 1` déclenchée.
  2. Inspection de la cible : Target Group -> Onglet Targets : statut `Unhealthy` avec le message `Target.FailedHealthCheck - Status code returned: 404`.
  3. Vérification des paramètres du Target Group : le chemin de contrôle est défini sur `/erreur-panne-provoquee-404` au lieu de `/health`.
* **Action corrective** :
  * Modification immédiate du Target Group pour restaurer le chemin `/health` :
    ```bash
    python scripts/chaos_repair.py health_path
    ```
* **Temps de rétablissement (MTTR)** : 45 secondes (dès le prochain intervalle de contrôle).

---

### INCIDENT 03 : Coupure d'Accès Réseau à la Base de Données RDS
* **Composant affecté** : Security Group RDS (`biblio-dev-rds-sg`).
* **Symptôme observé** :
  * Les requêtes de consultation de catalogue échouent avec un timeout ou erreur interne.
  * La route `/health` répond avec le statut HTTP 503 : `{"status": "DOWN", "database": "UNREACHABLE"}`.
* **Méthode de diagnostic** :
  1. Appel curl direct sur l'ALB : `curl -I http://<ALB_DNS>/health` renvoie code `503`.
  2. Inspection des logs applicatifs dans `/aws/ec2/biblio-dev-app` : exception `org.postgresql.util.PSQLException: Connection to <endpoint>:5432 refused / timed out`.
  3. Vérification du groupe de sécurité RDS : la règle autorisant le port 5432 depuis `biblio-dev-app-sg` a disparu.
* **Action corrective** :
  * Ré-autorisation immédiate du port 5432 depuis le groupe applicatif :
    ```bash
    python scripts/chaos_repair.py cut_db
    ```
* **Temps de rétablissement (MTTR)** : 1 minute 10 secondes.

---

### INCIDENT 04 : Modification d'un Paramètre de Connexion à la Base
* **Composant affecté** : Configuration d'environnement `/etc/library/app.env`.
* **Symptôme observé** :
  * L'application démarre mais toutes les opérations de persistance échouent avec `FATAL: password authentication failed for user "dbadmin"`.
* **Méthode de diagnostic** :
  1. Consultation des logs systemd via SSM Session Manager :
     ```bash
     journalctl -u bibliotheque.service -e
     ```
  2. Constat de rejet des identifiants d'authentification PostgreSQL.
* **Action corrective** :
  * Re-téléchargement du mot de passe authentique depuis l'objet S3 chiffré :
    ```bash
    aws s3 cp s3://<BUCKET_NAME>/secrets/db_password.txt /tmp/db_password.txt
    # Mise à jour de /etc/library/app.env et redémarrage du service systemd
    systemctl restart bibliotheque.service
    ```
* **Temps de rétablissement (MTTR)** : 2 minutes.

---

### INCIDENT 05 : Saturation du Volume EBS par Accumulation de Journaux
* **Composant affecté** : Volume EBS racine (`/dev/xvda`) de l'instance EC2.
* **Symptôme observé** :
  * L'instance ne répond plus aux requêtes. Les écritures sur disque échouent (`No space left on device`).
* **Méthode de diagnostic** :
  1. Connexion via SSM Session Manager.
  2. Commande `df -h` : la partition `/` est saturée à 100%.
  3. Commande `du -sh /var/log/*` : découverte de fichiers de logs volumineux non purgés.
* **Action corrective** :
  1. Purge immédiate des logs résiduels :
     ```bash
     truncate -s 0 /var/log/user-data.log
     journalctl --vacuum-time=1d
     ```
  2. Redémarrage du service applicatif.
* **Mesure préventive** : Rétention CloudWatch Logs active et rotation automatique configurée dans `logrotate`.

---

### INCIDENT 06 : Suppression de l'Objet S3 Nécessaire au Démarrage
* **Composant affecté** : Objet S3 `app/bibliotheque-app.jar`.
* **Symptôme observé** :
  * Les nouvelles instances lancées par l'ASG ne parviennent pas à passer au statut Healthy et sont recyclées en boucle.
* **Méthode de diagnostic** :
  1. Consultation du log User Data `/var/log/user-data.log` dans CloudWatch Logs :
     `fatal error: An error occurred (404) when calling the HeadObject operation: Key "app/bibliotheque-app.jar" does not exist`.
* **Action corrective** :
  * Ré-exécution de la publication de l'artefact JAR :
    ```powershell
    python -m awscli s3 cp app/target/bibliotheque-app.jar s3://<BUCKET_NAME>/app/bibliotheque-app.jar
    ```
* **Temps de rétablissement (MTTR)** : 1 minute 30 secondes.

---

### INCIDENT 07 : Retrait Manuel d'une Instance de son Groupe Cible (Deregistration)
* **Composant affecté** : Enregistrement Target Group ALB.
* **Symptôme observé** :
  * Une instance passe au statut `draining` puis disparaît du pool actif de l'ALB.
  * L'autre instance absorbe l'intégralité du trafic sans rupture de service.
* **Méthode de diagnostic** :
  1. Console Target Group -> Onglet Targets : une cible marquée `unused` ou absente.
  2. Auto Scaling Group -> L'ASG détecte que l'instance n'est plus saine selon le contrôle ELB et lance une nouvelle instance pour rétablir la capacité requise de 2.
* **Action corrective** :
  * Laisser l'ASG terminer le remplacement automatique, ou ré-enregistrer manuellement l'instance si elle est saine :
    ```bash
    aws elbv2 register-targets --target-group-arn <ARN> --targets Id=<INSTANCE_ID>,Port=8080
    ```
* **Temps de rétablissement (MTTR)** : 30 secondes (automatique).
