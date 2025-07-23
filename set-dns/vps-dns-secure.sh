#!/bin/bash
# ==========================================================================
#  vps-dns-secure.sh – Подсилване на сигурността на DNS сървър (Bind9)
# --------------------------------------------------------------------------
#  Версия: 1.0
#  Дата: 2025-07-22
#  Автор: Ilko Yordanov / NetGalaxy
# ==========================================================================
#
#  Този скрипт добавя мерки за сигурност върху вече конфигуриран DNS сървър
#  (Bind9), след като е изпълнен скриптът vps-dns-qsetup.sh.
#
#  Скриптът е модулен и изпълнява следните стъпки:
#    1. Предварителни проверки (OS, IP, FQDN, предишно изпълнение)
#    2. Проверка и подсигуряване на базови политики
#    3. Настройка на ACL (Access Control Lists)
#    4. Генериране и внедряване на TSIG ключове
#    5. Проверка и рестарт на Bind9
#    6. Автоматичен тест за TSIG синхронизация
#    7. Финален отчет и потвърждение
# ==========================================================================
#
# === ПОМОЩНА ИНФОРМАЦИЯ ===================================================
show_help() {
  echo ""
  echo "Използване: vps-dns-secure.sh [опция]"
  echo ""
  echo "Автоматизирано подсилване на сигурността на DNS сървър (Bind9)."
  echo ""
  echo "Опции:"
  echo "  --version       Показва версията на скрипта"
  echo "  --help          Показва тази помощ"
  echo ""
  echo "Забележка: Скриптът изисква да е изпълнен vps-dns-qsetup.sh преди него."
  echo ""
}

# === ОБРАБОТКА НА ОПЦИИ ====================================================
if [[ $# -gt 0 ]]; then
  case "$1" in
    --version)
      echo "vps-dns-secure.sh версия 1.0 (22 юли 2025 г.)"
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
# vps-dns-secure.sh – Скрипт за подсилване на сигурността на DNS (Bind9)
# Част от NetGalaxySoft DevOps Tools
# =====================================================================

echo ""
echo -e "\e[32m=========================================="
echo -e "      DNS SECURITY HARDENING (BIND9)"
echo -e "==========================================\e[0m"
echo ""

# Основни пътища и файлове
NETGALAXY_DIR="/etc/netgalaxy"
MODULES_FILE="$NETGALAXY_DIR/todo.modules"
SETUP_ENV_FILE="$NETGALAXY_DIR/setup.env"

# =====================================================================
# [МОДУЛ 1] ПРЕДВАРИТЕЛНИ ПРОВЕРКИ
# =====================================================================
echo "[1] ПРЕДВАРИТЕЛНИ ПРОВЕРКИ..."
echo "-----------------------------------------------------------"
echo ""

SETUP_ENV_FILE="/etc/netgalaxy/setup.env"
MODULES_FILE="/etc/netgalaxy/todo.modules"

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 1: Проверка за базова DNS конфигурация
# -------------------------------------------------------------------------------------
if [[ ! -f "$SETUP_ENV_FILE" ]] || ! grep -q '^SETUP_VPS_DNS_STATUS=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "🛑 Не е открита завършена базова DNS конфигурация."
  echo "ℹ️ Стартирайте първо скрипта vps-dns-qsetup.sh и опитайте отново."
  echo "🗑️ Премахване на скрипта."
  rm -- "$0"
  exit 1
fi

# Проверка дали защитната конфигурация вече е завършена
if grep -q '^SETUP_SECURE_DNS_STATUS=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "🛑 Скриптът вече е изпълнен (DNS сигурността е активирана)."
  echo "🗑️ Премахване на скрипта."
  rm -- "$0"
  exit 0
fi

# Проверка дали Модул 1 вече е изпълнен
if grep -q '^SECURE_DNS_MODULE1=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 1 вече е изпълнен успешно. Пропускане..."
  echo ""
else
  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 2: Проверка на операционната система
  # -------------------------------------------------------------------------------------
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
    echo "Поддържани: Ubuntu 22.04/24.04, Debian 11/12"
    exit 1
  fi

  echo "✅ Засечена поддържана ОС: $PRETTY_NAME"
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 3: Проверка на IP адреса
  # -------------------------------------------------------------------------------------
  while true; do
    printf "🌐 Въведете публичния IP адрес на сървъра (или 'q' за изход): "
    read SERVER_IP

    if [[ "$SERVER_IP" == "q" || "$SERVER_IP" == "Q" ]]; then
      echo "❎ Скриптът беше прекратен от потребителя."
      exit 0
    fi

    if ! [[ "$SERVER_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "❌ Невалиден IP адрес. Моля, въведете валиден IPv4."
      continue
    fi

    ACTUAL_IP=$(curl -s -4 ifconfig.me)
    if [[ -z "$ACTUAL_IP" ]]; then
      echo "❌ Неуспешно извличане на реален IP (curl ifconfig.me)."
      exit 1
    fi

    if [[ "$ACTUAL_IP" != "$SERVER_IP" ]]; then
      echo "🚫 Несъответствие! Въведеният IP не съвпада с реалния IP."
      read -p "🔁 Искате ли да опитате отново? [Enter за ДА, 'q' за изход]: " retry
      [[ "$retry" == "q" || "$retry" == "Q" ]] && exit 0
      echo ""
    else
      echo "✅ Потвърдено: IP $SERVER_IP е валидно."
      break
    fi
  done
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 4: Проверка на hostname
  # -------------------------------------------------------------------------------------
  echo "🔍 Проверка на hostname..."
  HOSTNAME_FQDN=$(hostname -f 2>/dev/null || echo "")

  if [[ -z "$HOSTNAME_FQDN" ]]; then
    echo "❌ Неуспешно извличане на FQDN. Конфигурацията не може да продължи."
    exit 1
  fi

  echo "✅ Потвърдено: hostname = $HOSTNAME_FQDN"
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 5: Запис на данните в todo.modules
  # -------------------------------------------------------------------------------------
  touch "$MODULES_FILE"

  grep -q '^SERVER_IP=' "$MODULES_FILE" && sed -i "s|^SERVER_IP=.*|SERVER_IP=\"$SERVER_IP\"|" "$MODULES_FILE" || echo "SERVER_IP=\"$SERVER_IP\"" >> "$MODULES_FILE"
  grep -q '^SERVER_FQDN=' "$MODULES_FILE" && sed -i "s|^SERVER_FQDN=.*|SERVER_FQDN=\"$HOSTNAME_FQDN\"|" "$MODULES_FILE" || echo "SERVER_FQDN=\"$HOSTNAME_FQDN\"" >> "$MODULES_FILE"

  echo "✅ Данните са записани в $MODULES_FILE."
  echo ""

  # ✅ Запис на резултат за Модул 1
  grep -q '^SECURE_DNS_MODULE1=' "$SETUP_ENV_FILE" && sed -i 's|^SECURE_DNS_MODULE1=.*|SECURE_DNS_MODULE1=✅|' "$SETUP_ENV_FILE" || echo "SECURE_DNS_MODULE1=✅" >> "$SETUP_ENV_FILE"

  echo "✅ Модул 1 завърши успешно."
  echo ""
fi
echo ""
echo ""


# =====================================================================
# [МОДУЛ 2] ПОДСИГУРЯВАНЕ НА БАЗОВИ ПОЛИТИКИ
# =====================================================================
echo "[2] ПОДСИГУРЯВАНЕ НА БАЗОВИ ПОЛИТИКИ..."
echo "-----------------------------------------------------------"
echo ""

SETUP_ENV_FILE="/etc/netgalaxy/setup.env"
OPTIONS_FILE="/etc/bind/named.conf.options"

if [[ ! -f "$SETUP_ENV_FILE" ]]; then
  echo "❌ Липсва $SETUP_ENV_FILE. Стартирайте Модул 1 първо."
  exit 1
fi

# Проверка дали модулът вече е изпълнен
if grep -q '^SECURE_DNS_MODULE2=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 2 вече е изпълнен успешно. Пропускане..."
  echo ""
else
  echo "▶ Започва изпълнение на Модул 2..."
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 1: Проверка за съществуване на named.conf.options
  # -------------------------------------------------------------------------------------
  if [[ ! -f "$OPTIONS_FILE" ]]; then
    echo "❌ Липсва файлът $OPTIONS_FILE. Скриптът не може да продължи."
    exit 1
  fi

  echo "✅ Файлът $OPTIONS_FILE е открит."
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 2: Обновяване на политики в named.conf.options
  # -------------------------------------------------------------------------------------
  echo "🔧 Обновяване на политики за сигурност в $OPTIONS_FILE..."

  sed -i '/options {/,/};/ {
    /recursion/d
    /allow-transfer/d
    /allow-recursion/d
    /dnssec-validation/d
  }' "$OPTIONS_FILE"

  sed -i '/options {/,/};/ {
    /^};/i\    recursion no;
    /^};/i\    allow-transfer { none; };
    /^};/i\    dnssec-validation auto;
  }' "$OPTIONS_FILE"

  echo "✅ Политиките са добавени: recursion=no, allow-transfer=none, dnssec-validation=auto."
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 3: Проверка на синтаксиса
  # -------------------------------------------------------------------------------------
  echo "🔍 Проверка на синтаксиса..."
  if ! named-checkconf; then
    echo "❌ Грешка в конфигурацията на Bind9 след промени."
    exit 1
  fi
  echo "✅ Синтаксисът е валиден."
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 4: Рестартиране на услугата
  # -------------------------------------------------------------------------------------
  echo "🔄 Рестартиране на Bind9..."
  systemctl restart bind9
  if ! systemctl is-active --quiet bind9; then
    echo "❌ Услугата Bind9 не стартира след промени."
    exit 1
  fi
  echo "✅ Bind9 е рестартиран успешно."
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 5: Запис на резултат за Модул 2
  # -------------------------------------------------------------------------------------
  grep -q '^SECURE_DNS_MODULE2=' "$SETUP_ENV_FILE" && sed -i 's|^SECURE_DNS_MODULE2=.*|SECURE_DNS_MODULE2=✅|' "$SETUP_ENV_FILE" || echo "SECURE_DNS_MODULE2=✅" >> "$SETUP_ENV_FILE"

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

SETUP_ENV_FILE="/etc/netgalaxy/setup.env"
MODULES_FILE="/etc/netgalaxy/todo.modules"
OPTIONS_FILE="/etc/bind/named.conf.options"

if grep -q '^SECURE_DNS_MODULE3=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 3 вече е изпълнен успешно. Пропускане..."
  echo ""
else
  echo "▶ Започва изпълнение на Модул 3..."
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 1: Извличане на данни
  # -------------------------------------------------------------------------------------
  if [[ ! -f "$MODULES_FILE" ]]; then
    echo "❌ Липсва $MODULES_FILE. Скриптът не може да продължи."
    exit 1
  fi

  if ! command -v dig &>/dev/null; then
    echo "❌ Липсва командата dig. Инсталирайте пакет dnsutils."
    exit 1
  fi

  SERVER_IP=$(hostname -I | awk '{print $1}')
  SERVER_FQDN=$(grep '^SERVER_FQDN=' "$MODULES_FILE" | awk -F'=' '{print $2}' | tr -d '"')
  DNS_ROLE=$(grep '^DNS_ROLE=' "$MODULES_FILE" | awk -F'=' '{print $2}' | tr -d '"')

  if [[ -z "$SERVER_FQDN" ]]; then
    SERVER_FQDN=$(hostname -f 2>/dev/null || echo "")
  fi

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
  if [[ ! -f "$OPTIONS_FILE" ]]; then
    echo "❌ Липсва $OPTIONS_FILE. Скриптът не може да продължи."
    exit 1
  fi

  echo "🔧 Добавяне на ACL 'trusted' и политики..."
  sed -i '/acl "trusted"/,/};/d' "$OPTIONS_FILE"
  sed -i "1i acl \"trusted\" {\n    $SERVER_IP;\n    $SECOND_DNS_IP;\n};\n" "$OPTIONS_FILE"

  sed -i '/allow-transfer/d' "$OPTIONS_FILE"
  sed -i '/options {/,/};/ {
    /^};/i\    allow-transfer { trusted; };
  }' "$OPTIONS_FILE"

  if [[ "$DNS_ROLE" == "primary" ]]; then
    sed -i '/also-notify/d' "$OPTIONS_FILE"
    sed -i '/options {/,/};/ {
      /^};/i\    also-notify { '"$SECOND_DNS_IP"'; };
    }' "$OPTIONS_FILE"
  fi

  echo "✅ ACL конфигурацията е добавена."
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 3: Проверка и рестарт
  # -------------------------------------------------------------------------------------
  echo "🔍 Проверка на синтаксиса..."
  if ! named-checkconf; then
    echo "❌ Грешка в конфигурацията след промени."
    exit 1
  fi
  echo "✅ Синтаксисът е валиден."

  echo "🔄 Рестартиране на Bind9..."
  systemctl restart bind9
  if ! systemctl is-active --quiet bind9; then
    echo "❌ Bind9 не стартира след промени."
    exit 1
  fi
  echo "✅ Bind9 е рестартиран успешно."
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 4: Запис в todo.modules
  # -------------------------------------------------------------------------------------
  touch "$MODULES_FILE"
  for VAR in SERVER_IP SECOND_DNS_IP SERVER_FQDN DNS_ROLE; do
    VALUE=$(eval echo "\$$VAR")
    grep -q "^$VAR=" "$MODULES_FILE" && sed -i "s|^$VAR=.*|$VAR=\"$VALUE\"|" "$MODULES_FILE" || echo "$VAR=\"$VALUE\"" >> "$MODULES_FILE"
  done

  echo "✅ Данните са записани в $MODULES_FILE."
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 5: Запис на резултат
  # -------------------------------------------------------------------------------------
  grep -q '^SECURE_DNS_MODULE3=' "$SETUP_ENV_FILE" && sed -i 's|^SECURE_DNS_MODULE3=.*|SECURE_DNS_MODULE3=✅|' "$SETUP_ENV_FILE" || echo "SECURE_DNS_MODULE3=✅" >> "$SETUP_ENV_FILE"

  echo "✅ Модул 3 завърши успешно."
fi
echo ""
echo ""


# =====================================================================
# [МОДУЛ 4] ГЕНЕРИРАНЕ НА TSIG КЛЮЧ
# =====================================================================
echo "[4] ГЕНЕРИРАНЕ НА TSIG КЛЮЧ..."
echo "-----------------------------------------------------------"
echo ""

SETUP_ENV_FILE="/etc/netgalaxy/setup.env"
KEYS_DIR="/etc/bind/keys"
TSIG_KEY_FILE="$KEYS_DIR/tsig.key"
CONF_LOCAL="/etc/bind/named.conf.local"

if grep -q '^SECURE_DNS_MODULE4=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 4 вече е изпълнен успешно. Пропускане..."
  echo ""
else
  echo "▶ Започва изпълнение на Модул 4..."
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 1: Проверка и подготовка на директория за ключове
  # -------------------------------------------------------------------------------------
  if [[ ! -d "$KEYS_DIR" ]]; then
    mkdir -p "$KEYS_DIR"
    chown bind:bind "$KEYS_DIR"
    chmod 750 "$KEYS_DIR"
    echo "✅ Директорията $KEYS_DIR е създадена."
  else
    echo "ℹ️ Директорията $KEYS_DIR вече съществува."
  fi

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 2: Генериране на TSIG ключ (hmac-sha256)
  # -------------------------------------------------------------------------------------
  if [[ ! -f "$TSIG_KEY_FILE" ]]; then
    echo "🔐 Генериране на TSIG ключ (hmac-sha256)..."
    if command -v tsig-keygen >/dev/null 2>&1; then
      tsig-keygen -a hmac-sha256 netgalaxy-key > "$TSIG_KEY_FILE"
      chown bind:bind "$TSIG_KEY_FILE"
      chmod 640 "$TSIG_KEY_FILE"
      echo "✅ TSIG ключът е генериран и записан в $TSIG_KEY_FILE."
    else
      echo "❌ Липсва tsig-keygen! Инсталирайте пакета bind9-utils и опитайте отново."
      exit 1
    fi
  else
    echo "ℹ️ TSIG ключът вече съществува в $TSIG_KEY_FILE."
  fi

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 3: Добавяне на ключа в named.conf.local
  # -------------------------------------------------------------------------------------
  if [[ ! -f "$CONF_LOCAL" ]]; then
    echo "❌ Липсва $CONF_LOCAL. Скриптът не може да продължи."
    exit 1
  fi

  if ! grep -q "include \"$TSIG_KEY_FILE\"" "$CONF_LOCAL"; then
    echo "include \"$TSIG_KEY_FILE\";" >> "$CONF_LOCAL"
    echo "✅ TSIG ключът е включен в $CONF_LOCAL."
  else
    echo "ℹ️ TSIG ключът вече е добавен в $CONF_LOCAL."
  fi

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 4: Проверка на синтаксиса и рестарт
  # -------------------------------------------------------------------------------------
  echo "🔍 Проверка на синтаксиса..."
  if ! named-checkconf; then
    echo "❌ Грешка в конфигурацията след добавяне на TSIG ключа."
    exit 1
  fi
  echo "✅ Синтаксисът е валиден."

  echo "🔄 Рестартиране на Bind9..."
  systemctl restart bind9
  if ! systemctl is-active --quiet bind9; then
    echo "❌ Bind9 не стартира след промени."
    exit 1
  fi
  echo "✅ Bind9 е рестартиран успешно."
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 5: Запис в setup.env
  # -------------------------------------------------------------------------------------
  grep -q '^SECURE_DNS_MODULE4=' "$SETUP_ENV_FILE" && sed -i 's|^SECURE_DNS_MODULE4=.*|SECURE_DNS_MODULE4=✅|' "$SETUP_ENV_FILE" || echo "SECURE_DNS_MODULE4=✅" >> "$SETUP_ENV_FILE"

  echo "✅ Модул 4 завърши успешно."
fi
echo ""
echo ""


# =====================================================================
# [МОДУЛ 5] ПРОВЕРКА И РЕСТАРТ
# =====================================================================
echo "[5] ПРОВЕРКА И РЕСТАРТ..."
echo "-----------------------------------------------------------"
echo ""

SETUP_ENV_FILE="/etc/netgalaxy/setup.env"

if [[ ! -f "$SETUP_ENV_FILE" ]]; then
  echo "❌ Липсва $SETUP_ENV_FILE. Стартирайте предишните модули!"
  exit 1
fi

if grep -q '^SECURE_DNS_MODULE5=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 5 вече е изпълнен успешно. Пропускане..."
  echo ""
else
  echo "▶ Започва изпълнение на Модул 5..."
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 1: Проверка на синтаксиса
  # -------------------------------------------------------------------------------------
  echo "🔍 Проверка на синтаксиса на BIND конфигурацията..."
  if ! named-checkconf; then
    echo "❌ Грешка: конфигурацията на BIND съдържа проблеми!"
    echo "➡ Проверете конфигурационните файлове преди да продължите."
    exit 1
  fi
  echo "✅ Конфигурацията е валидна."
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 2: Рестартиране на услугата Bind9
  # -------------------------------------------------------------------------------------
  echo "🔄 Рестартиране на Bind9..."
  if systemctl restart bind9; then
    echo "✅ Услугата Bind9 е рестартирана."
  else
    echo "❌ Неуспешен рестарт на Bind9!"
    exit 1
  fi

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 3: Проверка дали услугата е активна
  # -------------------------------------------------------------------------------------
  echo "🔍 Проверка дали Bind9 е активна..."
  if systemctl is-active --quiet bind9; then
    echo "✅ Bind9 е активна и работи."
  else
    echo "❌ Bind9 не е активна след рестарт!"
    exit 1
  fi
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 4: Запис на резултата
  # -------------------------------------------------------------------------------------
  grep -q '^SECURE_DNS_MODULE5=' "$SETUP_ENV_FILE" && sed -i 's|^SECURE_DNS_MODULE5=.*|SECURE_DNS_MODULE5=✅|' "$SETUP_ENV_FILE" || echo "SECURE_DNS_MODULE5=✅" >> "$SETUP_ENV_FILE"

  echo "✅ Модул 5 завърши успешно."
fi
echo ""
echo ""


# =====================================================================
# [МОДУЛ 6] ПОДГОТОВКА ЗА TSIG ТЕСТ
# =====================================================================
echo "[6] ПОДГОТОВКА ЗА TSIG ТЕСТ..."
echo "-----------------------------------------------------------"
echo ""

SETUP_ENV_FILE="/etc/netgalaxy/setup.env"
MODULES_FILE="/etc/netgalaxy/todo.modules"
TSIG_KEY_FILE="/etc/bind/keys/tsig.key"

if [[ ! -f "$SETUP_ENV_FILE" ]]; then
  echo "❌ Липсва $SETUP_ENV_FILE. Стартирайте предишните модули!"
  exit 1
fi

if grep -q '^SECURE_DNS_MODULE6=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 6 вече е изпълнен успешно. Пропускане..."
  echo ""
else
  echo "▶ Започва изпълнение на Модул 6..."
  echo ""

  # Проверка за TSIG ключ
  if [[ ! -f "$TSIG_KEY_FILE" ]]; then
    echo "❌ Липсва TSIG ключ ($TSIG_KEY_FILE). Модул 4 не е изпълнен."
    exit 1
  fi

  # Проверка за команда dig
  if ! command -v dig &>/dev/null; then
    echo "❌ Липсва командата dig! Инсталирайте пакет dnsutils."
    exit 1
  fi

  # Зареждане на данни
  if [[ ! -f "$MODULES_FILE" ]]; then
    echo "❌ Липсва $MODULES_FILE. Скриптът не може да продължи."
    exit 1
  fi

  SERVER_FQDN=$(grep '^SERVER_FQDN=' "$MODULES_FILE" | awk -F'=' '{print $2}' | tr -d '"')
  DNS_ROLE=$(grep '^DNS_ROLE=' "$MODULES_FILE" | awk -F'=' '{print $2}' | tr -d '"')
  SECOND_DNS_IP=$(grep '^SECOND_DNS_IP=' "$MODULES_FILE" | awk -F'=' '{print $2}' | tr -d '"')

  if [[ -z "$SERVER_FQDN" || -z "$DNS_ROLE" || -z "$SECOND_DNS_IP" ]]; then
    echo "❌ Липсват критични данни (SERVER_FQDN, DNS_ROLE или SECOND_DNS_IP)."
    exit 1
  fi

  DOMAIN=$(echo "$SERVER_FQDN" | cut -d '.' -f2-)

  # Извличане на името на ключа
  TSIG_KEY_NAME=$(grep 'key "' "$TSIG_KEY_FILE" | awk '{print $2}' | tr -d '"')
  if [[ -z "$TSIG_KEY_NAME" ]]; then
    echo "❌ Неуспешно извличане на името на TSIG ключа."
    exit 1
  fi

  # Показване на данни
  echo "✅ Подготовка за TSIG тест:"
  echo "SERVER_FQDN=$SERVER_FQDN"
  echo "DNS_ROLE=$DNS_ROLE"
  echo "DOMAIN=$DOMAIN"
  echo "SECOND_DNS_IP=$SECOND_DNS_IP"
  echo "TSIG_KEY_NAME=$TSIG_KEY_NAME"
  echo ""

  # Запис в setup.env
  grep -q '^SECURE_DNS_MODULE6=' "$SETUP_ENV_FILE" && sed -i 's|^SECURE_DNS_MODULE6=.*|SECURE_DNS_MODULE6=✅|' "$SETUP_ENV_FILE" || echo "SECURE_DNS_MODULE6=✅" >> "$SETUP_ENV_FILE"

  echo "✅ Модул 6 завърши успешно."
fi
echo ""
echo ""










exit 0



# =====================================================================
# [МОДУЛ 7] ФИНАЛЕН ОТЧЕТ
# =====================================================================
echo "[7] ФИНАЛЕН ОТЧЕТ..."
echo "-----------------------------------------------------------"
echo ""

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 1: Показване на статуса на всички модули
# -------------------------------------------------------------------------------------
echo -e "\e[32m=========================================="
echo -e "         ОТЧЕТ ЗА DNS HARDENING"
echo -e "==========================================\e[0m"
echo ""

MODULE1_STATUS=$(sudo grep '^SECURE_DNS_MODULE1=' "$SETUP_ENV_FILE" 2>/dev/null | cut -d '=' -f2)
MODULE2_STATUS=$(sudo grep '^SECURE_DNS_MODULE2=' "$SETUP_ENV_FILE" 2>/dev/null | cut -d '=' -f2)
MODULE3_STATUS=$(sudo grep '^SECURE_DNS_MODULE3=' "$SETUP_ENV_FILE" 2>/dev/null | cut -d '=' -f2)
MODULE4_STATUS=$(sudo grep '^SECURE_DNS_MODULE4=' "$SETUP_ENV_FILE" 2>/dev/null | cut -d '=' -f2)
MODULE5_STATUS=$(sudo grep '^SECURE_DNS_MODULE5=' "$SETUP_ENV_FILE" 2>/dev/null | cut -d '=' -f2)
MODULE6_STATUS=$(sudo grep '^SECURE_DNS_MODULE6=' "$SETUP_ENV_FILE" 2>/dev/null | cut -d '=' -f2)

echo "📌 Модул 1 – Предварителни проверки:     ${MODULE1_STATUS:-❌}"
echo "📌 Модул 2 – Инсталиране на пакети:      ${MODULE2_STATUS:-❌}"
echo "📌 Модул 3 – ACL и IP ограничения:       ${MODULE3_STATUS:-❌}"
echo "📌 Модул 4 – Генериране на TSIG ключ:    ${MODULE4_STATUS:-❌}"
echo "📌 Модул 5 – Проверка и рестарт:         ${MODULE5_STATUS:-❌}"
echo "📌 Модул 6 – Тест на TSIG:               ${MODULE6_STATUS:-❌}"
echo ""
echo "------------------------------------------------------------------"
echo ""

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 2: Потвърждение от оператора
# -------------------------------------------------------------------------------------
read -p "✅ Приемате ли конфигурацията като успешна? (y/n): " confirm
if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
  # ✅ Запис на финален статус
  if sudo grep -q '^SETUP_SECURE_DNS_STATUS=' "$SETUP_ENV_FILE" 2>/dev/null; then
    sudo sed -i 's|^SETUP_SECURE_DNS_STATUS=.*|SETUP_SECURE_DNS_STATUS=✅|' "$SETUP_ENV_FILE"
  else
    echo "SETUP_SECURE_DNS_STATUS=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
  fi

  # ✅ Изтриване на временни файлове
  if [[ -f "$MODULES_FILE" ]]; then
    sudo rm -f "$MODULES_FILE"
    echo "🗑️ Файлът $MODULES_FILE беше изтрит."
  fi

  # ✅ Изтриване на скрипта
  echo "🗑️ Скриптът ще се премахне."
  [[ -f "$0" ]] && sudo rm -- "$0"

  echo "🎯 Конфигурацията на DNS сигурността е завършена успешно."
else
  echo "ℹ️ Конфигурацията не е маркирана като успешна. Нищо не е изтрито."
fi

echo ""
echo ""

# ------------ Край на скрипта ------------
