#!/usr/bin/env python3
"""
Script Python (Boto3) de suivi et d'optimisation des coûts AWS Learner Lab.
Évalue la consommation horaire, le coût projeté d'une séance et l'état du budget de 50$.
"""

import sys
import boto3
from datetime import datetime

# Tarifs publics AWS us-east-1 (Free Tier / Learner Lab)
RATES = {
    "ec2_t3_micro": 0.0104,    # USD par heure
    "rds_db_t3_micro": 0.0180, # USD par heure (PostgreSQL Single-AZ)
    "alb_hourly": 0.0225,      # USD par heure
    "ebs_gp3_per_gb_mo": 0.080 # USD par Go par mois (~0.00011 USD/Go-h)
}

def analyze_costs(prefix="biblio-dev"):
    session = boto3.session.Session(region_name="us-east-1")
    ec2 = session.client("ec2")
    rds = session.client("rds")
    elbv2 = session.client("elbv2")

    print("==========================================================")
    print("      RAPPORT DE CONSOMMATION ET SUIVI DU BUDGET AWS      ")
    print("==========================================================")
    print(f"Horodatage : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Préfixe analysé : {prefix}\n")

    hourly_total = 0.0

    # 1. Analyse EC2 (ASG + NAT)
    ec2_resp = ec2.describe_instances(
        Filters=[
            {"Name": "instance-state-name", "Values": ["running"]},
            {"Name": "tag:Prefix", "Values": [prefix]}
        ]
    )
    running_instances = []
    for res in ec2_resp.get("Reservations", []):
        for inst in res.get("Instances", []):
            running_instances.append(inst)

    ec2_cost = len(running_instances) * RATES["ec2_t3_micro"]
    hourly_total += ec2_cost
    print(f"[-] Instances EC2 actives : {len(running_instances)}")
    for inst in running_instances:
        name = next((t["Value"] for t in inst.get("Tags", []) if t["Key"] == "Name"), inst["InstanceId"])
        print(f"    * {inst['InstanceId']} ({name}) - {inst['InstanceType']} en {inst['Placement']['AvailabilityZone']}")
    print(f"    Sous-total EC2 : {ec2_cost:.4f} USD/h\n")

    # 2. Analyse ALB
    alb_resp = elbv2.describe_load_balancers()
    matching_albs = [
        lb for lb in alb_resp.get("LoadBalancers", [])
        if prefix in lb["LoadBalancerName"]
    ]
    alb_cost = len(matching_albs) * RATES["alb_hourly"]
    hourly_total += alb_cost
    print(f"[-] Load Balancers (ALB) actifs : {len(matching_albs)}")
    for lb in matching_albs:
        print(f"    * {lb['LoadBalancerName']} (DNS: {lb['DNSName']})")
    print(f"    Sous-total ALB : {alb_cost:.4f} USD/h\n")

    # 3. Analyse RDS PostgreSQL
    rds_resp = rds.describe_db_instances()
    matching_dbs = [
        db for db in rds_resp.get("DBInstances", [])
        if prefix in db["DBInstanceIdentifier"] and db["DBInstanceStatus"] == "available"
    ]
    rds_cost = len(matching_dbs) * RATES["rds_db_t3_micro"]
    hourly_total += rds_cost
    print(f"[-] Bases de données RDS actives : {len(matching_dbs)}")
    for db in matching_dbs:
        print(f"    * {db['DBInstanceIdentifier']} ({db['DBInstanceClass']}, Multi-AZ: {db['MultiAZ']})")
    print(f"    Sous-total RDS : {rds_cost:.4f} USD/h\n")

    # 4. Synthèse et projection
    print("==========================================================")
    print(f"TOTAL HORAIRE EN FONCTIONNEMENT : {hourly_total:.4f} USD / heure")
    print("==========================================================")
    print(f"Coût pour une séance de 3 heures : {hourly_total * 3:.2f} USD")
    print(f"Coût si oublié actif 24 heures   : {hourly_total * 24:.2f} USD")
    print(f"Coût si oublié actif 1 semaine   : {hourly_total * 24 * 7:.2f} USD (~{hourly_total * 24 * 7 / 50 * 100:.1f}% du crédit total !)")
    print("==========================================================")

    if hourly_total > 0:
        print("💡 CONSEIL : Lancez 'scripts/destroy.ps1' dès la fin de vos tests pour stopper les coûts.")
    else:
        print("✅ Aucune ressource facturée active. Votre budget est sécurisé.")

if __name__ == "__main__":
    prefix = sys.argv[1] if len(sys.argv) > 1 else "biblio-dev"
    analyze_costs(prefix)
