#!/bin/bash

# ==========================================================================
#  vps-dns-qsetup - Автоматизирана конфигурация на DNS сървър (Bind9)
# --------------------------------------------------------------------------
#  Версия: 1.0
#  Дата: 2025-07-18
#  Автор: Ilko Yordanov / NetGalaxy
# ==========================================================================
#
#  Този скрипт извършва автоматизирана конфигурация на DNS сървър (Bind9)
#  върху VPS, подготвен с базовия скрипт vps-base-qsetup.sh.
#  Скриптът се изпълнява директно на сървъра и следва модулен принцип.
#
#  Модули:
#    1. Проверки (IP, hostname, setup.env, предишно изпълнение)
#    2. Подготовка на системата
#    3. Инсталиране и конфигуриране на Bind9
#    4. Създаване на основни зони и записи
#    5. Активиране и тестване на DNS услугата
# ==========================================================================

# === ПОМОЩНА ИНФОРМАЦИЯ ===================================================
show_help() {
  echo "Използване: vps-dns-qsetup.sh [опция]"
  echo ""
  echo "Автоматизирана и безопасна конфигурация на DNS сървър (Bind9) върху VPS."
  echo ""
  echo "Опции:"
  echo "  --version       Показва версията на скрипта"
  echo "  --help          Показва тази помощ"
}

# === ОБРАБОТКА НА ОПЦИИ ====================================================
if [[ $# -gt 0 ]]; then
  case "$1" in
    --version)
      echo "vps-dns-qsetup версия 1.0 (18 юли 2025 г.)"
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

echo ""
echo -e "\e[32m=========================================="
echo -e " НАЧАЛНА КОНФИГУРАЦИЯ НА ОТДАЛЕЧЕН СЪРВЪР"
echo -e "==========================================\e[0m"
echo ""

NETGALAXY_DIR="/etc/netgalaxy"
MODULES_FILE="$NETGALAXY_DIR/todo.modules"
SETUP_ENV_FILE="$NETGALAXY_DIR/setup.env"


# === [МОДУЛ 1] КОНФИГУРИРАНЕ НА DNS СЪРВЪР =========================
echo "[1] КОНФИГУРИРАНЕ НА DNS СЪРВЪР..."
echo "-----------------------------------------------------------"
echo ""

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 1: Проверка дали скриптът ще бъде стартиран на правилната операционна система.
# -------------------------------------------------------------------------------------

# --- Проверка на операционната система ---
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
echo ""

#------------------------------------------------------------------------
# СЕКЦИЯ 2: Проверка дали скриптът ще бъде стартиран на правилния сървър.
#-------------------------------------------------------------------------
while true; do
  printf "🌐 Въведете публичния IP адрес на сървъра (или 'q' за изход): "
  read SERVER_IP

  if [[ "$SERVER_IP" == "q" || "$SERVER_IP" == "Q" ]]; then
    echo "❎ Скриптът беше прекратен от потребителя."
    exit 0
  fi

  # Проверка за валиден IPv4 формат
  if ! [[ "$SERVER_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Невалиден IP адрес. Моля, въведете валиден IPv4 адрес (пример: 192.168.1.100)."
    continue
  fi

  # Извличане на реалния публичен IP
  ACTUAL_IP=$(curl -s -4 ifconfig.me)

  if [[ "$ACTUAL_IP" != "$SERVER_IP" ]]; then
    echo ""
    echo "🚫 Несъответствие! Въведеният IP ($SERVER_IP) не съвпада с реалния IP на машината."
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
echo ""
echo ""

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 3: Проверка дали hostname е домейн от трето ниво, започващ с ns1, ns2 или ns3.
# -------------------------------------------------------------------------------------

echo "🔍 Проверка на hostname..."
HOSTNAME_FQDN=$(hostname -f 2>/dev/null || echo "")

if [[ -z "$HOSTNAME_FQDN" ]]; then
  echo "❌ Неуспешно извличане на пълния hostname (FQDN)."
  echo "Скриптът не може да продължи без валиден FQDN."
  exit 1
fi

# Проверка за трето ниво и префикс ns1/ns2/ns3
if [[ ! "$HOSTNAME_FQDN" =~ ^ns[1-3]\..+\..+$ ]]; then
  echo ""
  echo "🚫 Несъвместим или недопустим домейн: $HOSTNAME_FQDN"
  echo ""
  echo "ℹ️ Този скрипт е предназначен за конфигуриране на DNS сървъри, работещи в мрежата NetGalaxy"
  echo "или обслужващи платформата NetGalaxy. Въведеният hostname не отговаря на изискванията."
  echo ""
  exit 1
fi

echo "✅ Потвърдено: hostname отговаря на изискванията ($HOSTNAME_FQDN)."
echo ""

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 4: Проверка във файла файла /etc/netgalaxy/setup.env дали сървърът има успешна 
# начална конфигурация и дали този скрипт вече е бил изпълнен на този сървър.
# -------------------------------------------------------------------------------------

echo "🔍 Проверка на статуса на сървъра в $SETUP_ENV_FILE..."
echo ""

# 🔒 Проверка дали началната конфигурация е била извършена:
if [[ ! -f "$SETUP_ENV_FILE" ]] || ! sudo grep -q '^SETUP_VPS_BASE_STATUS=✅' "$SETUP_ENV_FILE"; then
  echo "🛑 Началната конфигурация на този сървър не е в съответствие с изискванията "
  echo "   за конфигуриране на сървърите от мрежата NetGalaxy. Моля, използвайте скрипта "
  echo "   vps-base-qsetup.sh за правилното начално конфигуриране на сървъра."
  echo ""
  echo "🔧 Изпълнението на скрипта не може да продължи."
  echo ""
  [[ -f "$0" ]] && rm -- "$0"
  exit 1
fi

# 🔒 Проверка дали конфигурацията с този скрипт вече е била извършена
if sudo grep -q '^SETUP_VPS_DNS_STATUS=✅' "$SETUP_ENV_FILE"; then
  echo "🛑 Този скрипт вече е бил изпълнен на този сървър."
  echo "   Повторно изпълнение не се разрешава за предпазване от сбой на системата."
  echo ""
  [[ -f "$0" ]] && rm -- "$0"
  exit 0
fi

# ✅ Запис или обновяване на IP и FQDN в todo.modules
if sudo grep -q '^SERVER_IP=' "$MODULES_FILE" 2>/dev/null; then
  sudo sed -i "s|^SERVER_IP=.*|SERVER_IP=\"$SERVER_IP\"|" "$MODULES_FILE"
else
  echo "SERVER_IP=\"$SERVER_IP\"" | sudo tee -a "$MODULES_FILE" > /dev/null
fi

if sudo grep -q '^SERVER_FQDN=' "$MODULES_FILE" 2>/dev/null; then
  sudo sed -i "s|^SERVER_FQDN=.*|SERVER_FQDN=\"$HOSTNAME_FQDN\"|" "$MODULES_FILE"
else
  echo "SERVER_FQDN=\"$HOSTNAME_FQDN\"" | sudo tee -a "$MODULES_FILE" > /dev/null
fi

# ✅ Запис на резултата в setup.env
if sudo grep -q '^SETUP_VPS_DNS_STATUS=' "$SETUP_ENV_FILE" 2>/dev/null; then
  sudo sed -i 's|^SETUP_VPS_DNS_STATUS=.*|SETUP_VPS_DNS_STATUS=✅|' "$SETUP_ENV_FILE"
else
  echo "RESULT_DNS_CHECKS=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
fi

echo "✅ Сървърът е с валидна начална конфигурация."
echo ""
echo ""


# === [МОДУЛ 2] ИНСТАЛИРАНЕ НА BIND9 =========================
echo "[2] ИНСТАЛИРАНЕ НА BIND9..."
echo "-----------------------------------------------------------"
echo ""

# Проверка дали BIND9 вече е инсталиран
if dpkg -s bind9 >/dev/null 2>&1; then
  echo "ℹ️ BIND9 вече е инсталиран. Пропускане на този модул."
  # ✅ Запис на резултата в setup.env (обновяване или добавяне)
  if sudo grep -q '^RESULT_BIND9_INSTALL=' "$SETUP_ENV_FILE" 2>/dev/null; then
    sudo sed -i 's|^RESULT_BIND9_INSTALL=.*|RESULT_BIND9_INSTALL=✅ (вече инсталиран)|' "$SETUP_ENV_FILE"
  else
    echo "RESULT_BIND9_INSTALL=✅ (вече инсталиран)" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
  fi
else
  echo "⏳ Инсталиране на BIND9 (bind9 bind9-utils bind9-dnsutils)..."
  if sudo apt-get update && sudo apt-get install -y bind9 bind9-utils bind9-dnsutils; then
    echo "🔍 Проверка на статуса на услугата BIND9..."
    if systemctl is-active --quiet bind9; then
      echo "✅ BIND9 е инсталиран и услугата работи."
      # ✅ Запис на резултата в setup.env
      if sudo grep -q '^RESULT_BIND9_INSTALL=' "$SETUP_ENV_FILE" 2>/dev/null; then
        sudo sed -i 's|^RESULT_BIND9_INSTALL=.*|RESULT_BIND9_INSTALL=✅|' "$SETUP_ENV_FILE"
      else
        echo "RESULT_BIND9_INSTALL=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
      fi
    else
      echo "❌ Инсталацията приключи, но услугата BIND9 не е активна."
      echo "⛔ Скриптът не може да продължи. Проверете конфигурацията ръчно."
      [[ -f "$0" ]] && rm -- "$0"
      exit 1
    fi
  else
    echo "❌ Възникна грешка при инсталирането на BIND9."
    echo "⛔ Скриптът не може да продължи."
    [[ -f "$0" ]] && rm -- "$0"
    exit 1
  fi
fi
echo ""
echo ""

# === [МОДУЛ 4] ОПРЕДЕЛЯНЕ НА РОЛЯТА НА DNS СЪРВЪРА =========================
echo "[4] ОПРЕДЕЛЯНЕ НА РОЛЯТА НА DNS СЪРВЪРА..."
echo "-----------------------------------------------------------"
echo ""

# 🔍 Проверка дали модулът вече е изпълнен
if sudo grep -q '^RESULT_BIND9_ROLE=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 4 вече е изпълнен успешно. Пропускане..."
  echo ""
  return 0 2>/dev/null || exit 0
fi

# ✅ Четене на данни от todo.modules
if [[ -f "$MODULES_FILE" ]]; then
  SERVER_FQDN=$(grep '^SERVER_FQDN=' "$MODULES_FILE" | cut -d '"' -f2)
else
  echo "❌ Липсва файлът $MODULES_FILE. Скриптът не може да продължи."
  [[ -f "$0" ]] && rm -- "$0"
  exit 1
fi

# 🔍 Проверка дали имаме валиден FQDN
if [[ -z "$SERVER_FQDN" ]]; then
  echo "❌ Не е намерен SERVER_FQDN в $MODULES_FILE. Скриптът не може да продължи."
  [[ -f "$0" ]] && rm -- "$0"
  exit 1
fi

# ✅ Определяне на ролята по FQDN
DNS_ROLE=""
if [[ "$SERVER_FQDN" =~ ^ns1\. ]]; then
  DNS_ROLE="primary"
elif [[ "$SERVER_FQDN" =~ ^ns[23]\. ]]; then
  DNS_ROLE="secondary"
else
  echo "🛑 Несъвместимо име на сървъра: $SERVER_FQDN"
  echo "Скриптът не може да продължи, защото този сървър не е валиден DNS (ns1/ns2/ns3)."
  [[ -f "$0" ]] && rm -- "$0"
  exit 1
fi

echo "✅ Определена роля: $DNS_ROLE"
echo ""

# ✅ Запис или обновяване на DNS_ROLE в todo.modules
if sudo grep -q '^DNS_ROLE=' "$MODULES_FILE" 2>/dev/null; then
  sudo sed -i "s|^DNS_ROLE=.*|DNS_ROLE=\"$DNS_ROLE\"|" "$MODULES_FILE"
else
  echo "DNS_ROLE=\"$DNS_ROLE\"" | sudo tee -a "$MODULES_FILE" > /dev/null
fi

# ✅ Подготовка на named.conf.local (ако не съществува)
if [[ ! -f /etc/bind/named.conf.local ]]; then
  echo "// Локални DNS зони ще се добавят тук" | sudo tee /etc/bind/named.conf.local > /dev/null
fi

# ✅ Проверка на синтаксиса
echo "🔍 Проверка на синтаксиса..."
if ! sudo named-checkconf; then
  echo "❌ Грешка в конфигурацията на BIND9. Скриптът не може да продължи."
  [[ -f "$0" ]] && rm -- "$0"
  exit 1
fi

# ✅ Рестарт на услугата
echo "🔄 Рестартиране на BIND9..."
sudo systemctl restart bind9
if ! systemctl is-active --quiet bind9; then
  echo "❌ Услугата BIND9 не стартира след промени. Скриптът не може да продължи."
  [[ -f "$0" ]] && rm -- "$0"
  exit 1
fi

# ✅ Запис на резултата в setup.env
if sudo grep -q '^RESULT_BIND9_ROLE=' "$SETUP_ENV_FILE" 2>/dev/null; then
  sudo sed -i 's|^RESULT_BIND9_ROLE=.*|RESULT_BIND9_ROLE=✅|' "$SETUP_ENV_FILE"
else
  echo "RESULT_BIND9_ROLE=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
fi

echo "✅ Модул 4 завърши успешно: ролята на DNS сървъра е $DNS_ROLE."
echo ""
echo ""
