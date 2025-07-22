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
# СЕКЦИЯ 1: Проверка за базова конфигурация и състояние на DNS
# -------------------------------------------------------------------------------------

# Проверка за базова конфигурация
if [[ ! -f "$SETUP_ENV_FILE" ]] || ! sudo grep -q '^SETUP_VPS_BASE_STATUS=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "🛑 Сървърът е с нестандартна начална конфигурация. Моля, стартирайте файла vps-base-qsetup.sh и опитайте отново."
  echo "🗑️ Премахване на скрипта."
  [[ -f "$0" ]] && rm -- "$0"
  exit 1
fi

# Проверка дали DNS конфигурацията вече е завършена
if sudo grep -q '^SETUP_VPS_DNS_STATUS=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "🛑 Скриптът за конфигуриране на DNS сървър вече е изпълнен. Повторното изпълнение може да срине сървърната система."
  echo "🗑️ Премахване на скрипта."
  [[ -f "$0" ]] && rm -- "$0"
  exit 0
fi

# Проверка дали Модул 1 е изпълнен
if sudo grep -q '^DNS_RESULT_MODULE1=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 1 вече е изпълнен успешно. Пропускане..."
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
    echo "❌ Операционната система $PRETTY_NAME не се поддържа от този скрипт."
    echo "Поддържани системи: Ubuntu 22.04/24.04, Debian 11/12"
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
  echo ""

while true; do
  printf "🌐 Въведете IP адреса на другия DNS сървър (или 'q' за изход): "
  read SECOND_DNS_IP

  if [[ "$SECOND_DNS_IP" == "q" || "$SECOND_DNS_IP" == "Q" ]]; then
    echo "❎ Скриптът беше прекратен от потребителя."
    exit 0
  fi

  if [[ -z "$SECOND_DNS_IP" ]]; then
    echo "❌ Задължително е да въведете IP на другия DNS сървър."
    continue
  fi

  if [[ "$SECOND_DNS_IP" == "$SERVER_IP" ]]; then
    echo "❌ Невалидно: IP адресът на втория DNS не може да съвпада с текущия сървър. Опитайте отново."
    continue
  fi

  if [[ "$SECOND_DNS_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "✅ Въведен IP на друг DNS: $SECOND_DNS_IP"
    break
  else
    echo "❌ Невалиден IP адрес. Опитайте отново."
  fi
done
echo ""
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

  if [[ ! "$HOSTNAME_FQDN" =~ ^ns[1-3]\..+\..+$ ]]; then
    echo "🚫 Несъвместим или недопустим домейн: $HOSTNAME_FQDN"
    echo "ℹ️ Този скрипт е за DNS сървъри на NetGalaxy."
    exit 1
  fi

  echo "✅ Потвърдено: hostname = $HOSTNAME_FQDN"
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 5: Създаване на todo.modules и запис на IP/FQDN
  # -------------------------------------------------------------------------------------
  if [[ ! -f "$MODULES_FILE" ]]; then
    sudo touch "$MODULES_FILE"
  fi

  # SERVER_IP
  if [[ -n "$SERVER_IP" ]]; then
    if sudo grep -q '^SERVER_IP=' "$MODULES_FILE" 2>/dev/null; then
      sudo sed -i "s|^SERVER_IP=.*|SERVER_IP=\"$SERVER_IP\"|" "$MODULES_FILE"
    else
      echo "SERVER_IP=\"$SERVER_IP\"" | sudo tee -a "$MODULES_FILE" > /dev/null
    fi
  else
    echo "❌ Променливата SERVER_IP е празна. Скриптът не може да продължи."
    exit 1
  fi

  # SERVER_FQDN
  if [[ -n "$HOSTNAME_FQDN" ]]; then
    if sudo grep -q '^SERVER_FQDN=' "$MODULES_FILE" 2>/dev/null; then
      sudo sed -i "s|^SERVER_FQDN=.*|SERVER_FQDN=\"$HOSTNAME_FQDN\"|" "$MODULES_FILE"
    else
      echo "SERVER_FQDN=\"$HOSTNAME_FQDN\"" | sudo tee -a "$MODULES_FILE" > /dev/null
    fi
  else
    echo "❌ Променливата HOSTNAME_FQDN е празна. Скриптът не може да продължи."
    exit 1
  fi

  # SECOND_DNS_IP
  if sudo grep -q '^SECOND_DNS_IP=' "$MODULES_FILE" 2>/dev/null; then
    sudo sed -i "s|^SECOND_DNS_IP=.*|SECOND_DNS_IP=\"$SECOND_DNS_IP\"|" "$MODULES_FILE"
  else
    echo "SECOND_DNS_IP=\"$SECOND_DNS_IP\"" | sudo tee -a "$MODULES_FILE" > /dev/null
  fi

  # ✅ Запис на резултат
  if sudo grep -q '^DNS_RESULT_MODULE1=' "$SETUP_ENV_FILE" 2>/dev/null; then
    sudo sed -i 's|^DNS_RESULT_MODULE1=.*|DNS_RESULT_MODULE1=✅|' "$SETUP_ENV_FILE"
  else
    echo "DNS_RESULT_MODULE1=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
  fi

  echo "✅ Модул 1 завърши успешно."

fi   # <-- Затваря основния IF за проверка на изпълнение на модула
echo ""
echo ""


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


# === [МОДУЛ 3] КОНФИГУРИРАНЕ НА named.conf.options =========================
echo "[3] КОНФИГУРИРАНЕ НА named.conf.options..."
echo "-----------------------------------------------------------"
echo ""

# ✅ Проверка дали модулът вече е изпълнен
if sudo grep -q '^DNS_RESULT_MODULE3=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 3 вече е изпълнен успешно. Пропускане..."
else

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 1: Четене на данни
  # -------------------------------------------------------------------------------------
  if [[ -f "$MODULES_FILE" ]]; then
    SERVER_IP=$(grep '^SERVER_IP=' "$MODULES_FILE" | awk -F'=' '{print $2}' | tr -d '"')
    IPV6_ENABLED=$(grep '^IPV6_ENABLED=' "$MODULES_FILE" | awk -F'=' '{print $2}' | tr -d '"')
  else
    echo "❌ Липсва файлът $MODULES_FILE. Скриптът не може да продължи."
    exit 1
  fi

  if [[ -z "$SERVER_IP" ]]; then
    echo "❌ Липсва SERVER_IP в $MODULES_FILE."
    exit 1
  fi

  echo "✅ Използван IPv4 адрес: $SERVER_IP"
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 2: Създаване на конфигурация за named.conf.options
  # -------------------------------------------------------------------------------------
  echo "🔧 Създаване на нова конфигурация в named.conf.options..."

  # Определяне на listen-on-v6 според наличието на IPv6
  if [[ "$IPV6_ENABLED" == "yes" ]]; then
    LISTEN_V6="{ any; }"
  else
    LISTEN_V6="{ none; }"
  fi

  cat <<EOF | sudo tee /etc/bind/named.conf.options > /dev/null
options {
    directory "/var/cache/bind";

    listen-on { 127.0.0.1; $SERVER_IP; };
    listen-on-v6 $LISTEN_V6;

    allow-query { any; };

    recursion no;

    forwarders {
        1.1.1.1;
        8.8.8.8;
    };

    dnssec-validation auto;
};
EOF

  echo "✅ named.conf.options е обновен."
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 3: Проверка на синтаксиса
  # -------------------------------------------------------------------------------------
  echo "🔍 Проверка на синтаксиса..."
  if ! sudo named-checkconf; then
    echo "❌ Грешка в конфигурацията на named.conf.options."
    exit 1
  fi
  echo "✅ Синтаксисът е валиден."
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 4: Отваряне на порт 53 в UFW
  # -------------------------------------------------------------------------------------
  echo "🔓 Отваряне на порт 53 (TCP/UDP) за DNS..."
  sudo ufw allow 53/tcp > /dev/null
  sudo ufw allow 53/udp > /dev/null
  echo "✅ Порт 53 е отворен."
  echo ""

  # -------------------------------------------------------------------------------------
  # СЕКЦИЯ 5: Рестарт на услугата
  # -------------------------------------------------------------------------------------
  echo "🔄 Рестартиране на BIND9..."
  sudo systemctl restart bind9
  if ! systemctl is-active --quiet bind9; then
    echo "❌ Услугата BIND9 не стартира след промени."
    exit 1
  fi
  echo "✅ Услугата BIND9 работи."
  echo ""

  # ✅ Запис на резултат за Модул 3
  if sudo grep -q '^DNS_RESULT_MODULE3=' "$SETUP_ENV_FILE" 2>/dev/null; then
    sudo sed -i 's|^DNS_RESULT_MODULE3=.*|DNS_RESULT_MODULE3=✅|' "$SETUP_ENV_FILE"
  else
    echo "DNS_RESULT_MODULE3=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
  fi

  echo "✅ Модул 3 завърши успешно."
fi
echo ""
echo ""


# === [МОДУЛ 4] ОПРЕДЕЛЯНЕ НА РОЛЯТА НА DNS СЪРВЪРА =========================
echo "[4] ОПРЕДЕЛЯНЕ НА РОЛЯТА НА DNS СЪРВЪРА..."
echo "-----------------------------------------------------------"
echo ""

# 🔍 Проверка дали модулът вече е изпълнен
if sudo grep -q '^DNS_RESULT_MODULE4=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 4 вече е изпълнен успешно. Пропускане..."
  echo ""
else
  # Тук започва реалната логика на модула
  # ✅ Четене на данни от todo.modules
  if [[ -f "$MODULES_FILE" ]]; then
    SERVER_FQDN=$(grep '^SERVER_FQDN=' "$MODULES_FILE" | awk -F'=' '{print $2}' | tr -d '"')
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
    echo "Скриптът не може да продължи, защото този сървър не е валиден DNS (ns1/ns2/ns3)."
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
  echo ""
fi
echo ""
echo ""


# === [МОДУЛ 5] СЪЗДАВАНЕ НА ЗОНИ =========================
echo "[5] СЪЗДАВАНЕ НА ЗОНИ..."
echo "-----------------------------------------------------------"
echo ""

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 1: Проверка дали модулът вече е изпълнен
# -------------------------------------------------------------------------------------
if sudo grep -q '^DNS_RESULT_MODULE5=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 5 вече е изпълнен успешно. Пропускане..."
  return 0 2>/dev/null || exit 0
fi

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 2: Проверка на предходния модул и зареждане на данни
# -------------------------------------------------------------------------------------
if ! sudo grep -q '^DNS_RESULT_MODULE4=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "❌ Не може да продължи: Модул 4 не е изпълнен успешно."
  exit 1
fi

if [[ -f "$MODULES_FILE" ]]; then
  SERVER_FQDN=$(grep '^SERVER_FQDN=' "$MODULES_FILE" | awk -F'=' '{print $2}' | tr -d '"')
  SERVER_IP=$(grep '^SERVER_IP=' "$MODULES_FILE" | awk -F'=' '{print $2}' | tr -d '"')
  DNS_ROLE=$(grep '^DNS_ROLE=' "$MODULES_FILE" | awk -F'=' '{print $2}' | tr -d '"')
  SECOND_DNS_IP=$(grep '^SECOND_DNS_IP=' "$MODULES_FILE" | awk -F'=' '{print $2}' | tr -d '"')
else
  echo "❌ Липсва файлът $MODULES_FILE. Скриптът не може да продължи."
  exit 1
fi

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 3: Проверка на данните
# -------------------------------------------------------------------------------------
if [[ -z "$SERVER_FQDN" || -z "$SERVER_IP" || -z "$DNS_ROLE" ]]; then
  echo "❌ Липсват критични данни (FQDN, IP или роля). Проверете $MODULES_FILE."
  exit 1
fi

DOMAIN=$(echo "$SERVER_FQDN" | cut -d '.' -f2-)
if [[ -z "$DOMAIN" ]]; then
  echo "❌ Невалиден домейн. Проверете SERVER_FQDN в $MODULES_FILE."
  exit 1
fi

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 4: Подготовка на конфигурационните файлове
# -------------------------------------------------------------------------------------
REVERSE_ZONE_NAME=$(echo "$SERVER_IP" | awk -F. '{print $3"."$2"."$1}')
ZONE_FILE="/etc/bind/zones/db.$DOMAIN"
REVERSE_ZONE_FILE="/etc/bind/zones/db.$REVERSE_ZONE_NAME.in-addr.arpa"

if [[ ! -f /etc/bind/named.conf.local ]]; then
  echo "// Локални DNS зони" | sudo tee /etc/bind/named.conf.local > /dev/null
fi

if [[ "$DNS_ROLE" == "primary" && ! -d /etc/bind/zones ]]; then
  sudo mkdir /etc/bind/zones
fi

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 5: Конфигуриране според ролята
# -------------------------------------------------------------------------------------
if [[ "$DNS_ROLE" == "primary" ]]; then
  echo "🔧 Конфигуриране на PRIMARY DNS (ns1)..."

  # Добавяне на зони в named.conf.local (без allow-transfer и also-notify на този етап)
  if ! grep -q "$DOMAIN" /etc/bind/named.conf.local; then
    cat <<EOF | sudo tee -a /etc/bind/named.conf.local > /dev/null

zone "$DOMAIN" {
    type master;
    file "$ZONE_FILE";
};
zone "$REVERSE_ZONE_NAME.in-addr.arpa" {
    type master;
    file "$REVERSE_ZONE_FILE";
};
EOF
  fi

  # ✅ Добавяне на allow-transfer и also-notify (само ако SECOND_DNS_IP е зададен)
  if [[ -n "$SECOND_DNS_IP" ]]; then
    for ZONE in "$DOMAIN" "$REVERSE_ZONE_NAME.in-addr.arpa"; do
      if grep -q "zone \"$ZONE\"" /etc/bind/named.conf.local; then
        # Премахваме стари директиви, ако има
        sudo sed -i "/zone \"$ZONE\" {/,/}/ {
          /allow-transfer/d
          /also-notify/d
        }" /etc/bind/named.conf.local

        # Инжектираме новите редове преди затварящата скоба
        sudo sed -i "/zone \"$ZONE\" {/,/}/ {
          /^};/i\    allow-transfer { $SECOND_DNS_IP; };
          /^};/i\    also-notify { $SECOND_DNS_IP; };
        }" /etc/bind/named.conf.local

        echo "✅ Обновени allow-transfer и also-notify за $ZONE"
      fi
    done
  fi

  # ✅ Създаване на forward зона
  {
    echo "\$TTL    604800"
    echo "@       IN      SOA     ns1.$DOMAIN. admin.$DOMAIN. ("
    echo "                        $(date +%Y%m%d%H) ; Serial"
    echo "                        604800     ; Refresh"
    echo "                        86400      ; Retry"
    echo "                        2419200    ; Expire"
    echo "                        604800 )   ; Negative Cache TTL"
    echo ";"
    echo "@       IN      NS      ns1.$DOMAIN."
    echo "@       IN      A       $SERVER_IP"
    echo "ns1     IN      A       $SERVER_IP"
    if [[ -n "$SECOND_DNS_IP" ]]; then
      echo "@       IN      NS      ns2.$DOMAIN."
      echo "ns2     IN      A       $SECOND_DNS_IP"
    fi
  } | sudo tee "$ZONE_FILE" > /dev/null

  # ✅ Създаване на reverse зона
  LAST_OCTET=$(echo "$SERVER_IP" | awk -F. '{print $4}')
  cat <<EOF | sudo tee "$REVERSE_ZONE_FILE" > /dev/null
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN. admin.$DOMAIN. (
                        $(date +%Y%m%d%H) ; Serial
                        604800     ; Refresh
                        86400      ; Retry
                        2419200    ; Expire
                        604800 )   ; Negative Cache TTL
;
@       IN      NS      ns1.$DOMAIN.
$LAST_OCTET    IN      PTR     ns1.$DOMAIN.
EOF

elif [[ "$DNS_ROLE" == "secondary" ]]; then
  echo "🔧 Конфигуриране на SECONDARY DNS..."
  MASTER_IP=$(grep '^SECOND_DNS_IP=' "$MODULES_FILE" | awk -F'=' '{print $2}' | tr -d '"')
  if [[ -z "$MASTER_IP" ]]; then
    echo "❌ Липсва IP на PRIMARY DNS (MASTER_IP). Проверете $MODULES_FILE."
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
  else
    # Поправяме master IP, ако е различен
    sudo sed -i "/zone \"$DOMAIN\" {/,/}/ {
      /masters/d
    }" /etc/bind/named.conf.local
    sudo sed -i "/zone \"$DOMAIN\" {/,/}/ {
      /^};/i\    masters { $MASTER_IP; };
    }" /etc/bind/named.conf.local
    echo "✅ Обновен MASTER IP за $DOMAIN"
  fi

else
  echo "❌ Непозната роля: $DNS_ROLE"
  exit 1
fi

# ✅ Уверяваме се, че /var/cache/bind/ има правилните права
if [[ -d "/var/cache/bind" ]]; then
    sudo chown bind:bind /var/cache/bind
    sudo chmod 750 /var/cache/bind
    echo "✅ Дадени са правилни права на /var/cache/bind/"
fi

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 6: Проверка на синтаксиса и рестарт
# -------------------------------------------------------------------------------------
echo "🔍 Проверка на синтаксиса на конфигурацията..."
if ! sudo named-checkconf; then
  echo "❌ Грешка в конфигурацията на BIND9."
  exit 1
fi
echo "✅ Конфигурацията е валидна."

echo "➡️ [DEBUG] Стартиране на рестарт на BIND9..."
if sudo systemctl restart bind9; then
  echo "✅ Рестартът на BIND9 беше изпълнен успешно."
else
  echo "❌ Грешка при опит за рестарт на BIND9!"
  exit 1
fi

# Малка пауза, за да дадем време на BIND да зареди зоните
sleep 2

echo "➡️ [DEBUG] Проверка дали BIND9 е активен..."
if ! sudo systemctl is-active --quiet bind9; then
  echo "❌ Услугата BIND9 не е активна след рестарт!"
  exit 1
else
  echo "✅ Услугата BIND9 е активна и работи."
fi

# ✅ Допълнителна проверка: показваме броя на заредените зони за debug
ZONE_COUNT=$(sudo rndc status | grep "number of zones" || echo "неизвестно")
echo "➡️ [DEBUG] $ZONE_COUNT"

# ✅ Запис на резултат за Модул 5
if sudo grep -q '^DNS_RESULT_MODULE5=' "$SETUP_ENV_FILE" 2>/dev/null; then
  sudo sed -i 's|^DNS_RESULT_MODULE5=.*|DNS_RESULT_MODULE5=✅|' "$SETUP_ENV_FILE"
else
  echo "DNS_RESULT_MODULE5=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
fi

echo "✅ Модул 5 завърши успешно: зоните са конфигурирани и BIND9 е рестартиран."
echo ""

# -------------------------------------------------------------------------------------
# СЕКЦИЯ 7: Финален запис
# -------------------------------------------------------------------------------------
if sudo grep -q '^DNS_RESULT_MODULE5=' "$SETUP_ENV_FILE" 2>/dev/null; then
  sudo sed -i 's|^DNS_RESULT_MODULE5=.*|DNS_RESULT_MODULE5=✅|' "$SETUP_ENV_FILE"
else
  echo "DNS_RESULT_MODULE5=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
fi

echo "✅ Модул 5 завърши успешно: зоните са конфигурирани."
echo ""
echo ""


# === [МОДУЛ 6] ФИНАЛЕН ОТЧЕТ =========================
echo "[6] ФИНАЛЕН ОТЧЕТ..."
echo "-----------------------------------------------------------"
echo ""

echo -e "\e[32m=========================================="
echo -e "         ОТЧЕТ ЗА КОНФИГУРАЦИЯТА"
echo -e "==========================================\e[0m"
echo ""

# ✅ Четене на резултати (с sudo)
MODULE1_STATUS=$(sudo grep '^DNS_RESULT_MODULE1=' "$SETUP_ENV_FILE" 2>/dev/null | cut -d '=' -f2)
MODULE2_STATUS=$(sudo grep '^DNS_RESULT_MODULE2=' "$SETUP_ENV_FILE" 2>/dev/null | cut -d '=' -f2)
MODULE3_STATUS=$(sudo grep '^DNS_RESULT_MODULE3=' "$SETUP_ENV_FILE" 2>/dev/null | cut -d '=' -f2)
MODULE4_STATUS=$(sudo grep '^DNS_RESULT_MODULE4=' "$SETUP_ENV_FILE" 2>/dev/null | cut -d '=' -f2)
MODULE5_STATUS=$(sudo grep '^DNS_RESULT_MODULE5=' "$SETUP_ENV_FILE" 2>/dev/null | cut -d '=' -f2)

echo "📌 Модул 1 – Предварителни проверки:    ${MODULE1_STATUS:-❌}"
echo "📌 Модул 2 – Инсталиране на BIND9:      ${MODULE2_STATUS:-❌}"
echo "📌 Модул 3 – Конфигурация options:      ${MODULE3_STATUS:-❌}"
echo "📌 Модул 4 – Определяне на роля:        ${MODULE4_STATUS:-❌}"
echo "📌 Модул 5 – Създаване на зони:         ${MODULE5_STATUS:-❌}"
echo ""
echo "------------------------------------------------------------------"
echo ""

# -------------------------------------------------------------------------------------
# ✅ Автоматична проверка на DNS състоянието
# -------------------------------------------------------------------------------------
echo "🔍 Автоматична проверка на DNS състоянието..."
echo ""

# 1. Проверка дали BIND9 е активен
if systemctl is-active --quiet bind9; then
    echo "✅ BIND9 работи."
else
    echo "❌ BIND9 не е активен!"
fi

# 2. Проверка на зоната при SLAVE чрез rndc zonestatus
if [[ "$DNS_ROLE" == "secondary" ]]; then
    echo "🔍 Проверка на статус на зоната $DOMAIN..."
    ZONE_STATUS=$(sudo rndc zonestatus "$DOMAIN" 2>/dev/null | grep "loaded serial")
    if [[ -n "$ZONE_STATUS" ]]; then
        echo "✅ Зоната е заредена на SLAVE: $ZONE_STATUS"
    else
        echo "⚠️ Зоната не е заредена на SLAVE или rndc няма информация."
        echo "ℹ️ Може да проверите логовете или да изпълните ръчно:"
        echo "   sudo rndc retransfer $DOMAIN"
    fi
fi

# 3. Бърз dig тест за отговор на локална заявка
if dig @127.0.0.1 "$DOMAIN" +short >/dev/null 2>&1; then
    echo "✅ DNS отговаря на локални заявки за $DOMAIN."
else
    echo "❌ DNS не отговаря на локални заявки за $DOMAIN."
fi
echo ""
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
