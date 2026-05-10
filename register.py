import json, urllib.request, sys, os

with open('/tmp/pub_key') as f:
    pub_key = f.read().strip()

payload = json.dumps({
    "name": os.environ["CLIENT_NAME"],
    "pub_key": pub_key,
    "token": os.environ["TOKEN"],
    "ip_range": os.environ["SCAN_RANGE"]
}).encode()

req = urllib.request.Request(
    f'http://{os.environ["MASTER_IP"]}:5000/register',
    data=payload,
    headers={"Content-Type": "application/json"}
)

try:
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read())
        print(data.get("sensor_id", ""))
except Exception as e:
    print(f"REGISTRATION_ERROR: {e}", file=sys.stderr)
    sys.exit(1)