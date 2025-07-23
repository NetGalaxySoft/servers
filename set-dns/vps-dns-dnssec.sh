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

# Проверка дали модулът вече е изпълнен
if sudo grep -q '^DNSSEC_MODULE2=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 2 вече е изпълнен успешно. Пропускане..."
  echo ""
else
  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 1: Създаване на директория за DNSSEC ключове
  # -------------------------------------------------------------------------------------
  DNSSEC_DIR="/etc/bind/keys/dnssec"
  if [[ ! -d "$DNSSEC_DIR" ]]; then
    echo "🔧 Създаване на директория за DNSSEC ключове..."
    if sudo mkdir -p "$DNSSEC_DIR"; then
      sudo chown bind:bind "$DNSSEC_DIR"
      sudo chmod 750 "$DNSSEC_DIR"
      echo "✅ Директорията за DNSSEC ключове е създадена: $DNSSEC_DIR"
    else
      echo "❌ Неуспешно създаване на $DNSSEC_DIR"
      exit 1
    fi
  else
    echo "ℹ️ Директорията за DNSSEC ключове вече съществува: $DNSSEC_DIR"
  fi
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 2: Проверка на конфигурираните зони
  # -------------------------------------------------------------------------------------
  echo "🔍 Проверка на конфигурираните зони..."
  ZONES=$(grep -E 'zone "[^"]+"' /etc/bind/named.conf.local | awk '{print $2}' | tr -d '"')
  if [[ -z "$ZONES" ]]; then
    echo "❌ Не са открити зони в /etc/bind/named.conf.local"
    exit 1
  fi

  echo "✅ Засечени зони:"
  echo "$ZONES"
  echo ""

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 3: Генериране на ключовете
# -------------------------------------------------------------------------------------
for ZONE in "${ZONES[@]}"; do
  echo "🔐 Генериране на KSK и ZSK за $ZONE..."

  # KSK (Key Signing Key)
  if ! sudo -u bind dnssec-keygen -K "$DNSSEC_DIR" -a RSASHA256 -b 2048 -n ZONE -f KSK "$ZONE"; then
    echo "❌ Грешка при генериране на KSK за $ZONE!"
    exit 1
  fi

  # ZSK (Zone Signing Key)
  if ! sudo -u bind dnssec-keygen -K "$DNSSEC_DIR" -a RSASHA256 -b 1024 -n ZONE "$ZONE"; then
    echo "❌ Грешка при генериране на ZSK за $ZONE!"
    exit 1
  fi

  echo "✅ Ключовете за $ZONE са генерирани успешно."
done

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 4: Запис в setup.env
  # -------------------------------------------------------------------------------------
  if sudo grep -q '^DNSSEC_MODULE2=' "$SETUP_ENV_FILE" 2>/dev/null; then
    sudo sed -i 's|^DNSSEC_MODULE2=.*|DNSSEC_MODULE2=✅|' "$SETUP_ENV_FILE"
  else
    echo "DNSSEC_MODULE2=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
  fi

  echo "✅ Модул 2 завърши успешно."
  echo ""
fi
echo ""
echo ""


# =====================================================================
# [МОДУЛ 3] ACL И ОГРАНИЧЕНИЯ ПО IP
# =====================================================================
echo "[3] ACL И ОГРАНИЧЕНИЯ ПО IP..."
echo "-----------------------------------------------------------"
echo ""

# Debug: показва дали ще се пропусне
echo "ℹ️ Проверка за статуса на Модул 3 в $SETUP_ENV_FILE..."

if sudo grep -q '^SECURE_DNS_MODULE3=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "🛑 Модул 3 вече е маркиран като изпълнен. Ако искате да го стартирате отново, използвайте опцията --force."
  [[ "$1" != "--force" ]] && exit 0
  echo "⚠️ Режим FORCE активен – продължаваме въпреки статуса."
fi

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 1: Извличане на данни
# -------------------------------------------------------------------------------------
if [[ ! -f "$MODULES_FILE" ]]; then
  echo "❌ Липсва $MODULES_FILE. Скриптът не може да продължи."
  exit 1
fi

# Основен IP на сървъра
SERVER_IP=$(hostname -I | awk '{print $1}')

# Опит за извличане от todo.modules
SERVER_FQDN=$(grep '^SERVER_FQDN=' "$MODULES_FILE" | awk -F'=' '{print $2}' | tr -d '"')
DNS_ROLE=$(grep '^DNS_ROLE=' "$MODULES_FILE" | awk -F'=' '{print $2}' | tr -d '"')

# Ако SERVER_FQDN е празен → fallback към hostname -f
if [[ -z "$SERVER_FQDN" ]]; then
  SERVER_FQDN=$(hostname -f 2>/dev/null || echo "")
fi

# Ако DNS_ROLE липсва → определяме по hostname
if [[ -z "$DNS_ROLE" ]]; then
  if [[ "$SERVER_FQDN" =~ ^ns1\. ]]; then
    DNS_ROLE="primary"
  elif [[ "$SERVER_FQDN" =~ ^ns[23]\. ]]; then
    DNS_ROLE="secondary"
  fi
fi

if [[ -z "$SERVER_FQDN" || -z "$DNS_ROLE" ]]; then
  echo "❌ Липсват SERVER_FQDN или DNS_ROLE и не могат да се определят автоматично."
  exit 1
fi

DOMAIN=$(echo "$SERVER_FQDN" | cut -d '.' -f2-)
SECOND_DNS_IP=$(dig +short ns2.$DOMAIN A | tail -n 1)

if [[ -z "$SECOND_DNS_IP" ]]; then
  echo "❌ Не може да се извлече IP за ns2.$DOMAIN."
  echo "➡ Добавете го ръчно в $MODULES_FILE:"
  echo "SECOND_DNS_IP=\"xxx.xxx.xxx.xxx\""
  exit 1
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

echo "✅ Заредени данни:"
echo "SERVER_IP=$SERVER_IP"
echo "SERVER_FQDN=$SERVER_FQDN"
echo "SECOND_DNS_IP=$SECOND_DNS_IP"
echo "DNS_ROLE=$DNS_ROLE"
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
# СЕКЦИЯ 4: Запис в todo.modules
# -------------------------------------------------------------------------------------
if [[ ! -f "$MODULES_FILE" ]]; then
  sudo touch "$MODULES_FILE"
fi

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
# СЕКЦИЯ 5: Запис на резултат
# -------------------------------------------------------------------------------------
if sudo grep -q '^SECURE_DNS_MODULE3=' "$SETUP_ENV_FILE" 2>/dev/null; then
  sudo sed -i 's|^SECURE_DNS_MODULE3=.*|SECURE_DNS_MODULE3=✅|' "$SETUP_ENV_FILE"
else
  echo "SECURE_DNS_MODULE3=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
fi

echo "✅ Модул 3 завърши успешно."
echo ""








exit 0


# =====================================================================
# [МОДУЛ 4] ВКЛЮЧВАНЕ НА КЛЮЧОВЕТЕ В ЗОНАТА
# =====================================================================
echo "[4] ВКЛЮЧВАНЕ НА КЛЮЧОВЕТЕ..."
echo "-----------------------------------------------------------"
echo ""
# TODO:
# - Вмъкване на KSK и ZSK файлове в конфигурацията на зоната.
# - Проверка за коректно форматиране.
echo ""
echo ""

# =====================================================================
# [МОДУЛ 5] ИНИЦИАЛИЗАЦИЯ НА ПОДПИСВАНЕТО
# =====================================================================
echo "[5] ПОДПИСВАНЕ НА ЗОНАТА..."
echo "-----------------------------------------------------------"
echo ""
# TODO:
# - rndc loadkeys $DOMAIN
# - rndc signing -list $DOMAIN
# - Проверка за .signed файл в /var/cache/bind
echo ""
echo ""

# =====================================================================
# [МОДУЛ 6] ВАЛИДАЦИЯ НА DNSSEC
# =====================================================================
echo "[6] ВАЛИДАЦИЯ..."
echo "-----------------------------------------------------------"
echo ""
# TODO:
# - named-checkzone $DOMAIN /var/cache/bind/$DOMAIN.db.signed
# - dig +dnssec $DOMAIN @127.0.0.1
echo ""
echo ""

# =====================================================================
# [МОДУЛ 7] ФИНАЛЕН ОТЧЕТ
# =====================================================================
echo "[7] ФИНАЛЕН ОТЧЕТ..."
echo "-----------------------------------------------------------"
echo ""
# TODO:
# - Показване на статуса на всички модули.
# - Запис SETUP_DNSSEC_STATUS=✅ в setup.env.
# - Изтриване на временно todo.modules (ако съществува).
# - (По избор) Изтриване на скрипта.
echo ""
echo ""

# Край на шаблона
