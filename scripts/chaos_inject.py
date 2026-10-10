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
        print("[FAIL] Aucune instance applicative en cours d'execution trouvee.")
        return

    target = instances[0]
    print(f"-> Terminaison forcee de l'instance {target}...")
    ec2.terminate_instances(InstanceIds=[target])
    print(f"[OK] Panne injectee : Instance {target} en cours de destruction.")
    print("Symptome attendu : L'ALB bascule le trafic sur la 2eme instance sans coupure, l'ASG recree une instance de remplacement.")

def inject_alter_health_path():
    _, elbv2, _, _ = get_clients()
    print("[PANNE 2] Alteration du chemin de controle de sante de l'ALB...")
    tgs = elbv2.describe_target_groups()
    matching = [tg for tg in tgs.get("TargetGroups", []) if "biblio-dev" in tg["TargetGroupName"]]
    if not matching:
        print("[FAIL] Target Group introuvable.")
        return

    tg_arn = matching[0]["TargetGroupArn"]
    elbv2.modify_target_group(
        TargetGroupArn=tg_arn,
        HealthCheckPath="/erreur-panne-provoquee-404"
    )
    print(f"[OK] Panne injectee : HealthCheckPath modifie vers /erreur-panne-provoquee-404 sur {matching[0]['TargetGroupName']}.")
    print("Symptome attendu : Toutes les cibles deviennent 'Unhealthy', l'alarme CloudWatch 'biblio-dev-alarm-unhealthy-hosts' se declenche, l'ALB renvoie 502/503.")

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
        print("[FAIL] Aucune cible active dans le Target Group.")
        return

    target_id = targets[0]["Target"]["Id"]
    print(f"-> Desenregistrement de la cible {target_id}...")
    elbv2.deregister_targets(
        TargetGroupArn=tg_arn,
        Targets=[{"Id": target_id, "Port": 8080}]
    )
    print(f"[OK] Panne injectee : Cible {target_id} retiree.")
    print("Symptome attendu : Le trafic n'est plus envoye a cette instance. Si ASG health check est ELB, l'instance sera recyclee.")

def inject_cut_db_sg():
    ec2, _, _, _ = get_clients()
    print("[PANNE 4] Coupure d'acces reseau a la base RDS PostgreSQL...")
    sgs = ec2.describe_security_groups(
        Filters=[{"Name": "group-name", "Values": ["biblio-dev-rds-sg"]}]
    )
    if not sgs.get("SecurityGroups"):
        print("[FAIL] Security Group RDS introuvable.")
        return

    sg_id = sgs["SecurityGroups"][0]["GroupId"]
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
        print("[OK] Panne injectee : Regle d'acces PostgreSQL (5432) revoquee sur biblio-dev-rds-sg.")
        print("Symptome attendu : L'application ne peut plus joindre la DB, la route /health renvoie 503 DOWN, statut 'UNREACHABLE'.")
    except Exception as e:
        print(f"Erreur injection : {e}")

def main():
    parser = argparse.ArgumentParser(description="Injecteur de pannes (Semaine 13)")
    parser.add_argument("scenario", choices=["terminate", "health_path", "deregister", "cut_db"],
                        help="Scenario de panne a injecter")
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
