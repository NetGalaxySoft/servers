#!/bin/bash

# ==========================================================================
#  fastapi-autostart.sh – Версия 2.0
#  Стартиране на FastAPI или Vite сървър чрез systemd услуга
# --------------------------------------------------------------------------
#  Работи от директорията NetGalaxyUP/
#  Използване:
#     ./scripts/fastapi-autostart.sh -b 8000   # стартира backend (FastAPI)
#     ./scripts/fastapi-autostart.sh -v 5173   # стартира frontend (Vite)
# ==========================================================================

# Принудително преминаване към корена на проекта
cd "$(dirname "$(realpath "$0")")/.." || exit 1

MODE="$1"
PORT="$2"

if [[ -z "$MODE" || -z "$PORT" ]]; then
  echo "❗ Употреба: $0 -b <порт>  или  $0 -v <порт>"
  exit 1
fi

# Проверка за валиден порт
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
  echo "❗ Грешка: Невалиден порт '$PORT'. Моля въведете число между 1 и 65535."
  exit 1
fi

APP_USER=$(whoami)
SERVICE_NAME="netgalaxyup${MODE:1}$PORT"

if [[ "$MODE" == "-b" ]]; then
  BACKEND_DIR="$(pwd)/backend"
  MAIN_PATH="$BACKEND_DIR/main.py"
  UVICORN_PATH="$BACKEND_DIR/venv/bin/uvicorn"

  if [ ! -f "$MAIN_PATH" ]; then
    echo "❌ main.py не е намерен в $BACKEND_DIR"
    exit 2
  fi
  if [ ! -x "$UVICORN_PATH" ]; then
    echo "❌ uvicorn не е намерен или не е изпълним в $UVICORN_PATH"
    exit 3
  fi

  echo "🛠️ Създаване на systemd услуга за FastAPI: $SERVICE_NAME..."

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

elif [[ "$MODE" == "-v" ]]; then
  FRONTEND_DIR="$(pwd)/frontend"
  VITE_PATH="$FRONTEND_DIR/node_modules/.bin/vite"

  if [ ! -x "$VITE_PATH" ]; then
    echo "❌ Vite не е намерен или не е изпълним в $VITE_PATH"
    exit 4
  fi

  echo "🛠️ Създаване на systemd услуга за Vite preview: $SERVICE_NAME..."

  sudo tee /etc/systemd/system/$SERVICE_NAME.service >/dev/null <<EOF
[Unit]
Description=NetGalaxyUP Vite сървър (порт $PORT)
After=network.target

[Service]
User=$APP_USER
WorkingDirectory=$FRONTEND_DIR
ExecStart=$VITE_PATH preview --port $PORT --host
Restart=always

[Install]
WantedBy=multi-user.target
EOF

else
  echo "❗ Невалиден режим '$MODE'. Използвайте -b или -v."
  exit 1
fi

echo "🚀 Активиране на услугата..."
sudo systemctl daemon-reexec
sudo systemctl enable $SERVICE_NAME
sudo systemctl restart $SERVICE_NAME

echo "✅ Услугата $SERVICE_NAME е стартирана."
echo "🌍 Приложението е достъпно на: http://$(hostname -I | awk '{print $1}'):$PORT"
