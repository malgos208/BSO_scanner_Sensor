import time
import subprocess
import requests
import os
import datetime

# Pobieranie konfiguracji z ENV (z docker-compose)
MASTER_URL = os.getenv("MASTER_URL")
CLIENT_NAME = os.getenv("CLIENT_NAME")
SCAN_RANGE = os.getenv("SCAN_RANGE")

def log(message):
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}")

def run_host_discovery():
    log(f"🔎 Rozpoczynanie skanowania sieci: {SCAN_RANGE}")
    
    # -sn: Ping scan (wykrywanie żywych hostów bez skanowania portów - szybkie!)
    # -oG -: Wyjście w formacie "grepable" dla łatwego parsowania
    result = subprocess.run(
        ["nmap", "-sn"] + SCAN_RANGE.split() + ["-oG", "-"], # podział, jeśli jest kilka zakresów podsieci
        capture_output=True,
        text=True
    )

    hosts = []
    for line in result.stdout.splitlines():
        if "Status: Up" in line:
            # Wyciągamy IP z linii typu: Host: 192.168.1.1 () Status: Up
            parts = line.split()
            if len(parts) > 1:
                hosts.append(parts[1])

    log(f"✅ Znaleziono {len(hosts)} aktywnych hostów.")
    return hosts

def send_to_master(hosts):
    payload = {
        "sensor": CLIENT_NAME,
        "hosts": hosts
    }
    try:
        r = requests.post(MASTER_URL, json=payload, timeout=10)
        log(f"📡 Wysłano dane do Mastera. Status: {r.status_code}")
    except Exception as e:
        log(f"❌ Błąd połączenia z Masterem: {e}")

if __name__ == "__main__":
    log(f"🚀 Sensor Agent uruchomiony dla {CLIENT_NAME}")
    while True:
        try:
            active_hosts = run_host_discovery()
            if active_hosts:
                send_to_master(active_hosts)
            else:
                log("Brak aktywnych hostów w sieci.")
        except Exception as e:
            log(f"Błąd krytyczny: {e}")

        # Odczekaj np. 1 godzinę przed kolejnym sprawdzeniem sieci
        time.sleep(3600)