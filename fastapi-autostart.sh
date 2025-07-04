#!/bin/bash

# ==========================================================================
#  fastapi-autostart.sh – Версия 1.4
#  Автоматично създаване и стартиране на systemd услуга за FastAPI сървър
# --------------------------------------------------------------------------
#  Работи от директорията NetGalaxyUP/, в която се намира backend/
#  Не използва find – без риск от фалшиви пътища
#  Използване: ./scripts/fastapi-autostart.sh <порт>
# ==========================================================================

# Принудително преминаване към корена на проекта
cd "$(dirname "$(realpath "$0")")/.." || exit 1

PORT=$1

if [ -z "$PORT" ]; then
  echo "❗ Моля, въведи порт като аргумент при стартиране на скрипта."
  echo "👉 Пример: ./scripts/fastapi-autostart.sh 8000"
  exit 1
fi

# 📁 Определяне на пътищата
APP_DIR="$(pwd)"
BACKEND_DIR="$APP_DIR/backend"
MAIN_PATH="$BACKEND_DIR/main.py"
UVICORN_PATH="$BACKEND_DIR/venv/bin/uvicorn"

# 🧪 Проверка за main.py
if [ ! -f "$MAIN_PATH" ]; then
  echo "❌ main.py не е намерен в директорията $BACKEND_DIR"
  exit 2
fi

# 🧪 Проверка за uvicorn
if [ ! -f "$UVICORN_PATH" ]; then
  echo "❌ uvicorn не е намерен във виртуалната среда ($UVICORN_PATH)"
  exit 3
fi

APP_USER=$(whoami)
SERVICE_NAME="netgalaxyup$PORT"

echo "🛠️ Създаване на systemd услуга: $SERVICE_NAME..."

sudo tee /etc/systemd/system/$SERVICE_NAME.service >/dev/null <<EOF
[Unit]
Description=NetGalaxyUP FastAPI сървър (порт $PORT)
After=network.target

[Service]
User=$APP_USER
WorkingDirectory=$BACKEND_DIR
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
