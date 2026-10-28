# REGISTRE DES DÉCISIONS D'ARCHITECTURE (ADR)
**Architecture AWS — Plateforme CineTrekker (Livrables L1-L3)**

---

### ADR-01 : Choix d'une Instance NAT EC2 plutôt qu'un NAT Gateway managé
* **Statut** : Validé (exigence L3).
* **Contexte** : Les instances applicatives situées en sous-réseaux privés ont besoin d'accéder à Internet pour télécharger des paquets Linux et contacter certaines APIs de métadonnées.
* **Option A** : AWS Managed NAT Gateway (0,045 $/h + trafic = ~32,40 $/mois).
* **Option B** : Instance EC2 NAT minimale `t3.micro` avec `iptables-nft` (~0,0104 $/h = ~7,50 $/mois si continu, et ~0,03 $ par séance de 3h).
* **Décision** : **Option B retenue.** Le NAT Gateway managé épuiserait plus de 60% du budget de 50$ en quelques semaines. L'instance NAT est entièrement provisionnée par IaC avec `source_dest_check = false` et un script de masquerading automatique.
* **Conséquences / Limitations** : L'instance NAT constitue un point unique de défaillance (SPOF) pour le trafic sortant non-S3. Ce compromis est pleinement documenté et acceptable dans le cadre d'un compte étudiant gratuit.

---

### ADR-02 : Utilisation du VPC Gateway Endpoint pour Amazon S3
* **Statut** : Validé.
* **Contexte** : Les instances applicatives transfèrent l'archive applicative `cinetrekker.tar.gz` depuis Amazon S3 au démarrage.
* **Décision** : Mise en place d'un `aws_vpc_endpoint` de type `Gateway` pour Amazon S3 rattaché aux tables de routage publique et privée.
* **Bénéfices** : Le trafic S3 ne traverse ni l'Internet Gateway ni l'instance NAT. Il reste sur le réseau dorsal AWS interne, est 100% gratuit, offre une latence minimale et fonctionne même si l'instance NAT est arrêtée.

---

### ADR-03 : Architecture Stateless et Découplage de la Persistance
* **Statut** : Validé.
* **Contexte** : Les instances applicatives EC2 doivent être jetables et remplaçables à tout moment par l'Auto Scaling Group sans perte de données.
* **Décision** : L'application CineTrekker est conçue de façon purement stateless. Aucune donnée durable n'est stockée sur le disque local de l'instance EC2. La persistance relationnelle est isolée dans son propre tiers de sous-réseaux dédiés.
