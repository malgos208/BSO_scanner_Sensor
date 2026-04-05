#!/bin/bash
# Użycie: curl -sSL https://raw.githubusercontent.com/malgos208/BSO_scanner_Sensor/main/setup_sensor.sh | sudo bash -s -- <IP_MASTERA> <NAZWA_KLIENTA> <ZAKRES_IP>
# może być kilka podsieci, np. "192.168.1.0/24 10.0.5.0/24 172.16.0.0/16" lub 192.168.1.1-10

# np. curl -sSL https://raw.githubusercontent.com/malgos208/BSO_scanner_Sensor/main/setup_sensor.sh | sudo bash -s -- 10.0.2.15 MAIN_SA 10.0.2.1-10

MASTER_IP=$1
CLIENT_NAME=$2
SCAN_RANGE=$3

if [ -z "$SCAN_RANGE" ]; then
    echo "❌ Błąd: Brak argumentów. Użycie: ./setup_sensor.sh <IP_MASTERA> <NAZWA_KLIENTA> <ZAKRES_IP>"
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

# 3. Rejestracja w Masterze (zgodnie z Twoim app.py)
echo "📡 Rejestracja w Masterze ($MASTER_IP)..."
RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"name\":\"$CLIENT_NAME\", \"pub_key\":\"$PUB_KEY\", \"ip_range\":\"$SCAN_RANGE\"}" \
    "http://$MASTER_IP:5000/register")

# Wyciągnięcie portu z odpowiedzi JSON
SENSOR_ID=$(echo $RESPONSE | grep -oP '(?<="sensor_id":")[^"]+')
PORT=$(echo $RESPONSE | grep -oP '(?<="port":)[0-9]+')

if [ -z "$PORT" ]; then
    echo "❌ Błąd rejestracji! Nie można znaleźć portu. Odpowiedź: $RESPONSE"
    exit 1
fi
if [ -z "$SENSOR_ID" ]; then
    echo "❌ Błąd rejestracji! Nie można znaleźć sensor_id. Odpowiedź: $RESPONSE"
    exit 1
fi

echo "✅ Zarejestrowano: sensor ID: $SENSOR_ID, port tunelu: $PORT"


# 4. Generowanie pliku .env dla docker-compose (parametryzacja)
cat <<EOF > .env
MASTER_IP=$MASTER_IP
SENSOR_ID=$SENSOR_ID
CLIENT_NAME=$CLIENT_NAME
SCAN_RANGE=$SCAN_RANGE
TUNNEL_PORT=$PORT
EOF

# 5. Uruchomienie
docker compose up -d --build
echo "🚀 Sensor działa w tle na porcie $PORT."