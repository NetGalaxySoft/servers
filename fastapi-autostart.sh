#!/bin/bash

# ==========================================================================
#  fastapi-autostart.sh – Версия 1.3
#  Автоматично създаване и стартиране на systemd услуга за FastAPI сървър
# --------------------------------------------------------------------------
#  Работи от директорията, в която се намира main.py и venv/
#  Не използва find – без риск от фалшиви пътища
#  Използване: ./fastapi-autostart.sh <порт>
# ==========================================================================

PORT=$1

if [ -z "$PORT" ]; then
  echo "❗ Моля, въведи порт като аргумент при стартиране на скрипта."
  echo "👉 Пример: ./fastapi-autostart.sh 8000"
  exit 1
fi

# 📌 Определяне на директорията на скрипта
APP_DIR="$(realpath "$(dirname "$0")")"

# 📄 Проверка за наличието на main.py
MAIN_PATH="$APP_DIR/main.py"
if [ ! -f "$MAIN_PATH" ]; then
  echo "❌ main.py не е намерен в директорията $APP_DIR"
  exit 2
fi

# 📦 Проверка за uvicorn в venv/bin
UVICORN_PATH="$APP_DIR/venv/bin/uvicorn"
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

echo "🧹 Скриптът беше изпълнен. Изтриване..."
rm -- "$0"

