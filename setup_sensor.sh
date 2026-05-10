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

# 1. Pobranie plików z repozytorium
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
    -v "$(pwd)/ssh_keys/id_ed25519.pub:/tmp/pub_key:ro" \
    -v "$(pwd)/register.py:/tmp/register.py:ro" \
    -e CLIENT_NAME="$CLIENT_NAME" \
    -e TOKEN="$TOKEN" \
    -e SCAN_RANGE="$SCAN_RANGE" \
    -e MASTER_IP="$MASTER_IP" \
    sensor_agent \
    python3 /tmp/register.py
)

if [ $? -ne 0 ] || [ -z "$SENSOR_ID" ]; then
    echo "❌ Błąd rejestracji. Sprawdź token i połączenie z Masterem."
    exit 1
fi
echo "✅ Zarejestrowano sensor: $SENSOR_ID"

# 4. Generowanie pliku .env dla docker-compose
cat <<EOF > .env
MASTER_IP=$MASTER_IP
SENSOR_ID=$SENSOR_ID
CLIENT_NAME=$CLIENT_NAME
SCAN_RANGE=$SCAN_RANGE
EOF

# 5. Uruchomienie
docker compose up -d --remove-orphans # --remove-orphans usuwa stare kontenery
echo "🚀 Sensor działa w tle."