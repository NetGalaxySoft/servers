#!/bin/bash

# ==========================================================================
#  vps-vpn-qsetup - Инсталация и конфигурация на WireGuard VPN за VPS
# --------------------------------------------------------------------------
#  Версия: 1.0
#  Дата: 2025-07-24
#  Автор: Ilko Yordanov / NetGalaxy
# ==========================================================================
#
#  Този скрипт автоматизира настройката на WireGuard VPN на VPS сървър.
#  Изпълнява се локално на сървъра (root потребител).
#
#  Основни функции:
#    1. Предварителни проверки
#    2. Инсталиране на WireGuard
#    3. Конфигуриране на VPN интерфейс (wg0)
#    4. Създаване на клиентски конфигурации
#    5. Добавяне на клиенти в сървърната конфигурация
#    6. Рестартиране и проверка на услугата
#    7. Обобщение на настройките
# ==========================================================================

# === ПОМОЩНА ИНФОРМАЦИЯ ===================================================
show_help() {
  echo "Използване: vps-vpn-qsetup.sh [опция]"
  echo ""
  echo "Автоматизирана конфигурация на WireGuard VPN за VPS."
  echo ""
  echo "Опции:"
  echo "  --version       Показва версията на скрипта"
  echo "  --help          Показва тази помощ"
}

# === ОБРАБОТКА НА ОПЦИИ ===================================================
if [[ $# -gt 0 ]]; then
  case "$1" in
    --version)
      echo "vps-vpn-qsetup версия 1.0 (24 юли 2025 г.)"
      exit 0
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      echo "❌ Неразпозната опция: $1"
      show_help
      exit 1
      ;;
  esac
fi

# === ИНИЦИАЛИЗАЦИЯ НА ПЪТИЩА =============================================
echo ""
echo -e "\e[32m============================================"
echo -e "  НАСТРОЙКА НА WIREGUARD VPN НА VPS СЪРВЪР"
echo -e "============================================\e[0m"
echo ""

NETGALAXY_DIR="/etc/netgalaxy"
MODULES_FILE="$NETGALAXY_DIR/todo.modules"
SETUP_ENV_FILE="$NETGALAXY_DIR/setup.env"

# =====================================================================
# [МОДУЛ 1] ПРЕДВАРИТЕЛНИ ПРОВЕРКИ И ИНИЦИАЛИЗАЦИЯ
# =====================================================================
echo "[1] ПРЕДВАРИТЕЛНИ ПРОВЕРКИ НА СИСТЕМА..."
echo "-----------------------------------------------------------"
echo ""

# ✅ Проверка за root права
if [[ $EUID -ne 0 ]]; then
  echo "❌ Трябва да стартирате скрипта с root права (sudo)."
  exit 1
fi

# ✅ Проверка за базова конфигурация
if [[ ! -f "$SETUP_ENV_FILE" ]] || ! sudo grep -q '^SETUP_VPS_BASE_STATUS=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "🛑 Сървърът е с нестандартна начална конфигурация. Моля, стартирайте файла vps-base-qsetup.sh и опитайте отново."
  echo "🗑️ Премахване на скрипта."
  [[ -f "$0" ]] && rm -- "$0"
  exit 1
fi

# ✅ Проверка дали скриптът вече е изпълнен успешно
if [[ -f "$SETUP_ENV_FILE" ]] && sudo grep -q '^SETUP_VPS_VPN_STATUS=✅' "$SETUP_ENV_FILE"; then
  echo "🛑 Този скрипт вече е бил изпълнен успешно на този сървър."
  echo "Повторно изпълнение не е позволено, за да се избегне повреда на системата."
  [[ -f "$0" ]] && sudo rm -- "$0"
  exit 0
fi

# ✅ Проверка на операционната система
echo "🔍 Проверка на операционната система..."
if [[ -f /etc/os-release ]]; then
  source /etc/os-release
  OS_NAME=$ID
  OS_VERSION=$VERSION_ID
else
  echo "❌ Неуспешно откриване на ОС. Скриптът изисква Ubuntu или Debian."
  exit 1
fi

SUPPORTED=false
if [[ "$OS_NAME" == "ubuntu" && ( "$OS_VERSION" == "22.04" || "$OS_VERSION" == "24.04" ) ]]; then
  SUPPORTED=true
elif [[ "$OS_NAME" == "debian" && ( "$OS_VERSION" == "11" || "$OS_VERSION" == "12" ) ]]; then
  SUPPORTED=true
fi

if [[ "$SUPPORTED" == false ]]; then
  echo "❌ Операционната система $PRETTY_NAME не се поддържа от този скрипт."
  echo "Поддържани системи: Ubuntu 22.04/24.04, Debian 11/12"
  exit 1
fi

echo "✅ Засечена поддържана ОС: $PRETTY_NAME"
echo ""

# ✅ Проверка дали модулът вече е изпълнен
if sudo grep -q '^VPN_RESULT_MODULE1=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 1 вече е изпълнен успешно. Пропускане..."
else
  # ✅ Потвърждение на IP адрес
  while true; do
    printf "🌐 Въведете публичния IP адрес на сървъра (или 'q' за изход): "
    read SERVER_IP

    if [[ "$SERVER_IP" == "q" || "$SERVER_IP" == "Q" ]]; then
      echo "❎ Скриптът беше прекратен от потребителя."
      exit 0
    fi

    if ! [[ "$SERVER_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "❌ Невалиден IP адрес. Моля, въведете валиден IPv4 адрес (пример: 192.168.1.100)."
      continue
    fi

    ACTUAL_IP=$(curl -s -4 ifconfig.me)

    if [[ "$ACTUAL_IP" != "$SERVER_IP" ]]; then
      echo ""
      echo "🚫 Несъответствие! Въведеният IP ($SERVER_IP) не съвпада с реалния IP на машината ($ACTUAL_IP)."
      echo ""
      read -p "🔁 Искате ли да опитате отново? [Enter за ДА, 'q' за изход]: " retry
      if [[ "$retry" == "q" || "$retry" == "Q" ]]; then
        echo "⛔ Скриптът беше прекратен от потребителя."
        exit 0
      fi
      echo ""
    else
      echo "✅ Потвърдено: скриптът е стартиран на сървъра с IP $SERVER_IP."
      break
    fi
  done

  # ✅ Запис или обновяване на SERVER_IP в todo.modules
  if sudo grep -q '^SERVER_IP=' "$MODULES_FILE" 2>/dev/null; then
    sudo sed -i "s|^SERVER_IP=.*|SERVER_IP=\"$SERVER_IP\"|" "$MODULES_FILE"
  else
    echo "SERVER_IP=\"$SERVER_IP\"" | sudo tee -a "$MODULES_FILE" > /dev/null
  fi

  # ✅ Запис на резултат за Модул 1
  if sudo grep -q '^VPN_RESULT_MODULE1=' "$SETUP_ENV_FILE" 2>/dev/null; then
    sudo sed -i 's|^VPN_RESULT_MODULE1=.*|VPN_RESULT_MODULE1=✅|' "$SETUP_ENV_FILE"
  else
    echo "VPN_RESULT_MODULE1=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
  fi
fi
echo ""
echo ""


# =====================================================================
# [МОДУЛ 2] ИНСТАЛИРАНЕ НА WIREGUARD
# =====================================================================
echo "[2] ИНСТАЛИРАНЕ НА WIREGUARD..."
echo "-----------------------------------------------------------"
echo ""

SETUP_ENV_FILE="/etc/netgalaxy/setup.env"

# ✅ Проверка дали модулът вече е изпълнен
if sudo grep -q '^VPN_RESULT_MODULE2=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 2 вече е изпълнен успешно. Пропускане..."
else
  echo "▶ Започва изпълнение на Модул 2..."
  echo ""

  # ✅ Обновяване на пакетите
  echo "🔍 Обновяване на списъка с пакети..."
  if ! sudo apt-get update -y; then
    echo "❌ Грешка при обновяване на списъка с пакети."
    exit 1
  fi
  echo "✅ Списъкът с пакети е обновен."
  echo ""

  # ✅ Инсталиране на WireGuard
  echo "🔍 Инсталиране на WireGuard и нужните инструменти..."
  if ! sudo apt-get install -y wireguard wireguard-tools; then
    echo "❌ Грешка при инсталиране на WireGuard."
    exit 1
  fi
  echo "✅ WireGuard е инсталиран успешно."
  echo ""

  # ✅ Проверка за наличие на командата wg
  if ! command -v wg >/dev/null 2>&1; then
    echo "❌ WireGuard не е инсталиран коректно (липсва команда wg)."
    exit 1
  fi
  echo "✅ WireGuard е наличен."
  echo ""

  # ✅ Запис на резултат за Модул 2
  if sudo grep -q '^VPN_RESULT_MODULE2=' "$SETUP_ENV_FILE" 2>/dev/null; then
    sudo sed -i 's|^VPN_RESULT_MODULE2=.*|VPN_RESULT_MODULE2=✅|' "$SETUP_ENV_FILE"
  else
    echo "VPN_RESULT_MODULE2=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
  fi

  echo "✅ Модул 2 завърши успешно."
fi
echo ""
echo ""


# =====================================================================
# [МОДУЛ 3] КОНФИГУРАЦИЯ НА ОСНОВНИЯ VPN ИНТЕРФЕЙС (WG0)
# =====================================================================
echo "[3] КОНФИГУРАЦИЯ НА ОСНОВНИЯ VPN ИНТЕРФЕЙС..."
echo "-----------------------------------------------------------"
echo ""

SETUP_ENV_FILE="/etc/netgalaxy/setup.env"
MODULES_FILE="/etc/netgalaxy/todo.modules"
WG_CONF="/etc/wireguard/wg0.conf"

# --- Проверка дали модулът вече е изпълнен ---
if grep -q '^VPN_RESULT_MODULE3=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 3 вече е изпълнен успешно. Пропускане..."
  echo ""
else
  echo "▶ Започва изпълнение на Модул 3..."
  echo ""

  # ===========================================================
  # СЕКЦИЯ 1: ДИАЛОГ С ОПЕРАТОРА (СЪБИРАНЕ НА ДАННИ)
  # ===========================================================
  # Извличане на IP на сървъра от todo.modules
  SERVER_IP=$(grep '^SERVER_IP=' "$MODULES_FILE" | awk -F'=' '{print $2}' | tr -d '"')
  echo "ℹ️ Засечен IP на сървъра: $SERVER_IP"
  echo ""

  # Въвеждане на VPN подмрежа
  while true; do
    read -p "🌐 Въведете VPN подмрежа (по подразбиране 10.20.0.0/24): " VPN_SUBNET
    VPN_SUBNET=${VPN_SUBNET:-10.20.0.0/24}
    if [[ "$VPN_SUBNET" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
      break
    else
      echo "❌ Невалиден формат. Използвайте CIDR, напр. 10.20.0.0/24."
    fi
  done

  # Въвеждане на VPN адрес на сървъра
  while true; do
    read -p "🔑 Въведете VPN IP на сървъра (по подразбиране 10.20.0.1): " VPN_SERVER_IP
    VPN_SERVER_IP=${VPN_SERVER_IP:-10.20.0.1}
    if [[ "$VPN_SERVER_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+.[0-9]+$ ]]; then
      break
    else
      echo "❌ Невалиден IP адрес. Пример: 10.20.0.1"
    fi
  done

  # Въвеждане на порт
  while true; do
    read -p "📡 Въведете порт за WireGuard (по подразбиране 51820): " WG_PORT
    WG_PORT=${WG_PORT:-51820}
    if [[ "$WG_PORT" =~ ^[0-9]+$ && "$WG_PORT" -ge 1024 && "$WG_PORT" -le 65535 ]]; then
      break
    else
      echo "❌ Невалиден порт. Допустим диапазон: 1024-65535."
    fi
  done

  # Потвърждение
  echo ""
  echo "Проверете въведените данни:"
  echo "---------------------------------"
  echo "Публичен IP на сървъра: $SERVER_IP"
  echo "VPN подмрежа:          $VPN_SUBNET"
  echo "VPN IP на сървъра:     $VPN_SERVER_IP"
  echo "WireGuard порт:        $WG_PORT"
  echo "---------------------------------"
  read -p "✅ Потвърждавате ли? (y/n): " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "❎ Скриптът е прекратен от потребителя."
    exit 0
  fi

  # Запис на данните в todo.modules
  for VAR in VPN_SUBNET VPN_SERVER_IP WG_PORT; do
    VALUE=$(eval echo "\$$VAR")
    if grep -q "^$VAR=" "$MODULES_FILE" 2>/dev/null; then
      sed -i "s|^$VAR=.*|$VAR=\"$VALUE\"|" "$MODULES_FILE"
    else
      echo "$VAR=\"$VALUE\"" >> "$MODULES_FILE"
    fi
  done

  # ===========================================================
  # СЕКЦИЯ 2: ИЗПЪЛНЕНИЕ
  # ===========================================================
  echo ""
  echo "🔍 Инсталация и конфигурация на WireGuard..."
  
  # Инсталация
  if ! command -v wg &>/dev/null; then
    apt update && apt install -y wireguard wireguard-tools
  fi

  # Генериране на ключове
  SERVER_PRIVATE_KEY=$(wg genkey)
  SERVER_PUBLIC_KEY=$(echo "$SERVER_PRIVATE_KEY" | wg pubkey)

  # Създаване на конфигурация
  cat <<EOF > "$WG_CONF"
[Interface]
Address = $VPN_SERVER_IP/24
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIVATE_KEY

PostUp = sysctl -w net.ipv4.ip_forward=1
PostDown = sysctl -w net.ipv4.ip_forward=0
SaveConfig = true
EOF

  chmod 600 "$WG_CONF"

  # Активиране
  systemctl enable --now wg-quick@wg0

  if systemctl is-active --quiet wg-quick@wg0; then
    echo "✅ WireGuard е активен."
  else
    echo "❌ Грешка при стартиране на WireGuard."
    exit 1
  fi

  # Запис в setup.env
  if grep -q '^VPN_RESULT_MODULE3=' "$SETUP_ENV_FILE" 2>/dev/null; then
    sed -i 's|^VPN_RESULT_MODULE3=.*|VPN_RESULT_MODULE3=✅|' "$SETUP_ENV_FILE"
  else
    echo "VPN_RESULT_MODULE3=✅" >> "$SETUP_ENV_FILE"
  fi

  echo "✅ Модул 3 завърши успешно."
fi
echo ""
echo ""


exit 0
