#!/usr/bin/env python3
"""
Générateur de test de charge multi-utilisateurs (20 nominaux / 100 de pointe).
Démontre la résilience, la latence et la stabilité de l'infrastructure 3-tiers sous charge.
"""

import sys
import time
import argparse
import random
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed

ENDPOINTS = [
    "/",
    "/health",
    "/api/books",
    "/api/stats",
    "/api/info"
]

def make_request(base_url):
    path = random.choice(ENDPOINTS)
    url = f"{base_url.rstrip('/')}{path}"
    start = time.time()
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "LoadTest-Runner/1.0"})
        with urllib.request.urlopen(req, timeout=8) as resp:
            elapsed = (time.time() - start) * 1000
            return resp.status, elapsed, None
    except urllib.error.HTTPError as e:
        elapsed = (time.time() - start) * 1000
        return e.code, elapsed, str(e)
    except Exception as e:
        elapsed = (time.time() - start) * 1000
        return 0, elapsed, str(e)

def run_load_test(base_url, concurrent_users, duration_seconds):
    print("==========================================================")
    print("        TEST DE CHARGE APPLICATIF & INFRASTRUCTURE        ")
    print("==========================================================")
    print(f"URL Cible              : {base_url}")
    print(f"Utilisateurs Simultanés: {concurrent_users}")
    print(f"Durée du test          : {duration_seconds} secondes")
    print("==========================================================\n")

    latencies = []
    status_codes = {}
    errors = 0
    total_requests = 0

    end_time = time.time() + duration_seconds
    start_time = time.time()

    with ThreadPoolExecutor(max_workers=concurrent_users) as executor:
        while time.time() < end_time:
            futures = [executor.submit(make_request, base_url) for _ in range(concurrent_users)]
            for f in as_completed(futures):
                status, lat, err = f.result()
                total_requests += 1
                latencies.append(lat)
                status_codes[status] = status_codes.get(status, 0) + 1
                if status != 200:
                    errors += 1
            time.sleep(0.1)

    total_time = time.time() - start_time
    rps = total_requests / total_time if total_time > 0 else 0
    latencies.sort()
    avg_lat = sum(latencies) / len(latencies) if latencies else 0
    p95_lat = latencies[int(len(latencies) * 0.95)] if latencies else 0
    min_lat = latencies[0] if latencies else 0
    max_lat = latencies[-1] if latencies else 0

    print("---------------- RÉSULTATS DU TEST ----------------")
    print(f"Requêtes Totales traitées : {total_requests}")
    print(f"Débit moyen (RPS)         : {rps:.2f} req/s")
    print(f"Taux de succès            : {((total_requests - errors) / total_requests * 100):.2f}%")
    print(f"Répartition codes HTTP    : {status_codes}")
    print("\n--- Latences (ms) ---")
    print(f"Min    : {min_lat:.1f} ms")
    print(f"Moyenne: {avg_lat:.1f} ms")
    print(f"P95    : {p95_lat:.1f} ms")
    print(f"Max    : {max_lat:.1f} ms")
    print("==========================================================")

    if errors == 0 and avg_lat < 500:
        print("✅ RÉSULTAT CONFORME : L'infrastructure absorbe la charge sans aucune dégradation.")
    else:
        print("⚠️ Remarque : Des latences ou erreurs ont été détectées, vérifier CloudWatch.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test de charge ALB 3-tiers")
    parser.add_argument("--url", default="http://localhost:8080", help="URL de base de l'ALB ou application")
    parser.add_argument("--users", type=int, default=20, help="Nombre d'utilisateurs simultanés (20 nominal, 100 pointe)")
    parser.add_argument("--duration", type=int, default=15, help="Durée en secondes")
    args = parser.parse_args()

    run_load_test(args.url, args.users, args.duration)
