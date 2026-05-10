#!/bin/bash
# Użycie: curl -sSL https://raw.githubusercontent.com/malgos208/BSO_scanner_Sensor/main/setup_sensor.sh | sudo bash -s -- <IP_MASTERA> <NAZWA_KLIENTA> <UNIKALNY_TOKEN> <ZAKRES_IP>
# może być kilka podsieci, np. "192.168.1.0/24 10.0.5.0/24 172.16.0.0/16" lub 192.168.1.1-10

# np. curl -sSL https://raw.githubusercontent.com/malgos208/BSO_scanner_Sensor/main/setup_sensor.sh | sudo bash -s -- 10.0.2.15 MAIN_SA token123 10.0.2.1-10

MASTER_IP=$1
CLIENT_NAME=$2
TOKEN=$3
SCAN_RANGE=$4

if [ -z "$SCAN_RANGE" ]; then
    echo "❌ Błąd: Brak argumentów. Użycie: ./setup_sensor.sh <IP_MASTERA> <NAZWA_KLIENTA> <TOKEN> <ZAKRES_IP>"
    exit 1
fi

echo "🚀 Przygotowywanie Sensora dla: $CLIENT_NAME"

# 1. Pobranie plików z GitHub (zamiast pisać je ręcznie)
git clone https://github.com/malgos208/BSO_scanner_Sensor.git bso_sensor_tmp
mv bso_sensor_tmp/* .
rm -rf bso_sensor_tmp

# 2. Generowanie kluczy SSH dla tunelu
mkdir -p ssh_keys
if [ ! -f "./ssh_keys/id_ed25519" ]; then
    ssh-keygen -t ed25519 -N "" -f ./ssh_keys/id_ed25519 -q
    echo "✅ Wygenerowano klucze SSH."
fi
PUB_KEY=$(cat ./ssh_keys/id_ed25519.pub)


# 3. Rejestracja w Masterze
echo "📡 Rejestracja w Masterze ($MASTER_IP)..."
#Budowanie obrazu sensor_agent
docker compose build sensor_agent

SENSOR_ID=$(docker compose run --rm \
    -v $(pwd)/ssh_keys/id_ed25519.pub:/tmp/pub_key:ro \
    -e CLIENT_NAME="$CLIENT_NAME" \
    -e TOKEN="$TOKEN" \
    -e SCAN_RANGE="$SCAN_RANGE" \
    -e MASTER_IP="$MASTER_IP" \
    sensor_agent \
    python3 -c "
import json, urllib.request, sys, os

with open('/tmp/pub_key') as f:
    pub_key = f.read().strip()

payload = json.dumps({
    'name': os.environ['CLIENT_NAME'],
    'pub_key': os.environ['PUB_KEY'],
    'token': os.environ['TOKEN'],
    'ip_range': os.environ['SCAN_RANGE']
}).encode()

req = urllib.request.Request(
    f'http://{os.environ[\"MASTER_IP\"]}:5000/register',
    data=payload,
    headers={'Content-Type': 'application/json'}
)

try:
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read())
        print(data.get('sensor_id', ''))
except Exception as e:
    print(f'REGISTRATION_ERROR: {e}', file=sys.stderr)
    sys.exit(1)
"
)

if [ -z "$SENSOR_ID" ] || [[ "$SENSOR_ID" == *"REGISTRATION_ERROR"* ]]; then
    echo "❌ Błąd rejestracji."
    exit 1
fi

echo "✅ Zarejestrowano sensor: $SENSOR_ID"

# 4. Generowanie pliku .env dla docker-compose (parametryzacja)
cat <<EOF > .env
cat <<EOF > .env
MASTER_IP=$MASTER_IP
SENSOR_ID=$SENSOR_ID
CLIENT_NAME=$CLIENT_NAME
SCAN_RANGE=$SCAN_RANGE
EOF

# 5. Uruchomienie
docker compose up -d
echo "🚀 Sensor działa w tle."