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

# Директории и файлове
NETGALAXY_DIR="/etc/netgalaxy"
MODULES_FILE="$NETGALAXY_DIR/todo.modules"
SETUP_ENV_FILE="$NETGALAXY_DIR/setup.env"

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 1: Проверка за базова DNS конфигурация
# -------------------------------------------------------------------------------------
if [[ ! -f "$SETUP_ENV_FILE" ]] || ! sudo grep -q '^SETUP_VPS_DNS_STATUS=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "🛑 Не е открита завършена базова DNS конфигурация."
  echo "ℹ️ Стартирайте първо скрипта vps-dns-qsetup.sh и опитайте отново."
  echo "🗑️ Премахване на скрипта."
  [[ -f "$0" ]] && sudo rm -- "$0"
  exit 1
fi

# Проверка дали защитната конфигурация вече е завършена
if sudo grep -q '^SETUP_SECURE_DNS_STATUS=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "🛑 Скриптът вече е изпълнен (DNS сигурността е активирана)."
  echo "🗑️ Премахване на скрипта."
  [[ -f "$0" ]] && sudo rm -- "$0"
  exit 0
fi

# Проверка дали Модул 1 вече е изпълнен
if sudo grep -q '^SECURE_DNS_MODULE1=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
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
  if [[ ! -f "$MODULES_FILE" ]]; then
    sudo touch "$MODULES_FILE"
  fi

  # SERVER_IP
  if sudo grep -q '^SERVER_IP=' "$MODULES_FILE" 2>/dev/null; then
    sudo sed -i "s|^SERVER_IP=.*|SERVER_IP=\"$SERVER_IP\"|" "$MODULES_FILE"
  else
    echo "SERVER_IP=\"$SERVER_IP\"" | sudo tee -a "$MODULES_FILE" > /dev/null
  fi

  # SERVER_FQDN
  if sudo grep -q '^SERVER_FQDN=' "$MODULES_FILE" 2>/dev/null; then
    sudo sed -i "s|^SERVER_FQDN=.*|SERVER_FQDN=\"$HOSTNAME_FQDN\"|" "$MODULES_FILE"
  else
    echo "SERVER_FQDN=\"$HOSTNAME_FQDN\"" | sudo tee -a "$MODULES_FILE" > /dev/null
  fi

  echo "✅ Данните са записани в $MODULES_FILE."
  echo ""

  # ✅ Запис на резултат за Модул 1
  if sudo grep -q '^SECURE_DNS_MODULE1=' "$SETUP_ENV_FILE" 2>/dev/null; then
    sudo sed -i 's|^SECURE_DNS_MODULE1=.*|SECURE_DNS_MODULE1=✅|' "$SETUP_ENV_FILE"
  else
    echo "SECURE_DNS_MODULE1=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
  fi

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

# Проверка дали модулът вече е изпълнен
if sudo grep -q '^SECURE_DNS_MODULE2=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 2 вече е изпълнен успешно. Пропускане..."
  echo ""
else
  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 1: Проверка за съществуване на named.conf.options
  # -------------------------------------------------------------------------------------
  OPTIONS_FILE="/etc/bind/named.conf.options"
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

  # Премахваме стари директиви (ако присъстват с различни стойности)
  sudo sed -i '/recursion/d' "$OPTIONS_FILE"
  sudo sed -i '/allow-transfer/d' "$OPTIONS_FILE"
  sudo sed -i '/allow-recursion/d' "$OPTIONS_FILE"

  # Добавяме нужните директиви (ако ги няма)
  sudo sed -i '/options {/,/};/ {
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
  if ! sudo named-checkconf; then
    echo "❌ Грешка в конфигурацията на Bind9 след промени."
    exit 1
  fi
  echo "✅ Синтаксисът е валиден."
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 4: Рестартиране на услугата
  # -------------------------------------------------------------------------------------
  echo "🔄 Рестартиране на Bind9..."
  sudo systemctl restart bind9
  if ! systemctl is-active --quiet bind9; then
    echo "❌ Услугата Bind9 не стартира след промени."
    exit 1
  fi
  echo "✅ Bind9 е рестартиран успешно."
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 5: Запис на резултат за Модул 2
  # -------------------------------------------------------------------------------------
  if sudo grep -q '^SECURE_DNS_MODULE2=' "$SETUP_ENV_FILE" 2>/dev/null; then
    sudo sed -i 's|^SECURE_DNS_MODULE2=.*|SECURE_DNS_MODULE2=✅|' "$SETUP_ENV_FILE"
  else
    echo "SECURE_DNS_MODULE2=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
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

if sudo grep -q '^SECURE_DNS_MODULE3=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 3 вече е изпълнен успешно. Пропускане..."
  echo ""
else
  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 1: Подготовка и четене на текущи данни
  # -------------------------------------------------------------------------------------
  SERVER_IP=""
  SECOND_DNS_IP=""
  DNS_ROLE=""

  # Ако файлът съществува → четем
  if [[ -f "$MODULES_FILE" ]]; then
    SERVER_IP=$(grep '^SERVER_IP=' "$MODULES_FILE" | awk -F'=' '{print $2}' | tr -d '"')
    SECOND_DNS_IP=$(grep '^SECOND_DNS_IP=' "$MODULES_FILE" | awk -F'=' '{print $2}' | tr -d '"')
    DNS_ROLE=$(grep '^DNS_ROLE=' "$MODULES_FILE" | awk -F'=' '{print $2}' | tr -d '"')
  else
    sudo touch "$MODULES_FILE"
  fi

  # Ако липсва SERVER_IP → изискваме
  if [[ -z "$SERVER_IP" ]]; then
    read -p "🌐 Въведете публичния IP на този DNS сървър: " SERVER_IP
    if [[ -z "$SERVER_IP" ]]; then
      echo "❌ SERVER_IP е задължителен."
      exit 1
    fi
    if sudo grep -q '^SERVER_IP=' "$MODULES_FILE" 2>/dev/null; then
      sudo sed -i "s|^SERVER_IP=.*|SERVER_IP=\"$SERVER_IP\"|" "$MODULES_FILE"
    else
      echo "SERVER_IP=\"$SERVER_IP\"" | sudo tee -a "$MODULES_FILE" > /dev/null
    fi
  fi

  # Ако липсва SECOND_DNS_IP → изискваме
  if [[ -z "$SECOND_DNS_IP" ]]; then
    read -p "🌐 Въведете IP на другия DNS сървър: " SECOND_DNS_IP
    if [[ -z "$SECOND_DNS_IP" ]]; then
      echo "❌ SECOND_DNS_IP е задължителен."
      exit 1
    fi
    if sudo grep -q '^SECOND_DNS_IP=' "$MODULES_FILE" 2>/dev/null; then
      sudo sed -i "s|^SECOND_DNS_IP=.*|SECOND_DNS_IP=\"$SECOND_DNS_IP\"|" "$MODULES_FILE"
    else
      echo "SECOND_DNS_IP=\"$SECOND_DNS_IP\"" | sudo tee -a "$MODULES_FILE" > /dev/null
    fi
  fi

  # Ако липсва DNS_ROLE → определяме по hostname
  if [[ -z "$DNS_ROLE" ]]; then
    HOSTNAME_FQDN=$(hostname -f 2>/dev/null || echo "")
    if [[ "$HOSTNAME_FQDN" =~ ^ns1\. ]]; then
      DNS_ROLE="primary"
    elif [[ "$HOSTNAME_FQDN" =~ ^ns[23]\. ]]; then
      DNS_ROLE="secondary"
    else
      echo "❌ Неуспешно определяне на DNS_ROLE (hostname=$HOSTNAME_FQDN)."
      exit 1
    fi
    if sudo grep -q '^DNS_ROLE=' "$MODULES_FILE" 2>/dev/null; then
      sudo sed -i "s|^DNS_ROLE=.*|DNS_ROLE=\"$DNS_ROLE\"|" "$MODULES_FILE"
    else
      echo "DNS_ROLE=\"$DNS_ROLE\"" | sudo tee -a "$MODULES_FILE" > /dev/null
    fi
  fi

  echo "✅ Данни за ACL: SERVER_IP=$SERVER_IP | SECOND_DNS_IP=$SECOND_DNS_IP | DNS_ROLE=$DNS_ROLE"
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 2: Обновяване на named.conf.options
  # -------------------------------------------------------------------------------------
  OPTIONS_FILE="/etc/bind/named.conf.options"
  if [[ ! -f "$OPTIONS_FILE" ]]; then
    echo "❌ Липсва $OPTIONS_FILE. Скриптът не може да продължи."
    exit 1
  fi

  echo "🔧 Добавяне на ACL 'trusted' в $OPTIONS_FILE..."
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

  echo "✅ ACL добавен успешно."
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
  echo "✅ Bind9 е рестартиран."
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






exit 0


# =====================================================================
# [МОДУЛ 4] ГЕНЕРИРАНЕ НА TSIG КЛЮЧ
# =====================================================================
echo "[4] ГЕНЕРИРАНЕ НА TSIG КЛЮЧ..."
echo "-----------------------------------------------------------"
echo ""
# TODO:
# - Генериране на TSIG ключ с tsig-keygen (hmac-sha256).
# - Записване в /etc/bind/keys/tsig.key.
# - Добавяне в named.conf.local и зоните.
echo ""
echo ""

# =====================================================================
# [МОДУЛ 5] ПРОВЕРКА И РЕСТАРТ
# =====================================================================
echo "[5] ПРОВЕРКА И РЕСТАРТ..."
echo "-----------------------------------------------------------"
echo ""
# TODO:
# - Проверка на синтаксиса с named-checkconf.
# - Рестарт на bind9.
# - Проверка дали услугата е активна.
echo ""
echo ""

# =====================================================================
# [МОДУЛ 6] ТЕСТ НА TSIG
# =====================================================================
echo "[6] ТЕСТ НА TSIG..."
echo "-----------------------------------------------------------"
echo ""
# TODO:
# - Използване на dig за тестов AXFR със секретен ключ.
# - Проверка за грешки в логовете.
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
# - Потвърждение от оператора.
# - Изтриване на временните файлове и (по избор) скрипта.
echo ""
echo ""

echo "✅ Шаблонът на скрипта е готов. Попълнете модулите с реална логика."
