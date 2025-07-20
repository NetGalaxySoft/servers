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
echo -e "       КОНФИГУРАЦИЯ НА DNS СЪРВЪР"
echo -e "==========================================\e[0m"
echo ""

NETGALAXY_DIR="/etc/netgalaxy"
MODULES_FILE="$NETGALAXY_DIR/todo.modules"
SETUP_ENV_FILE="$NETGALAXY_DIR/setup.env"

# === [МОДУЛ 1] ПРЕДВАРИТЕЛНИ ПРОВЕРКИ =========================
echo "[1] ПРЕДВАРИТЕЛНИ ПРОВЕРКИ..."
echo "-----------------------------------------------------------"
echo ""

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 1: Проверка дали този модул е бил изпълнен
# -------------------------------------------------------------------------------------
if sudo grep -q '^DNS_RESULT_MODULE1=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 1 вече е изпълнен успешно. Пропускане..."
else

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 2: Проверка дали скриптът ще бъде стартиран на правилната операционна система
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
  echo "❌ Операционната система $PRETTY_NAME не се поддържа от този скрипт."
  echo "Поддържани системи: Ubuntu 22.04/24.04, Debian 11/12"
  exit 1
fi

echo "✅ Засечена поддържана ОС: $PRETTY_NAME"
echo ""

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 3: Проверка дали скриптът ще бъде стартиран на правилния сървър
# -------------------------------------------------------------------------------------
while true; do
  printf "🌐 Въведете публичния IP адрес на сървъра (или 'q' за изход): "
  read SERVER_IP

  if [[ "$SERVER_IP" == "q" || "$SERVER_IP" == "Q" ]]; then
    echo "❎ Скриптът беше прекратен от потребителя."
    exit 0
  fi

  if ! [[ "$SERVER_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Невалиден IP адрес. Моля, въведете валиден IPv4 адрес."
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
# СЕКЦИЯ 4: Проверка дали hostname е валиден (ns1/ns2/ns3)
# -------------------------------------------------------------------------------------
echo "🔍 Проверка на hostname..."
HOSTNAME_FQDN=$(hostname -f 2>/dev/null || echo "")

if [[ -z "$HOSTNAME_FQDN" ]]; then
  echo "❌ Неуспешно извличане на FQDN. Скриптът спира."
  exit 1
fi

if [[ ! "$HOSTNAME_FQDN" =~ ^ns[1-3]\..+\..+$ ]]; then
  echo "🚫 Несъвместим или недопустим домейн: $HOSTNAME_FQDN"
  echo "ℹ️ Този скрипт е за DNS сървъри на NetGalaxy."
  exit 1
fi

echo "✅ Потвърдено: hostname = $HOSTNAME_FQDN"
echo ""

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 5: Проверка за начална конфигурация и запис на IP/FQDN
# -------------------------------------------------------------------------------------
if [[ ! -f "$SETUP_ENV_FILE" ]] || ! sudo grep -q '^SETUP_VPS_BASE_STATUS=✅' "$SETUP_ENV_FILE"; then
  echo "🛑 Началната конфигурация липсва. Стартирайте vps-base-qsetup.sh"
  exit 1
fi

if sudo grep -q '^SETUP_VPS_DNS_STATUS=✅' "$SETUP_ENV_FILE"; then
  echo "🛑 Целият DNS скрипт вече е изпълнен на този сървър."
  exit 0
fi

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

# ✅ Запис на резултат
if sudo grep -q '^DNS_RESULT_MODULE1=' "$SETUP_ENV_FILE" 2>/dev/null; then
  sudo sed -i 's|^DNS_RESULT_MODULE1=.*|DNS_RESULT_MODULE1=✅|' "$SETUP_ENV_FILE"
else
  echo "DNS_RESULT_MODULE1=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
fi

echo "✅ Модул 1 завърши успешно."
echo ""
fi


# === [МОДУЛ 2] ИНСТАЛИРАНЕ НА BIND9 =========================
echo "[2] ИНСТАЛИРАНЕ НА BIND9..."
echo "-----------------------------------------------------------"
echo ""

# СЕКЦИЯ 1: Проверка дали модулът вече е изпълнен
if sudo grep -q '^DNS_RESULT_MODULE2=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 2 вече е изпълнен успешно. Пропускане..."
else
  # СЕКЦИЯ 2: Проверка дали BIND9 вече е инсталиран
  if dpkg -s bind9 >/dev/null 2>&1; then
    echo "ℹ️ BIND9 вече е инсталиран. Пропускане на инсталацията."
    # ✅ Запис на резултата
    if sudo grep -q '^DNS_RESULT_MODULE2=' "$SETUP_ENV_FILE" 2>/dev/null; then
      sudo sed -i 's|^DNS_RESULT_MODULE2=.*|DNS_RESULT_MODULE2=✅|' "$SETUP_ENV_FILE"
    else
      echo "DNS_RESULT_MODULE2=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
    fi
  else
    echo "⏳ Инсталиране на BIND9 (bind9 bind9-utils bind9-dnsutils)..."
    if sudo apt-get update && sudo apt-get install -y bind9 bind9-utils bind9-dnsutils; then
      echo "🔍 Проверка на статуса на услугата BIND9..."
      if systemctl is-active --quiet bind9; then
        echo "✅ BIND9 е инсталиран и услугата работи."
        # ✅ Запис на резултата
        if sudo grep -q '^DNS_RESULT_MODULE2=' "$SETUP_ENV_FILE" 2>/dev/null; then
          sudo sed -i 's|^DNS_RESULT_MODULE2=.*|DNS_RESULT_MODULE2=✅|' "$SETUP_ENV_FILE"
        else
          echo "DNS_RESULT_MODULE2=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
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
fi
echo ""
echo ""









exit 0

# === [МОДУЛ 3] КОНФИГУРИРАНЕ НА named.conf.options =========================
echo "[3] КОНФИГУРИРАНЕ НА named.conf.options..."
echo "-----------------------------------------------------------"
echo ""

# СЕКЦИЯ 1: Проверка дали модулът вече е изпълнен
if sudo grep -q '^DNS_RESULT_MODULE3=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 3 вече е изпълнен успешно. Пропускане..."
else
  # ✅ Проверка дали Модул 2 е завършен
  if ! sudo grep -q '^DNS_RESULT_MODULE2=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
    echo "❌ Не може да продължи: Модул 2 не е изпълнен успешно."
    exit 1
  fi

  # ✅ Четене на данни от todo.modules
  if [[ -f "$MODULES_FILE" ]]; then
    SERVER_IP=$(grep '^SERVER_IP=' "$MODULES_FILE" | cut -d '"' -f2)
  else
    echo "❌ Липсва файлът $MODULES_FILE. Скриптът не може да продължи."
    exit 1
  fi

  # 🔍 Проверка дали има валиден IPv4 адрес
  if [[ -z "$SERVER_IP" ]]; then
    echo "❌ Не е намерен SERVER_IP в $MODULES_FILE. Скриптът не може да продължи."
    exit 1
  fi

  # ✅ Проверка за IPv6 поддръжка
  SERVER_IPV6=""
  if ip -6 addr show | grep -q 'inet6 [2-9a-f]'; then
    SERVER_IPV6="yes"
  else
    SERVER_IPV6="no"
  fi

  # ✅ Обновяване или добавяне на IPv6 в todo.modules
  if sudo grep -q '^SERVER_IPV6=' "$MODULES_FILE" 2>/dev/null; then
    sudo sed -i "s|^SERVER_IPV6=.*|SERVER_IPV6=\"$SERVER_IPV6\"|" "$MODULES_FILE"
  else
    echo "SERVER_IPV6=\"$SERVER_IPV6\"" | sudo tee -a "$MODULES_FILE" > /dev/null
  fi

  echo "🔧 Създаване на нова конфигурация в named.conf.options..."
  sudo cp /etc/bind/named.conf.options /etc/bind/named.conf.options.bak

  # ✅ Генериране на новия блок options
  cat <<EOF | sudo tee /etc/bind/named.conf.options > /dev/null
options {
    directory "/var/cache/bind";

    listen-on { $SERVER_IP; };
    $( [[ "$SERVER_IPV6" == "yes" ]] && echo 'listen-on-v6 { any; };' || echo 'listen-on-v6 { none; };' )

    allow-query { any; };

    recursion no;

    forwarders {
        1.1.1.1;
        8.8.8.8;
    };

    dnssec-validation auto;
};
EOF

  # ✅ Проверка на синтаксиса
  echo "🔍 Проверка на синтаксиса..."
  if ! sudo named-checkconf; then
    echo "❌ Грешка в конфигурацията на BIND9. Скриптът не може да продължи."
    exit 1
  fi

  # ✅ Рестарт на услугата
  echo "🔄 Рестартиране на BIND9..."
  sudo systemctl restart bind9
  if ! systemctl is-active --quiet bind9; then
    echo "❌ Услугата BIND9 не стартира след промени. Скриптът не може да продължи."
    exit 1
  fi

  # ✅ Запис на резултат за Модул 3
  if sudo grep -q '^DNS_RESULT_MODULE3=' "$SETUP_ENV_FILE" 2>/dev/null; then
    sudo sed -i 's|^DNS_RESULT_MODULE3=.*|DNS_RESULT_MODULE3=✅|' "$SETUP_ENV_FILE"
  else
    echo "DNS_RESULT_MODULE3=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
  fi

  echo "✅ Модул 3 завърши успешно: конфигурацията на named.conf.options е обновена."
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

# ✅ Запис на резултат за Модул 4
if sudo grep -q '^DNS_RESULT_MODULE4=' "$SETUP_ENV_FILE" 2>/dev/null; then
  sudo sed -i 's|^DNS_RESULT_MODULE4=.*|DNS_RESULT_MODULE4=✅|' "$SETUP_ENV_FILE"
else
  echo "DNS_RESULT_MODULE4=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
fi

echo "✅ Модул 4 завърши успешно: ролята на DNS сървъра е $DNS_ROLE."
echo ""
echo ""


# === [МОДУЛ 4] ОПРЕДЕЛЯНЕ НА РОЛЯТА НА DNS СЪРВЪРА =========================
echo "[4] ОПРЕДЕЛЯНЕ НА РОЛЯТА НА DNS СЪРВЪРА..."
echo "-----------------------------------------------------------"
echo ""

# СЕКЦИЯ 1: Проверка дали модулът вече е изпълнен
if sudo grep -q '^DNS_RESULT_MODULE4=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 4 вече е изпълнен успешно. Пропускане..."
else
  # ✅ Проверка дали Модул 3 е завършен
  if ! sudo grep -q '^DNS_RESULT_MODULE3=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
    echo "❌ Не може да продължи: Модул 3 не е изпълнен успешно."
    exit 1
  fi

  # ✅ Четене на данни от todo.modules
  if [[ -f "$MODULES_FILE" ]]; then
    SERVER_FQDN=$(grep '^SERVER_FQDN=' "$MODULES_FILE" | cut -d '"' -f2)
  else
    echo "❌ Липсва файлът $MODULES_FILE. Скриптът не може да продължи."
    exit 1
  fi

  # 🔍 Проверка дали имаме валиден FQDN
  if [[ -z "$SERVER_FQDN" ]]; then
    echo "❌ Не е намерен SERVER_FQDN в $MODULES_FILE. Скриптът не може да продължи."
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
    echo "Сървърът не е валиден DNS (ns1/ns2/ns3)."
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
    exit 1
  fi

  # ✅ Рестарт на услугата
  echo "🔄 Рестартиране на BIND9..."
  sudo systemctl restart bind9
  if ! systemctl is-active --quiet bind9; then
    echo "❌ Услугата BIND9 не стартира след промени. Скриптът не може да продължи."
    exit 1
  fi

  # ✅ Запис на резултат за Модул 4
  if sudo grep -q '^DNS_RESULT_MODULE4=' "$SETUP_ENV_FILE" 2>/dev/null; then
    sudo sed -i 's|^DNS_RESULT_MODULE4=.*|DNS_RESULT_MODULE4=✅|' "$SETUP_ENV_FILE"
  else
    echo "DNS_RESULT_MODULE4=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
  fi

  echo "✅ Модул 4 завърши успешно: ролята на DNS сървъра е $DNS_ROLE."
fi
echo ""
echo ""


# === [МОДУЛ 5] СЪЗДАВАНЕ НА ЗОНИ =========================
echo "[5] СЪЗДАВАНЕ НА ЗОНИ..."
echo "-----------------------------------------------------------"
echo ""

# СЕКЦИЯ 1: Проверка дали модулът вече е изпълнен
if sudo grep -q '^DNS_RESULT_MODULE5=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 5 вече е изпълнен успешно. Пропускане..."
else
  # ✅ Проверка дали Модул 4 е завършен
  if ! sudo grep -q '^DNS_RESULT_MODULE4=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
    echo "❌ Не може да продължи: Модул 4 не е изпълнен успешно."
    exit 1
  fi

  # ✅ Четене на данни от todo.modules
  if [[ -f "$MODULES_FILE" ]]; then
    SERVER_FQDN=$(grep '^SERVER_FQDN=' "$MODULES_FILE" | cut -d '"' -f2)
    SERVER_IP=$(grep '^SERVER_IP=' "$MODULES_FILE" | cut -d '"' -f2)
    DNS_ROLE=$(grep '^DNS_ROLE=' "$MODULES_FILE" | cut -d '"' -f2)
  else
    echo "❌ Липсва файлът $MODULES_FILE. Скриптът не може да продължи."
    exit 1
  fi

  # 🔍 Проверка на DNS_ROLE
  if [[ -z "$DNS_ROLE" ]]; then
    echo "❌ Липсва DNS_ROLE в $MODULES_FILE. Скриптът не може да продължи."
    exit 1
  fi

  # ✅ Подготовка на named.conf.local
  if [[ ! -f /etc/bind/named.conf.local ]]; then
    echo "// Локални DNS зони" | sudo tee /etc/bind/named.conf.local > /dev/null
  fi

  # ✅ Папка за зонови файлове (само за PRIMARY)
  if [[ "$DNS_ROLE" == "primary" ]]; then
    if [[ ! -d /etc/bind/zones ]]; then
      sudo mkdir /etc/bind/zones
    fi
  fi

  # ✅ Конфигуриране според ролята
  if [[ "$DNS_ROLE" == "primary" ]]; then
    echo "🔧 Конфигуриране на PRIMARY DNS (ns1)..."

    DOMAIN=$(echo "$SERVER_FQDN" | cut -d '.' -f2-)
    ZONE_FILE="/etc/bind/zones/db.$DOMAIN"
    REVERSE_ZONE_FILE="/etc/bind/zones/db.$(echo "$SERVER_IP" | awk -F. '{print $3"."$2"."$1}.in-addr.arpa')"

    # Добавяне на зони в named.conf.local (ако липсват)
    if ! grep -q "$DOMAIN" /etc/bind/named.conf.local; then
      cat <<EOF | sudo tee -a /etc/bind/named.conf.local > /dev/null

zone "$DOMAIN" {
    type master;
    file "$ZONE_FILE";
};

zone "$(echo "$SERVER_IP" | awk -F. '{print $3"."$2"."$1}.in-addr.arpa')" {
    type master;
    file "$REVERSE_ZONE_FILE";
};
EOF
    fi

    # Създаване на forward зона
    cat <<EOF | sudo tee "$ZONE_FILE" > /dev/null
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN. admin.$DOMAIN. (
                        $(date +%Y%m%d%H) ; Serial
                        604800     ; Refresh
                        86400      ; Retry
                        2419200    ; Expire
                        604800 )   ; Negative Cache TTL
;
@       IN      NS      ns1.$DOMAIN.
@       IN      NS      ns2.$DOMAIN.

ns1     IN      A       $SERVER_IP
EOF

    # (Ако има втори DNS – ще се добави по-късно от контролен панел или автоматизация)

  elif [[ "$DNS_ROLE" == "secondary" ]]; then
    echo "🔧 Конфигуриране на SECONDARY DNS (slave)..."

    DOMAIN=$(echo "$SERVER_FQDN" | cut -d '.' -f2-)
    MASTER_IP="" # ще се изиска в бъдеща версия или от todo.modules

    if [[ -z "$MASTER_IP" ]]; then
      echo "❌ Липсва IP на PRIMARY DNS. Добавете го в todo.modules (MASTER_IP)."
      exit 1
    fi

    if ! grep -q "$DOMAIN" /etc/bind/named.conf.local; then
      cat <<EOF | sudo tee -a /etc/bind/named.conf.local > /dev/null

zone "$DOMAIN" {
    type slave;
    masters { $MASTER_IP; };
    file "/var/cache/bind/db.$DOMAIN";
};
EOF
    fi
  else
    echo "❌ Непозната роля: $DNS_ROLE"
    exit 1
  fi

  # ✅ Проверка на синтаксиса
  echo "🔍 Проверка на синтаксиса..."
  if ! sudo named-checkconf; then
    echo "❌ Грешка в конфигурацията на BIND9. Скриптът не може да продължи."
    exit 1
  fi

  # ✅ Рестарт на услугата
  echo "🔄 Рестартиране на BIND9..."
  sudo systemctl restart bind9
  if ! systemctl is-active --quiet bind9; then
    echo "❌ Услугата BIND9 не стартира след промени."
    exit 1
  fi

  # ✅ Запис на резултат за Модул 5
  if sudo grep -q '^DNS_RESULT_MODULE5=' "$SETUP_ENV_FILE" 2>/dev/null; then
    sudo sed -i 's|^DNS_RESULT_MODULE5=.*|DNS_RESULT_MODULE5=✅|' "$SETUP_ENV_FILE"
  else
    echo "DNS_RESULT_MODULE5=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
  fi

  echo "✅ Модул 5 завърши успешно: зоните са конфигурирани."
fi
echo ""
echo ""


# === [ФИНАЛЕН ОТЧЕТ] =======================================================
echo ""
echo -e "\e[32m=========================================="
echo -e "         ОТЧЕТ ЗА КОНФИГУРАЦИЯТА"
echo -e "==========================================\e[0m"
echo ""

# Четене на резултати
MODULE1_STATUS=$(grep '^DNS_RESULT_MODULE1=' "$SETUP_ENV_FILE" | cut -d '=' -f2)
MODULE2_STATUS=$(grep '^DNS_RESULT_MODULE2=' "$SETUP_ENV_FILE" | cut -d '=' -f2)
MODULE3_STATUS=$(grep '^DNS_RESULT_MODULE3=' "$SETUP_ENV_FILE" | cut -d '=' -f2)
MODULE4_STATUS=$(grep '^DNS_RESULT_MODULE4=' "$SETUP_ENV_FILE" | cut -d '=' -f2)
MODULE5_STATUS=$(grep '^DNS_RESULT_MODULE5=' "$SETUP_ENV_FILE" | cut -d '=' -f2)

echo "📌 Модул 1 – Предварителни проверки:    ${MODULE1_STATUS:-❌}"
echo "📌 Модул 2 – Инсталиране на BIND9:      ${MODULE2_STATUS:-❌}"
echo "📌 Модул 3 – Конфигурация options:      ${MODULE3_STATUS:-❌}"
echo "📌 Модул 4 – Определяне на роля:        ${MODULE4_STATUS:-❌}"
echo "📌 Модул 5 – Създаване на зони:         ${MODULE5_STATUS:-❌}"
echo ""
echo "------------------------------------------------------------------"
echo ""

# ✅ Потвърждение от оператора
read -p "✅ Приемате ли конфигурацията като успешна? (y/n): " confirm
if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
  # ✅ Запис на финален статус
  if sudo grep -q '^SETUP_VPS_DNS_STATUS=' "$SETUP_ENV_FILE" 2>/dev/null; then
    sudo sed -i 's|^SETUP_VPS_DNS_STATUS=.*|SETUP_VPS_DNS_STATUS=✅|' "$SETUP_ENV_FILE"
  else
    echo "SETUP_VPS_DNS_STATUS=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
  fi

  # ✅ Изтриване на todo.modules
  if [[ -f "$MODULES_FILE" ]]; then
    sudo rm -f "$MODULES_FILE"
    echo "🗑️ Файлът $MODULES_FILE беше изтрит."
  fi

  # ✅ Изтриване на скрипта
  echo "🗑️ Скриптът ще се премахне."
  [[ -f "$0" ]] && rm -- "$0"

  echo "🎯 Конфигурацията на DNS сървъра е завършена успешно."
else
  echo "ℹ️ Конфигурацията не е маркирана като успешна. Нищо не е изтрито."
fi
