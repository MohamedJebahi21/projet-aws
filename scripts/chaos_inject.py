#!/usr/bin/env python3
"""
Générateur d'injections de pannes (Chaos Engineering) - Semaine 13.
Simule les pannes types de l'enseignant pour entraîner le groupe à la détection et remédiation.
"""

import sys
import argparse
import boto3

def get_clients():
    session = boto3.session.Session(region_name="us-east-1")
    return (
        session.client("ec2"),
        session.client("elbv2"),
        session.client("autoscaling"),
        session.client("s3")
    )

def inject_terminate_instance():
    ec2, _, asg, _ = get_clients()
    print("[PANNE 1] Terminaison manuelle d'une instance ASG...")
    resp = ec2.describe_instances(
        Filters=[
            {"Name": "instance-state-name", "Values": ["running"]},
            {"Name": "tag:Tier", "Values": ["Application"]}
        ]
    )
    instances = [i["InstanceId"] for r in resp.get("Reservations", []) for i in r.get("Instances", [])]
    if not instances:
        print("❌ Aucune instance applicative en cours d'exécution trouvée.")
        return

    target = instances[0]
    print(f"-> Terminaison forcée de l'instance {target}...")
    ec2.terminate_instances(InstanceIds=[target])
    print(f"✅ Panne injectée : Instance {target} en cours de destruction.")
    print("Symptôme attendu : L'ALB bascule le trafic sur la 2ème instance sans coupure, l'ASG recrée une instance de remplacement.")

def inject_alter_health_path():
    _, elbv2, _, _ = get_clients()
    print("[PANNE 2] Altération du chemin de contrôle de santé de l'ALB...")
    tgs = elbv2.describe_target_groups()
    matching = [tg for tg in tgs.get("TargetGroups", []) if "biblio-dev" in tg["TargetGroupName"]]
    if not matching:
        print("❌ Target Group introuvable.")
        return

    tg_arn = matching[0]["TargetGroupArn"]
    elbv2.modify_target_group(
        TargetGroupArn=tg_arn,
        HealthCheckPath="/erreur-panne-provoquee-404"
    )
    print(f"✅ Panne injectée : HealthCheckPath modifié vers /erreur-panne-provoquee-404 sur {matching[0]['TargetGroupName']}.")
    print("Symptôme attendu : Toutes les cibles deviennent 'Unhealthy', l'alarme CloudWatch 'biblio-dev-alarm-unhealthy-hosts' se déclenche, l'ALB renvoie 502/503.")

def inject_deregister_target():
    _, elbv2, _, _ = get_clients()
    print("[PANNE 3] Retrait manuel d'une instance du groupe cible ALB...")
    tgs = elbv2.describe_target_groups()
    matching = [tg for tg in tgs.get("TargetGroups", []) if "biblio-dev" in tg["TargetGroupName"]]
    if not matching: return
    tg_arn = matching[0]["TargetGroupArn"]

    health = elbv2.describe_target_health(TargetGroupArn=tg_arn)
    targets = health.get("TargetHealthDescriptions", [])
    if not targets:
        print("❌ Aucune cible active dans le Target Group.")
        return

    target_id = targets[0]["Target"]["Id"]
    print(f"-> Désenregistrement de la cible {target_id}...")
    elbv2.deregister_targets(
        TargetGroupArn=tg_arn,
        Targets=[{"Id": target_id, "Port": 8080}]
    )
    print(f"✅ Panne injectée : Cible {target_id} retirée.")
    print("Symptôme attendu : Le trafic n'est plus envoyé à cette instance. Si ASG health check est ELB, l'instance sera recyclée.")

def inject_cut_db_sg():
    ec2, _, _, _ = get_clients()
    print("[PANNE 4] Coupure d'accès réseau à la base RDS PostgreSQL...")
    sgs = ec2.describe_security_groups(
        Filters=[{"Name": "group-name", "Values": ["biblio-dev-rds-sg"]}]
    )
    if not sgs.get("SecurityGroups"):
        print("❌ Security Group RDS introuvable.")
        return

    sg_id = sgs["SecurityGroups"][0]["GroupId"]
    # Retirer la règle ingress 5432
    try:
        app_sgs = ec2.describe_security_groups(Filters=[{"Name": "group-name", "Values": ["biblio-dev-app-sg"]}])
        app_sg_id = app_sgs["SecurityGroups"][0]["GroupId"]
        ec2.revoke_security_group_ingress(
            GroupId=sg_id,
            IpPermissions=[{
                "IpProtocol": "tcp",
                "FromPort": 5432,
                "ToPort": 5432,
                "UserIdGroupPairs": [{"GroupId": app_sg_id}]
            }]
        )
        print("✅ Panne injectée : Règle d'accès PostgreSQL (5432) révoquée sur biblio-dev-rds-sg.")
        print("Symptôme attendu : L'application ne peut plus joindre la DB, la route /health renvoie 503 DOWN, statut 'UNREACHABLE'.")
    except Exception as e:
        print(f"Erreur injection : {e}")

def main():
    parser = argparse.ArgumentParser(description="Injecteur de pannes (Semaine 13)")
    parser.add_argument("scenario", choices=["terminate", "health_path", "deregister", "cut_db"],
                        help="Scénario de panne à injecter")
    args = parser.parse_args()

    if args.scenario == "terminate":
        inject_terminate_instance()
    elif args.scenario == "health_path":
        inject_alter_health_path()
    elif args.scenario == "deregister":
        inject_deregister_target()
    elif args.scenario == "cut_db":
        inject_cut_db_sg()

if __name__ == "__main__":
    main()
