import time
import subprocess
import requests

MASTER_URL = "http://10.0.2.15:5000/ingest"

def run_scan():
    result = subprocess.run(
        ["nmap", "-sn", "10.0.2.7/24"],
        capture_output=True,
        text=True
    )

    hosts = []

    for line in result.stdout.splitlines():
        if "Nmap scan report for" in line:
            host = line.split("for")[-1].strip()
            host = host.replace("(", "").replace(")", "")
            hosts.append(host)

    return hosts

def send(hosts):
    print("🚀 SENSOR START")
    print("📡 HOSTS:", hosts)
    payload = {
        "sensor": "sensor_1",
        "hosts": hosts
    }

    r = requests.post(MASTER_URL, json=payload)
    print(r.json())


if __name__ == "__main__":
    while True:
        try:
            hosts = run_scan()
            send(hosts)
        except Exception as e:
            print("ERROR:", e)

        time.sleep(60)