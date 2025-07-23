#!/bin/bash
# ==========================================================================
#  vps-dns-dnssec.sh – Автоматизирано активиране на DNSSEC за Bind9
# --------------------------------------------------------------------------
#  Версия: 1.0
#  Дата: 2025-07-22
#  Автор: Ilko Yordanov / NetGalaxy
# ==========================================================================
#
#  Цел:
#    - Активиране на DNSSEC върху вече конфигуриран DNS сървър.
#    - Подписване на зоните, генериране на KSK и ZSK ключове.
#
#  Зависимости:
#    - Скриптовете vps-dns-qsetup.sh и vps-dns-secure.sh трябва да са завършени.
#    - Работещ Bind9, конфигуриран с TSIG и ACL.
#
# ==========================================================================

# === ПОМОЩНА ИНФОРМАЦИЯ ===================================================
show_help() {
  echo ""
  echo "Използване: vps-dns-dnssec.sh [опция]"
  echo ""
  echo "Автоматизирана активация и конфигурация на DNSSEC за Bind9."
  echo ""
  echo "Опции:"
  echo "  --version       Показва версията на скрипта"
  echo "  --help          Показва тази помощ"
  echo ""
  echo "Забележка: Скриптът изисква преди това да е изпълнен успешно:"
  echo "  1. vps-dns-qsetup.sh"
  echo "  2. vps-dns-secure.sh"
  echo ""
}

# === ОБРАБОТКА НА ОПЦИИ ====================================================
if [[ $# -gt 0 ]]; then
  case "$1" in
    --version)
      echo "vps-dns-dnssec.sh версия 1.0 (22 юли 2025 г.)"
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
# vps-dns-dnssec.sh – Скрипт за активация и управление на DNSSEC (Bind9)
# Част от NetGalaxySoft DevOps Tools
# =====================================================================

NETGALAXY_DIR="/etc/netgalaxy"
MODULES_FILE="$NETGALAXY_DIR/todo.modules"
SETUP_ENV_FILE="$NETGALAXY_DIR/setup.env"

echo ""
echo -e "\e[32m=========================================="
echo -e "       АКТИВИРАНЕ НА DNSSEC (BIND9)"
echo -e "==========================================\e[0m"
echo ""


# =====================================================================
# [МОДУЛ 1] ПРЕДВАРИТЕЛНИ ПРОВЕРКИ
# =====================================================================
echo "[1] ПРЕДВАРИТЕЛНИ ПРОВЕРКИ..."
echo "-----------------------------------------------------------"
echo ""

# Проверка дали базовата конфигурация е завършена
if [[ ! -f "$SETUP_ENV_FILE" ]] || ! sudo grep -q '^SETUP_VPS_DNS_STATUS=✅' "$SETUP_ENV_FILE"; then
  echo "🛑 Липсва базова DNS конфигурация."
  echo "➡ Стартирайте първо скрипта vps-dns-qsetup.sh и опитайте отново."
  exit 1
fi

# Проверка дали сигурността вече е активирана
if ! sudo grep -q '^SETUP_SECURE_DNS_STATUS=✅' "$SETUP_ENV_FILE"; then
  echo "🛑 Липсва подсигуряване на DNS (Bind9)."
  echo "➡ Стартирайте първо скрипта vps-dns-secure.sh и опитайте отново."
  exit 1
fi

# Проверка дали DNSSEC вече е конфигуриран
if sudo grep -q '^SETUP_DNSSEC_STATUS=✅' "$SETUP_ENV_FILE"; then
  echo "ℹ️ DNSSEC вече е конфигуриран. Скриптът ще се прекрати."
  exit 0
fi

# Проверка на ОС
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
  echo "❌ Операционната система $PRETTY_NAME не се поддържа."
  exit 1
fi

echo "✅ Засечена поддържана ОС: $PRETTY_NAME"
echo ""

# Проверка за нужните инструменти
echo "🔍 Проверка за налични инструменти (bind9, dnssec-keygen)..."
if ! command -v dnssec-keygen >/dev/null || ! command -v named-checkconf >/dev/null; then
  echo "❌ Липсват нужни пакети! Инсталирайте bind9-utils и опитайте отново."
  exit 1
fi
echo "✅ Всички нужни пакети са налични."
echo ""

# ✅ Запис в setup.env, че модулът е успешен
if sudo grep -q '^DNSSEC_MODULE1=' "$SETUP_ENV_FILE"; then
  sudo sed -i 's|^DNSSEC_MODULE1=.*|DNSSEC_MODULE1=✅|' "$SETUP_ENV_FILE"
else
  echo "DNSSEC_MODULE1=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
fi

echo "✅ Модул 1 завърши успешно."
echo ""
echo ""


# =====================================================================
# [МОДУЛ 2] ГЕНЕРИРАНЕ НА DNSSEC КЛЮЧОВЕ
# =====================================================================
echo "[2] ГЕНЕРИРАНЕ НА DNSSEC КЛЮЧОВЕ..."
echo "-----------------------------------------------------------"
echo ""

if sudo grep -q '^DNSSEC_MODULE2=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 2 вече е изпълнен успешно. Пропускане..."
  echo ""
else
  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 1: Създаване на директория за ключове
  # -------------------------------------------------------------------------------------
  DNSSEC_DIR="/etc/bind/keys/dnssec"
  echo "🔧 Създаване на директория за DNSSEC ключове..."
  if [[ ! -d "$DNSSEC_DIR" ]]; then
    sudo mkdir -p "$DNSSEC_DIR"
    sudo chown bind:bind "$DNSSEC_DIR"
    sudo chmod 750 "$DNSSEC_DIR"
    echo "✅ Директорията за DNSSEC ключове е създадена: $DNSSEC_DIR"
  else
    echo "ℹ️ Директорията $DNSSEC_DIR вече съществува."
  fi
  echo ""

  # -------------------------------------------------------------------------------------
# СЕКЦИЯ 2: Засичане на зоната за подписване
# -------------------------------------------------------------------------------------
echo "🔍 Проверка на конфигурираните зони..."
ZONES=$(sudo grep 'zone "' /etc/bind/named.conf.local | awk -F'"' '{print $2}')

if [[ -z "$ZONES" ]]; then
  echo "❌ Не са открити зони в named.conf.local!"
  exit 1
fi

echo "✅ Засечени зони:"
echo "$ZONES"
echo ""

# Избор на първата валидна зона (без reverse)
DOMAIN=$(echo "$ZONES" | grep -v 'in-addr.arpa' | head -n 1)

if [[ -z "$DOMAIN" ]]; then
  echo "❌ Не е намерена подходяща зона за подписване!"
  exit 1
fi

echo "✅ Избрана зона за подписване: $DOMAIN"
echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 3: Запис в todo.modules
  # -------------------------------------------------------------------------------------
  if [[ ! -f "$MODULES_FILE" ]]; then
    sudo touch "$MODULES_FILE"
  fi

  for VAR in DNSSEC_DOMAIN DNSSEC_KEYS_DIR; do
    case $VAR in
      DNSSEC_DOMAIN) VALUE="$DOMAIN" ;;
      DNSSEC_KEYS_DIR) VALUE="$DNSSEC_DIR" ;;
    esac
    if sudo grep -q "^$VAR=" "$MODULES_FILE" 2>/dev/null; then
      sudo sed -i "s|^$VAR=.*|$VAR=\"$VALUE\"|" "$MODULES_FILE"
    else
      echo "$VAR=\"$VALUE\"" | sudo tee -a "$MODULES_FILE" > /dev/null
    fi
  done

  echo "✅ Добавени данни в $MODULES_FILE:"
  echo "DNSSEC_DOMAIN=\"$DOMAIN\""
  echo "DNSSEC_KEYS_DIR=\"$DNSSEC_DIR\""
  echo ""

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 4: Генериране на DNSSEC ключове (KSK и ZSK)
# -------------------------------------------------------------------------------------
echo "🔐 Генериране на KSK и ZSK за $DOMAIN..."

# Проверка за достъпност на директорията
if ! sudo test -d "$DNSSEC_DIR"; then
  echo "❌ Директорията $DNSSEC_DIR не съществува или няма достъп!"
  exit 1
fi

# Генериране на KSK (Key Signing Key)
if sudo dnssec-keygen -a RSASHA256 -b 2048 -f KSK -n ZONE -K "$DNSSEC_DIR" "$DOMAIN"; then
  echo "✅ KSK за $DOMAIN е генериран успешно."
else
  echo "❌ Грешка при генериране на KSK за $DOMAIN!"
  exit 1
fi

# Генериране на ZSK (Zone Signing Key)
if sudo dnssec-keygen -a RSASHA256 -b 1024 -n ZONE -K "$DNSSEC_DIR" "$DOMAIN"; then
  echo "✅ ZSK за $DOMAIN е генериран успешно."
else
  echo "❌ Грешка при генериране на ZSK за $DOMAIN!"
  exit 1
fi

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 5: Запис на резултата
  # -------------------------------------------------------------------------------------
  if sudo grep -q '^DNSSEC_MODULE2=' "$SETUP_ENV_FILE" 2>/dev/null; then
    sudo sed -i 's|^DNSSEC_MODULE2=.*|DNSSEC_MODULE2=✅|' "$SETUP_ENV_FILE"
  else
    echo "DNSSEC_MODULE2=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
  fi

  echo "✅ Ключовете за $DOMAIN са генерирани успешно."
  echo "✅ Модул 2 завърши успешно."
fi
echo ""
echo ""


# =====================================================================
# [МОДУЛ 3] ACL И ОГРАНИЧЕНИЯ ПО IP
# =====================================================================
echo "[3] ACL И ОГРАНИЧЕНИЯ ПО IP..."
echo "-----------------------------------------------------------"
echo ""

# Проверка дали модулът вече е изпълнен
if sudo grep -q '^SECURE_DNS_MODULE3=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 3 вече е изпълнен успешно. Пропускане..."
  echo ""
else
  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 1: Проверка и извличане на данни
  # -------------------------------------------------------------------------------------
  echo "ℹ️ Проверка за наличието на $MODULES_FILE..."
  if [[ ! -f "$MODULES_FILE" ]]; then
    sudo touch "$MODULES_FILE"
  fi

  # Извличане на SERVER_IP
  SERVER_IP=$(hostname -I | awk '{print $1}')
  [[ -z "$SERVER_IP" ]] && { echo "❌ Неуспешно извличане на IP адрес."; exit 1; }

  # Извличане на SERVER_FQDN
  SERVER_FQDN=$(hostname -f 2>/dev/null || echo "")
  [[ -z "$SERVER_FQDN" ]] && { echo "❌ Неуспешно извличане на FQDN."; exit 1; }

  # Определяне на DOMAIN
  DOMAIN=$(echo "$SERVER_FQDN" | cut -d '.' -f2-)

  # Определяне на DNS_ROLE
  if [[ "$SERVER_FQDN" =~ ^ns1\. ]]; then
    DNS_ROLE="primary"
  else
    DNS_ROLE="secondary"
  fi

  # Опит за извличане на SECOND_DNS_IP
  SECOND_DNS_IP=$(dig +short ns2.$DOMAIN A | tail -n 1)
  if [[ -z "$SECOND_DNS_IP" ]]; then
    echo "⚠️ Неуспешно извличане на IP за ns2.$DOMAIN."
    read -p "➡️ Въведете ръчно IP за втория DNS: " SECOND_DNS_IP
    if [[ -z "$SECOND_DNS_IP" ]]; then
      echo "❌ SECOND_DNS_IP е задължително. Прекратяване."
      exit 1
    fi
  fi

  # ✅ Проверка на IP адресите
  if ! [[ "$SERVER_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ SERVER_IP ($SERVER_IP) не е валиден IPv4."
    exit 1
  fi
  if ! [[ "$SECOND_DNS_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ SECOND_DNS_IP ($SECOND_DNS_IP) не е валиден IPv4."
    exit 1
  fi

  echo "✅ Добавени данни в todo.modules:"
  echo "SERVER_IP=$SERVER_IP"
  echo "SERVER_FQDN=$SERVER_FQDN"
  echo "SECOND_DNS_IP=$SECOND_DNS_IP"
  echo "DNS_ROLE=$DNS_ROLE"
  echo ""

  # Запис в todo.modules
  for VAR in SERVER_IP SECOND_DNS_IP SERVER_FQDN DNS_ROLE; do
    VALUE=$(eval echo "\$$VAR")
    if sudo grep -q "^$VAR=" "$MODULES_FILE" 2>/dev/null; then
      sudo sed -i "s|^$VAR=.*|$VAR=\"$VALUE\"|" "$MODULES_FILE"
    else
      echo "$VAR=\"$VALUE\"" | sudo tee -a "$MODULES_FILE" > /dev/null
    fi
  done

  echo "✅ Данните са записани в $MODULES_FILE."
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 2: Обновяване на named.conf.options
  # -------------------------------------------------------------------------------------
  OPTIONS_FILE="/etc/bind/named.conf.options"
  if [[ ! -f "$OPTIONS_FILE" ]]; then
    echo "❌ Липсва $OPTIONS_FILE. Скриптът не може да продължи."
    exit 1
  fi

  echo "🔧 Добавяне на ACL 'trusted' и политики..."
  sudo sed -i '/acl "trusted"/,/};/d' "$OPTIONS_FILE"
  sudo sed -i "1i acl \"trusted\" {\n    $SERVER_IP;\n    $SECOND_DNS_IP;\n};\n" "$OPTIONS_FILE"

  sudo sed -i '/allow-transfer/d' "$OPTIONS_FILE"
  sudo sed -i '/options {/,/};/ {
    /^};/i\    allow-transfer { trusted; };
  }' "$OPTIONS_FILE"

  if [[ "$DNS_ROLE" == "primary" ]]; then
    sudo sed -i '/also-notify/d' "$OPTIONS_FILE"
    sudo sed -i '/options {/,/};/ {
      /^};/i\    also-notify { '"$SECOND_DNS_IP"'; };
    }' "$OPTIONS_FILE"
  fi

  echo "✅ ACL конфигурацията е добавена."
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 3: Проверка и рестарт
  # -------------------------------------------------------------------------------------
  echo "🔍 Проверка на синтаксиса..."
  if ! sudo named-checkconf; then
    echo "❌ Грешка в конфигурацията след промени."
    exit 1
  fi
  echo "✅ Синтаксисът е валиден."

  echo "🔄 Рестартиране на Bind9..."
  sudo systemctl restart bind9
  if ! systemctl is-active --quiet bind9; then
    echo "❌ Bind9 не стартира след промени."
    exit 1
  fi
  echo "✅ Bind9 е рестартиран успешно."
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 4: Запис на резултат
  # -------------------------------------------------------------------------------------
  if sudo grep -q '^SECURE_DNS_MODULE3=' "$SETUP_ENV_FILE" 2>/dev/null; then
    sudo sed -i 's|^SECURE_DNS_MODULE3=.*|SECURE_DNS_MODULE3=✅|' "$SETUP_ENV_FILE"
  else
    echo "SECURE_DNS_MODULE3=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
  fi

  echo "✅ Модул 3 завърши успешно."
fi
echo ""
echo ""


# =====================================================================
# [МОДУЛ 4] АКТИВИРАНЕ НА DNSSEC В ЗОНИТЕ
# =====================================================================
echo "[4] АКТИВИРАНЕ НА DNSSEC В ЗОНИТЕ..."
echo "-----------------------------------------------------------"
echo ""

if sudo grep -q '^SECURE_DNS_MODULE4=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 4 вече е изпълнен успешно. Пропускане..."
  echo ""
else

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 1: Проверка и настройка на UFW (порт 953 за rndc)
# -------------------------------------------------------------------------------------
echo "🔍 Проверка за UFW правила за порт 953 (rndc)..."
if command -v ufw >/dev/null && sudo ufw status | grep -q "Status: active"; then
  if ! sudo ufw status | grep -q "953/tcp"; then
    echo "🔧 Отваряне на порт 953/tcp за localhost..."
    sudo ufw allow from 127.0.0.1 to 127.0.0.1 port 953 proto tcp comment 'Allow rndc local control'
    sudo ufw reload
    echo "✅ Порт 953 е позволен за localhost."
  else
    echo "ℹ️ Порт 953 вече е разрешен."
  fi
else
  echo "ℹ️ UFW не е активен. Пропускане..."
fi
echo ""

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 2: Проверка и конфигурация на rndc
# -------------------------------------------------------------------------------------
echo "🔍 Проверка на rndc конфигурацията..."
RNDC_KEY_FILE="/etc/bind/rndc.key"
NAMED_CONF="/etc/bind/named.conf"

# Създаване на ключ, ако липсва
if [[ ! -f "$RNDC_KEY_FILE" ]]; then
  echo "🔧 Създаване на rndc ключ..."
  sudo rndc-confgen -a -c "$RNDC_KEY_FILE"
  sudo chown root:bind "$RNDC_KEY_FILE"
  sudo chmod 640 "$RNDC_KEY_FILE"
  echo "✅ rndc ключът е създаден."
else
  echo "ℹ️ rndc ключът вече съществува."
fi

# Премахване на грешен include (ако има)
sudo sed -i '/include "\/etc\/rndc.key";/d' "$NAMED_CONF"

# Добавяне на правилния include (ако липсва)
if ! sudo grep -q "include \"$RNDC_KEY_FILE\";" "$NAMED_CONF"; then
  echo "🔧 Добавяне на include за rndc.key..."
  echo "include \"$RNDC_KEY_FILE\";" | sudo tee -a "$NAMED_CONF" > /dev/null
fi

# Добавяне на controls секция (ако липсва)
if ! sudo grep -q 'controls {' "$NAMED_CONF"; then
  echo "🔧 Добавяне на controls секция за rndc..."
  cat <<EOF | sudo tee -a "$NAMED_CONF" > /dev/null

controls {
    inet 127.0.0.1 port 953 allow { localhost; } keys { "rndc-key"; };
};
EOF
fi

echo "🔍 Проверка на синтаксиса..."
if ! sudo named-checkconf; then
  echo "❌ Конфигурацията е невалидна! Прекратяване."
  exit 1
fi

echo "🔄 Рестартиране на Bind9..."
sudo systemctl restart bind9
if ! systemctl is-active --quiet bind9; then
  echo "❌ Bind9 не е активна след рестарт!"
  exit 1
fi
echo "✅ Bind9 работи успешно."
echo ""

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 3: Зареждане на данни за DNSSEC
# -------------------------------------------------------------------------------------
if [[ ! -f "$MODULES_FILE" ]]; then
  echo "❌ Липсва $MODULES_FILE. Не може да се продължи."
  exit 1
fi

DNSSEC_DOMAIN=$(grep '^DNSSEC_DOMAIN=' "$MODULES_FILE" | awk -F'=' '{print $2}' | tr -d '"')
DNSSEC_KEYS_DIR=$(grep '^DNSSEC_KEYS_DIR=' "$MODULES_FILE" | awk -F'=' '{print $2}' | tr -d '"')

if [[ -z "$DNSSEC_DOMAIN" || -z "$DNSSEC_KEYS_DIR" ]]; then
  echo "❌ Липсват DNSSEC_DOMAIN или DNSSEC_KEYS_DIR в $MODULES_FILE."
  exit 1
fi

if ! sudo test -d "$DNSSEC_KEYS_DIR"; then
  echo "❌ Директорията за ключове ($DNSSEC_KEYS_DIR) липсва."
  exit 1
fi

echo "✅ Заредени данни:"
echo "DNSSEC_DOMAIN=$DNSSEC_DOMAIN"
echo "DNSSEC_KEYS_DIR=$DNSSEC_KEYS_DIR"
echo ""

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 4: Активиране на DNSSEC за зоната
# -------------------------------------------------------------------------------------
CONF_LOCAL="/etc/bind/named.conf.local"
if [[ ! -f "$CONF_LOCAL" ]]; then
  echo "❌ Липсва конфигурационният файл $CONF_LOCAL."
  exit 1
fi

echo "🔧 Активиране на DNSSEC за зоната $DNSSEC_DOMAIN..."
if ! sudo grep -q "zone \"$DNSSEC_DOMAIN\"" "$CONF_LOCAL"; then
  echo "❌ Зоната $DNSSEC_DOMAIN не е намерена в $CONF_LOCAL."
  exit 1
fi

sudo sed -i "/zone \"$DNSSEC_DOMAIN\" {/,/};/ {
  /inline-signing/d
  /auto-dnssec/d
  /^};/i\    inline-signing yes;\n    auto-dnssec maintain;
}" "$CONF_LOCAL"

echo "✅ DNSSEC опциите са добавени."
echo ""

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 5: Подписване на зоната
# -------------------------------------------------------------------------------------
echo "🔍 Проверка дали зоната вече е подписана..."
if sudo rndc signing -list "$DNSSEC_DOMAIN" | grep -q "key"; then
  echo "ℹ️ Зоната вече е подписана."
else
  echo "🔐 Подготовка за подписване..."

  # Проверка за ключове
  if ! sudo ls "$DNSSEC_KEYS_DIR"/*.key >/dev/null 2>&1; then
    echo "❌ Липсват DNSSEC ключове в $DNSSEC_KEYS_DIR!"
    echo "➡ Изпълнете Модул 2 за генериране на ключове и стартирайте отново."
    exit 1
  fi

  # Осигуряване на достъп до ключовете
  sudo chown -R bind:bind "$DNSSEC_KEYS_DIR"
  sudo chmod -R 640 "$DNSSEC_KEYS_DIR"/*.private
  sudo chmod -R 644 "$DNSSEC_KEYS_DIR"/*.key

  # Проверка на controls
  if ! sudo rndc status >/dev/null 2>&1; then
    echo "❌ rndc не работи! Проверете конфигурацията."
    exit 1
  fi

  echo "🔐 Зареждане на ключовете с rndc loadkeys..."
  if ! sudo rndc loadkeys "$DNSSEC_DOMAIN"; then
    echo "❌ rndc loadkeys се провали."
    exit 1
  fi

  echo "🔐 Стартиране на подписване..."
  if ! sudo rndc signing -nsec3param 1 0 10 "$DNSSEC_DOMAIN"; then
    echo "❌ rndc signing се провали."
    exit 1
  fi

  echo "✅ Подписването е стартирано."
fi
echo ""

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 6: Финална проверка и запис
# -------------------------------------------------------------------------------------
echo "🔍 Финална проверка на синтаксиса..."
if ! sudo named-checkconf; then
  echo "❌ Невалидна конфигурация след промени."
  exit 1
fi

sudo systemctl restart bind9
if ! systemctl is-active --quiet bind9; then
  echo "❌ Bind9 не се стартира след промените."
  exit 1
fi

if sudo grep -q '^SECURE_DNS_MODULE4=' "$SETUP_ENV_FILE" 2>/dev/null; then
  sudo sed -i 's|^SECURE_DNS_MODULE4=.*|SECURE_DNS_MODULE4=✅|' "$SETUP_ENV_FILE"
else
  echo "SECURE_DNS_MODULE4=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
fi

echo "✅ Модул 4 завърши успешно."
echo ""
fi
echo ""
echo ""



















exit 0
# =====================================================================
# [МОДУЛ 5] ВАЛИДАЦИЯ НА ПОДПИСВАНЕТО
# =====================================================================
echo "[5] ВАЛИДАЦИЯ НА ПОДПИСВАНЕТО..."
echo "-----------------------------------------------------------"
echo ""

SIGNED_FILE="/var/cache/bind/$DNSSEC_DOMAIN.db.signed"

echo "🔍 Проверка за signed файл..."
if [[ -f "$SIGNED_FILE" ]]; then
  echo "✅ Signed файлът съществува: $SIGNED_FILE"
else
  echo "❌ Липсва signed файл за $DNSSEC_DOMAIN!"
  exit 1
fi

echo "🔍 Проверка на синтаксиса на подписаната зона..."
if ! sudo named-checkzone "$DNSSEC_DOMAIN" "$SIGNED_FILE"; then
  echo "❌ Грешка при проверка на подписаната зона."
  exit 1
fi
echo "✅ Подписаната зона е валидна."
echo ""


# =====================================================================
# [МОДУЛ 6] ТЕСТ С DIG
# =====================================================================
echo "[6] ТЕСТ НА DNSSEC С DIG..."
echo "-----------------------------------------------------------"
echo ""
if dig +dnssec "$DNSSEC_DOMAIN" @127.0.0.1 | grep -q "RRSIG"; then
  echo "✅ DNSSEC записите са налични в отговора."
else
  echo "❌ DNSSEC записите липсват! Проверете конфигурацията."
  exit 1
fi
echo ""


# =====================================================================
# [МОДУЛ 7] ФИНАЛЕН ОТЧЕТ
# =====================================================================
echo "[7] ФИНАЛЕН ОТЧЕТ..."
echo "-----------------------------------------------------------"
echo ""

# Запис на глобалния статус
if sudo grep -q '^SETUP_DNSSEC_STATUS=' "$SETUP_ENV_FILE" 2>/dev/null; then
  sudo sed -i 's|^SETUP_DNSSEC_STATUS=.*|SETUP_DNSSEC_STATUS=✅|' "$SETUP_ENV_FILE"
else
  echo "SETUP_DNSSEC_STATUS=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
fi

echo "✅ DNSSEC е активиран и проверен успешно!"
echo ""

# Край на шаблона
