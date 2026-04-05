FROM python:3.11-slim

# Instalacja nmapa
RUN apt-get update && apt-get install -y \
    nmap \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Kopiowanie zależności
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Kopiowanie kodu agenta
COPY sensor_agent.py .

# Start agenta
CMD ["python3", "sensor_agent.py"]