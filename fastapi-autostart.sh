#!/bin/bash

# ==========================================================================
#  fastapi-autostart.sh – Автоматично създаване на systemd услуга за FastAPI
# ==========================================================================

PORT=$1

if [ -z "$PORT" ]; then
  echo "❗ Моля, въведи порт като аргумент при стартиране на скрипта."
  echo "👉 Пример: ./fastapi-autostart.sh 8000"
  exit 1
fi

# 📁 Директория на скрипта (приема, че е стартиран от папката backend/)
APP_DIR=$(dirname "$(realpath "$0")")
APP_USER=$(whoami)

# 📌 Откриване на main.py
MAIN_PATH="$APP_DIR/main.py"
if [ ! -f "$MAIN_PATH" ]; then
  echo "❌ main.py не е намерен в $APP_DIR"
  exit 2
fi

# 🔍 Откриване на uvicorn
UVICORN_PATH="$APP_DIR/venv/bin/uvicorn"
if [ ! -f "$UVICORN_PATH" ]; then
  echo "❌ uvicorn не е намерен във виртуалната среда ($UVICORN_PATH)"
  exit 3
fi

# 🧾 Име на услугата
SERVICE_NAME="netgalaxyup$PORT"

echo "🛠️ Създаване на systemd услуга: $SERVICE_NAME..."

sudo tee /etc/systemd/system/$SERVICE_NAME.service >/dev/null <<EOF
[Unit]
Description=NetGalaxyUP FastAPI сървър (порт $PORT)
After=network.target

[Service]
User=$APP_USER
WorkingDirectory=$APP_DIR
ExecStart=$UVICORN_PATH main:app --host 0.0.0.0 --port $PORT
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "🚀 Активиране на услугата..."
sudo systemctl daemon-reexec
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME

echo "✅ Услугата $SERVICE_NAME е стартирана."
echo "🌍 Достъпно на: http://$(hostname -I | awk '{print $1}'):$PORT"
