#!/bin/bash

# ==========================================================================
#  fastapi-autostart.sh – Версия 1.2
#  Автоматично създаване и стартиране на systemd услуга за FastAPI сървър
# --------------------------------------------------------------------------
#  Използване: ./fastapi-autostart.sh <порт>
#  Работи независимо от директорията, от която се стартира
# ==========================================================================

PORT=$1

if [ -z "$PORT" ]; then
  echo "❗ Моля, въведи порт като аргумент при стартиране на скрипта."
  echo "👉 Пример: ./fastapi-autostart.sh 8000"
  exit 1
fi

echo "🔍 Откриване на main.py..."
MAIN_PATH=$(find $HOME -type f -name main.py | head -n 1)
if [ -z "$MAIN_PATH" ]; then
  echo "❌ main.py не е намерен в домашната директория"
  exit 2
fi

APP_DIR=$(dirname "$MAIN_PATH")
APP_USER=$(whoami)

echo "🔍 Откриване на uvicorn..."
UVICORN_PATH="$APP_DIR/venv/bin/uvicorn"
if [ ! -f "$UVICORN_PATH" ]; then
  echo "❌ uvicorn не е намерен във виртуалната среда ($UVICORN_PATH)"
  exit 3
fi

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
echo "🌍 Приложението е достъпно на: http://$(hostname -I | awk '{print $1}'):$PORT"
