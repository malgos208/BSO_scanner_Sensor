import time
import subprocess
import requests
import os
import datetime

# Pobieranie konfiguracji z ENV (z docker-compose)
MASTER_URL = os.getenv("MASTER_URL")
SENSOR_ID = os.getenv("SENSOR_ID")
CLIENT_NAME = os.getenv("CLIENT_NAME")
SCAN_RANGE = os.getenv("SCAN_RANGE")

CHECK_INTERVAL = 30 # co 30s sprawdzanie
SEND_INTERVAL = 10800 # co 3 godziny wysyłka

def log(message):
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}")

def run_host_discovery():
    log(f"Rozpoczynam skanowanie sieci: {SCAN_RANGE}")
    
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

    log(f"[  OK  ] Znaleziono {len(hosts)} aktywnych hostów.")
    return hosts

def send_to_master():
    active_hosts = run_host_discovery()

    payload = {
        "sensor_id": SENSOR_ID,
        "hosts": active_hosts
    }
    try:
        r = requests.post(f"{MASTER_URL}/ingest", json=payload, timeout=10)
        log(f"Wysłano dane do Mastera. Status: {r.status_code}")
    except Exception as e:
        log(f"[ FAIL ] Błąd połączenia z Masterem: {e}")

if __name__ == "__main__":
    log(f"[ OK ] Sensor Agent uruchomiony dla {CLIENT_NAME}")

    last_sent = 0

    while True:
        now = time.time()

        try:
            # sprawdzanie co 30s
            r = requests.get(f"{MASTER_URL}/check-tasks/{SENSOR_ID}", timeout=10)

            if r.json().get("run_nmap"):
                log("[ TRIGGERED ] Wymuszone skanowanie z mastera")
                send_to_master()
                last_sent = now  # reset timera

        except Exception as e:
            log(f"[ FAIL ] Błąd: {e}")

        # automatyczna wysyłka co godzinę
        if now - last_sent >= SEND_INTERVAL:
            log("Automatyczna wysyłka (co 3h)")
            send_to_master()
            last_sent = now

        time.sleep(CHECK_INTERVAL)