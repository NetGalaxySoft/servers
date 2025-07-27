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
# [МОДУЛ 1] Проверки
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
echo ""


# =====================================================================
# [МОДУЛ 2] ВЪВЕЖДАНЕ НА ИМЕ НА КЛИЕНТА
# =====================================================================

CLIENTS_DIR="/etc/wireguard/clients"
WG_CONF="/etc/wireguard/wg0.conf"

# ✅ Създаване на директория за клиенти, ако липсва
sudo mkdir -p "$CLIENTS_DIR"
sudo chmod 700 "$CLIENTS_DIR"

while true; do
  read -p "👤 Въведете име на клиента (3-15 символа, букви, цифри, '-', '_'): " CLIENT_NAME

  # ✅ Проверка за празно име
  if [[ -z "$CLIENT_NAME" ]]; then
    echo "❌ Името на клиента не може да бъде празно."
    continue
  fi

  # ✅ Проверка за дължина
  if (( ${#CLIENT_NAME} < 3 || ${#CLIENT_NAME} > 15 )); then
    echo "❌ Дължината трябва да е между 3 и 15 символа."
    continue
  fi

  # ✅ Проверка за валидни символи
  if [[ ! "$CLIENT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "❌ Името съдържа неразрешени символи. Разрешени: латински букви, цифри, '-', '_'."
    continue
  fi

  # ✅ Проверка дали клиентът вече съществува
  CLIENT_DIR="$CLIENTS_DIR/$CLIENT_NAME"
  if [[ -d "$CLIENT_DIR" ]]; then
    echo "⚠️ Клиент '$CLIENT_NAME' вече съществува."
    read -p "Искате ли да презапишете конфигурацията? (y/q): " choice
    case "$choice" in
      [Yy]*)
        echo "▶ Премахване на старата конфигурация..."
        sudo rm -rf "$CLIENT_DIR"

        echo "▶ Премахване на Peer от wg0.conf..."
        sudo sed -i "/# Client: $CLIENT_NAME/,/^$/d" "$WG_CONF"

        echo "▶ Синхронизиране на WireGuard..."
        sudo wg syncconf wg0 <(sudo wg-quick strip wg0)

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

# ✅ Създаване на нова директория за клиента
sudo mkdir -p "$CLIENT_DIR"
sudo chmod 700 "$CLIENT_DIR"

echo "✅ Името е валидирано: $CLIENT_NAME"
echo ""
echo ""


# =====================================================================
# [МОДУЛ 3] ВЪВЕЖДАНЕ НА IP АДРЕС ЗА КЛИЕНТА
# =====================================================================

SETUP_ENV_FILE="/etc/netgalaxy/setup.env"
WG_CONF="/etc/wireguard/wg0.conf"

# ✅ Извличане на IP на сървъра
SERVER_IP=$(sudo grep '^SERVER_IP=' "$SETUP_ENV_FILE" | awk -F'=' '{print $2}' | tr -d '"')

# ✅ Анимация: въртящ се курсор за търсене
spinner="/-\|"
echo -n "🔍 Откриване на VPN подмрежата "
for i in {1..8}; do
  printf "\b${spinner:i%4:1}"
  sleep 0.2
done
echo ""

# ✅ Извличане на VPN подмрежата от wg0.conf (пример: 10.20.0.1/24)
VPN_SUBNET=$(sudo grep '^Address' "$WG_CONF" | awk '{print $3}' | head -n 1)
SUBNET_IP=$(echo "$VPN_SUBNET" | cut -d'/' -f1)
SUBNET_MASK=$(echo "$VPN_SUBNET" | cut -d'/' -f2)

echo "ℹ️ VPN подмрежа: $VPN_SUBNET"

# ✅ Допълнителна анимация: точки за „обработка“
for i in {1..5}; do
  echo -n "."
  sleep 0.3
done
echo ""

# ✅ Функция за проверка дали IP е в подмрежата
function ip_in_subnet() {
    local ip=$1
    local network=$2
    local maskbits=$3
    local IFS=.
    read -r i1 i2 i3 i4 <<< "$ip"
    read -r n1 n2 n3 n4 <<< "$network"
    local ip_dec=$(( (i1<<24) + (i2<<16) + (i3<<8) + i4 ))
    local net_dec=$(( (n1<<24) + (n2<<16) + (n3<<8) + n4 ))
    local mask=$(( 0xFFFFFFFF << (32 - maskbits) & 0xFFFFFFFF ))
    [[ $((ip_dec & mask)) -eq $((net_dec & mask)) ]]
}

# ✅ Функция за конвертиране IP -> число
function ip_to_dec() {
    local IFS=.
    read -r i1 i2 i3 i4 <<< "$1"
    echo $(( (i1<<24) + (i2<<16) + (i3<<8) + i4 ))
}

# ✅ Функция за конвертиране число -> IP
function dec_to_ip() {
    local ip_dec=$1
    echo "$(( (ip_dec>>24) & 255 )).$(( (ip_dec>>16) & 255 )).$(( (ip_dec>>8) & 255 )).$(( ip_dec & 255 ))"
}

# ✅ Изчисляване на диапазона
NET_DEC=$(ip_to_dec "$SUBNET_IP")
START_IP=$((NET_DEC + 2))  # Прескачаме мрежовия адрес и IP на сървъра
END_IP=$((NET_DEC + (1 << (32 - SUBNET_MASK)) - 2))

# ✅ Събиране на свободните IP адреси
FREE_IPS=()
for (( ip_dec=START_IP; ip_dec<=END_IP; ip_dec++ )); do
    candidate=$(dec_to_ip "$ip_dec")
    if [[ "$candidate" != "$SERVER_IP" ]] && ! sudo grep -q "$candidate/32" "$WG_CONF"; then
        FREE_IPS+=("$candidate")
    fi
done

if [[ ${#FREE_IPS[@]} -eq 0 ]]; then
    echo "❌ Няма свободни IP адреси в подмрежата $VPN_SUBNET."
    exit 1
fi

# ✅ Анимация преди избора на свободен IP
echo -n "🎯 Избор на свободен IP "
for i in {1..16}; do
  echo -n "."
  sleep 0.3
done
echo ""

# ✅ Избор на произволен свободен IP
FREE_IP=$(printf "%s\n" "${FREE_IPS[@]}" | shuf -n 1)

# ✅ Подсказване на IP на оператора
while true; do
  read -p "🌐 Въведете VPN IP за клиента [по подразбиране $FREE_IP]: " CLIENT_IP
  CLIENT_IP=${CLIENT_IP:-$FREE_IP}

  # Проверка за валиден IPv4
  if [[ ! "$CLIENT_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Невалиден IP адрес."
    continue
  fi

  # Проверка дали не е IP на сървъра
  if [[ "$CLIENT_IP" == "$SERVER_IP" || "$CLIENT_IP" == "$SUBNET_IP" ]]; then
    echo "❌ Този IP е резервиран (сървър или мрежов адрес)."
    continue
  fi

# Проверка дали IP е в подмрежата
if ! ip_in_subnet "$CLIENT_IP" "$SUBNET_IP" "$SUBNET_MASK"; then
  echo "❌ IP адресът не е в подмрежата $VPN_SUBNET."
  continue
fi

# Проверка дали IP вече се използва
if sudo grep -q "$CLIENT_IP/32" "$WG_CONF"; then
  echo "❌ IP адресът вече се използва."
  continue
fi

break
done

# ✅ Установяване на AllowedIPs по подразбиране
ALLOWED_IPS="0.0.0.0/0"

echo ""
echo "✅ IP адресът е валидиран: $CLIENT_IP"
echo "✅ Allowed IPs: $ALLOWED_IPS"
echo ""
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
