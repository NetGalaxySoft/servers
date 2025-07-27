#!/bin/bash
# ==========================================================================
#  vps-vpn-client-register - Регистрация на нов WireGuard VPN клиент
# --------------------------------------------------------------------------
#  Версия: 1.0
#  Дата: 2025-07-24
#  Автор: Ilko Yordanov / NetGalaxy
# ==========================================================================
#
#  Този скрипт автоматизира процеса по добавяне на нов клиент към вече
#  конфигуриран WireGuard VPN сървър (wg0). Изпълнява се локално на
#  сървъра с root права.
#
#  Основни функции:
#    1. Проверка за завършена VPN инсталация (vps-vpn-qsetup.sh)
#    2. Проверка за активен интерфейс wg0
#    3. Въвеждане на име на клиента и мрежови параметри (VPN IP, Allowed IPs)
#    4. Генериране на ключове и клиентска конфигурация
#    5. Записване на конфигурацията в /etc/wireguard/clients/<CLIENT_NAME>
#    6. Добавяне на клиента в сървърната конфигурация (wg0.conf)
#    7. Презареждане на WireGuard без прекъсване на връзката (wg syncconf)
#    8. Генериране на QR код за мобилни устройства (ако qrencode е наличен)
#    9. Извеждане на обобщение и инструкции за клиента

# === ПОМОЩНА ИНФОРМАЦИЯ ===================================================
show_help() {
  echo "Използване: vps-vpn-client-register.sh [опция]"
  echo ""
  echo "Добавяне на нов WireGuard VPN клиент към съществуващ VPN сървър."
  echo ""
  echo "Опции:"
  echo "  --version       Показва версията на скрипта"
  echo "  --help          Показва тази помощ"
}

# === ОБРАБОТКА НА ОПЦИИ ===================================================
if [[ $# -gt 0 ]]; then
  case "$1" in
    --version)
      echo "vps-vpn-client-register версия 1.0 (24 юли 2025 г.)"
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


# =====================================================================
# Скрипт: vps-vpn-client-register.sh
# Цел: Добавяне на нов VPN клиент към WireGuard сървър
# =====================================================================

SETUP_ENV_FILE="/etc/netgalaxy/setup.env"
WG_CONF="/etc/wireguard/wg0.conf"
CLIENTS_DIR="/etc/wireguard/clients"
WG_INTERFACE="wg0"

echo "[VPN CLIENT REGISTER] Добавяне на нов клиент..."
echo "-----------------------------------------------------------"
echo ""

# =====================================================================
# [1] Проверки
# =====================================================================

SETUP_ENV_FILE="/etc/netgalaxy/setup.env"
WG_INTERFACE="wg0"
WG_CONF="/etc/wireguard/wg0.conf"
CLIENTS_DIR="/etc/wireguard/clients"

# ✅ Проверка за root
if [[ $EUID -ne 0 ]]; then
  echo "❌ Скриптът трябва да се стартира с root права (sudo)."
  exit 1
fi

# ✅ Проверка за успешна инсталация на VPN (setup.env)
if ! sudo grep -q '^SETUP_VPS_VPN_STATUS=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "❌ VPN сървърът не е конфигуриран напълно. Стартирайте vps-vpn-qsetup.sh преди този скрипт."
  exit 1
fi

# ✅ Проверка за активен WireGuard интерфейс
if ! sudo systemctl is-active --quiet "wg-quick@$WG_INTERFACE"; then
  echo "❌ WireGuard интерфейсът ($WG_INTERFACE) не е активен. Стартирайте го ръчно или проверете конфигурацията."
  exit 1
fi

# ✅ Проверка за наличието на qrencode
if ! command -v qrencode &>/dev/null; then
  echo "⚠️ qrencode не е инсталиран. QR кодове няма да могат да се генерират."
  echo "ℹ️ Инсталирайте го с: sudo apt-get install -y qrencode"
fi

# ✅ Проверка за наличие на wg0.conf
if [[ ! -f "$WG_CONF" ]]; then
  echo "❌ Липсва конфигурационният файл: $WG_CONF"
  exit 1
fi

# ✅ Създаване на директория за клиенти, ако липсва
sudo mkdir -p "$CLIENTS_DIR"
sudo chmod 700 "$CLIENTS_DIR"

echo "✅ Проверките са завършени успешно."
echo ""


# =====================================================================
# [МОДУЛ 2] ВЪВЕЖДАНЕ НА ИМЕ НА КЛИЕНТА
# =====================================================================

CLIENTS_DIR="/etc/wireguard/clients"

# ✅ Създаване на директория за клиенти, ако липсва
sudo mkdir -p "$CLIENTS_DIR"
sudo chmod 700 "$CLIENTS_DIR"

while true; do
  read -p "👤 Въведете име на клиента (пример: client1): " CLIENT_NAME

  # ✅ Проверка за празно име
  if [[ -z "$CLIENT_NAME" ]]; then
    echo "❌ Името на клиента не може да бъде празно."
    continue
  fi

  # ✅ Проверка за дължина
  if (( ${#CLIENT_NAME} < 3 || ${#CLIENT_NAME} > 32 )); then
    echo "❌ Дължината трябва да е между 3 и 32 символа."
    continue
  fi

  # ✅ Проверка за валидни символи (букви, цифри, тире и долна черта)
  if [[ ! "$CLIENT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "❌ Името съдържа неразрешени символи. Разрешени са: букви, цифри, '-', '_'."
    continue
  fi

  # ✅ Проверка дали клиентът вече съществува
  CLIENT_DIR="$CLIENTS_DIR/$CLIENT_NAME"
  if [[ -d "$CLIENT_DIR" ]]; then
    echo "⚠️ Клиент '$CLIENT_NAME' вече съществува."
    read -p "Искате ли да презапишете конфигурацията? (y/q): " choice
    case "$choice" in
      [Yy]*)
        echo "▶ Презапис на конфигурацията..."
        sudo rm -rf "$CLIENT_DIR"
        break
        ;;
      [Qq]*)
        echo "❎ Прекратяване на скрипта."
        exit 0
        ;;
      *)
        echo "❌ Невалиден избор. Въведете 'y' или 'q'."
        continue
        ;;
    esac
  else
    break
  fi
done

# ✅ Създаване на директория за новия клиент
sudo mkdir -p "$CLIENT_DIR"
sudo chmod 700 "$CLIENT_DIR"

echo "✅ Името е валидирано: $CLIENT_NAME"
echo ""

exit 0
# =====================================================================
# [3] Генериране на ключове и конфигурация
# =====================================================================

echo "🔐 Генериране на ключове..."
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)
SERVER_PUBLIC_KEY=$(grep -m 1 'PrivateKey' "$WG_CONF" | awk '{print $3}' | wg pubkey)

SERVER_IP=$(grep '^Address' "$WG_CONF" | awk '{print $3}' | cut -d'/' -f1)
WG_PORT=$(grep '^ListenPort' "$WG_CONF" | awk '{print $3}')
ENDPOINT=$(grep '^SERVER_IP=' "$SETUP_ENV_FILE" | awk -F'=' '{print $2}' | tr -d '"')

# ✅ Създаване на клиентската конфигурация
cat <<EOF > "$CLIENT_CONF"
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/32
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $ENDPOINT:$WG_PORT
AllowedIPs = $ALLOWED_IPS
EOF

chmod 600 "$CLIENT_CONF"
echo "✅ Конфигурацията на клиента е създадена: $CLIENT_CONF"
echo ""

# =====================================================================
# [4] Добавяне на клиента в wg0.conf
# =====================================================================
echo "🔗 Добавяне на клиента в сървърната конфигурация..."
cat <<EOF >> "$WG_CONF"

# Client: $CLIENT_NAME
[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = $CLIENT_IP/32
EOF

# ✅ Презареждане на WireGuard конфигурацията
wg syncconf $WG_INTERFACE <(wg-quick strip $WG_INTERFACE)
echo "✅ Клиентът е добавен успешно."
echo ""

# =====================================================================
# [5] Обобщение и QR код
# =====================================================================

echo "📋 Обобщение за клиента:"
echo "-------------------------------------"
echo "Име:          $CLIENT_NAME"
echo "VPN IP:       $CLIENT_IP"
echo "Allowed IPs:  $ALLOWED_IPS"
echo "Конфигурация: $CLIENT_CONF"
echo "-------------------------------------"
echo ""

if command -v qrencode &>/dev/null; then
  echo "📱 Генериране на QR код за мобилни устройства:"
  qrencode -t ansiutf8 < "$CLIENT_CONF"
else
  echo "ℹ️ Инструментът qrencode не е наличен. QR код няма да бъде показан."
fi

echo ""
echo "✅ Добавянето на клиента е завършено успешно."
