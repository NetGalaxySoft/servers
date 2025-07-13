#!/bin/bash

# ========================================================================== 
#  vps-host-qsetup - Надстройка за хостинг сървър (bind9, apache, mariadb)
# --------------------------------------------------------------------------
#  Версия: 1.0
#  Дата: 2025-06-30
#  Автор: Ilko Yordanov / NetGalaxy
# ==========================================================================
#
#  Този скрипт извършва надграждаща конфигурация на вече подготвен VPS
#  сървър. Той добавя услуги за хостинг и управление на домейни.
#
#  Етапи:
#    1. Събиране на цялата информация
#    2. Потвърждение от оператора
#    3. Инсталация и конфигурация на услугите
#    4. Финален отчет на резултатите
# ==========================================================================

# === ПОМОЩНА ИНФОРМАЦИЯ ===================================================
show_help() {
  echo "Използване: vps-host-qsetup.sh [опция]"
  echo ""
  echo "Надграждаща конфигурация за хостинг сървър (Apache, bind9, MariaDB)."
  echo ""
  echo "Опции:"
  echo "  --version       Показва версията на скрипта"
  echo "  --help          Показва тази помощ"
}

# === ОБРАБОТКА НА ОПЦИИ ====================================================
if [[ $# -gt 0 ]]; then
  case "$1" in
    --version)
      echo "vps-host-qsetup версия 1.0 (30 юни 2025 г.)"
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

# === ПОКАЗВАНЕ НА ЗАГЛАВИЕТО ===============================================
echo ""
echo ""
echo -e "\e[32m=========================================="
echo -e "  НАДСТРОЙКА ЗА ХОСТИНГ СЪРВЪР (VPS)"
echo -e "==========================================\e[0m"
echo ""

# === ГЛОБАЛНИ ПРОМЕНЛИВИ НА ХОСТИНГ СКРИПТА ==================================

SERVER_IP=""                        # ➤ IP адрес, въведен от оператора (очакваният IP на този сървър)
ACTUAL_IP="$(curl -s ifconfig.me)"  # ➤ Реален външен IP адрес на сървъра (извлечен автоматично)

SERVER_DOMAIN=""                    # ➤ FQDN домейн, въведен от оператора (напр. example.com)
ACTUAL_DOMAIN="$(hostname -f)"      # ➤ Реален hostname на сървъра (FQDN, извлечен автоматично)

DNS_REQUIRED=""                     # ➤ "yes" или "no" – дали искаме да инсталираме DNS сървър
DNS_MODE="master"                   # ➤ Тип DNS сървър (master/slave) – по подразбиране: master
DNS_ZONE=""                         # ➤ Зоната, която ще се обслужва от DNS (напр. example.com)
SLAVE_MASTER_IP=""                  # ➤ IP адрес на master DNS сървър (ако режимът е "slave")

CONFIRM=""                          # ➤ Променлива за потвърждение от оператора при важни действия


# === [0] ИНИЦИАЛИЗАЦИЯ НА МАРКЕРНИТЕ ФАЙЛОВЕ НА ПЛАТФОРМАТА ================

NETGALAXY_DIR="/etc/netgalaxy"
MODULES_FILE="$NETGALAXY_DIR/todo.modules"
SETUP_ENV_FILE="$NETGALAXY_DIR/setup.env"

# 🔒 Проверка дали началната конфигурация е била извършена:
if [[ ! -f "$SETUP_ENV_FILE" ]] || ! grep -q '^SETUP_VPS_BASE_STATUS=✅' "$SETUP_ENV_FILE"; then
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
if grep -q '^SETUP_VPS_HOST_STATUS=✅' "$SETUP_ENV_FILE"; then
  echo "🛑 Този скрипт вече е бил изпълнен на този сървър."
  echo "   Повторно изпълнение не се разрешава за предпазване от сбой на системата."

  [[ -f "$0" ]] && rm -- "$0"
  exit 0
fi

# ✅ Ако началната конфигурация е налична, продължаваме с инициализация

# Създаване на директорията, ако не съществува
if [[ ! -d "$NETGALAXY_DIR" ]]; then
  echo "📁 Създаване на директория за NetGalaxy: $NETGALAXY_DIR"
  sudo mkdir -p "$NETGALAXY_DIR"
  sudo chmod 755 "$NETGALAXY_DIR"
  echo "✅ Директорията беше създадена успешно."
fi

# Създаване на файла todo.modules, ако не съществува
if [[ ! -f "$MODULES_FILE" ]]; then
  echo "📝 Създаване на лог файл за изпълнени модули ($MODULES_FILE)..."
  sudo touch "$MODULES_FILE"
  sudo chmod 644 "$MODULES_FILE"
  echo "✅ Файлът todo.modules беше създаден успешно (празен)."
else
  echo "ℹ️ Открит съществуващ файл todo.modules – ще се добавят нови редове при изпълнение на модулите."
fi
echo ""
echo ""


# === [МОДУЛ 1] ПРОВЕРКА НА IP И FQDN НА СЪРВЪРА =============================
echo "[1] ПРОВЕРКА НА IP И FQDN НА СЪРВЪРА..."
echo "-----------------------------------------------------------"
echo ""
MODULE_NAME="host_01_ip_check"
MODULES_FILE="/etc/netgalaxy/todo.modules"
SETUP_ENV_FILE="/etc/netgalaxy/setup.env"

# 🔁 Проверка дали модулът вече е бил изпълнен
if grep -q "^$MODULE_NAME\b" "$MODULES_FILE"; then
  echo "🔁 Пропускане на $MODULE_NAME (вече е отбелязан като изпълнен)..."
  echo ""
else {

# 🌐 Проверка на домейн името (FQDN)
  while true; do
    printf "🌍 Въведете FQDN (пълното домейн име) на сървъра (или 'q' за изход): "
    read SERVER_DOMAIN

    if [[ "$SERVER_DOMAIN" == "q" || "$SERVER_DOMAIN" == "Q" ]]; then
      echo "⛔ Скриптът беше прекратен от потребителя след $MODULE_NAME."
      [[ -f "$0" ]] && rm -- "$0"
      exit 0
    fi

    if ! [[ "$SERVER_DOMAIN" =~ ^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)+([A-Za-z]{2,})$ ]]; then
      echo "❌ Невалиден FQDN. Моля, въведете валидно пълно домейн име (напр. host.example.com)."
      continue
    fi

    # 🧠 Проверка дали домейнът сочи към IP адреса на сървъра
    resolved_ip=$(dig +short "$SERVER_DOMAIN" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

    if [[ "$resolved_ip" != "$ACTUAL_IP" ]]; then
      echo ""
      echo "🚫 Домейнът $SERVER_DOMAIN не сочи към този сървър."
      echo "⚠️ Очакван IP: $ACTUAL_IP"
      echo "🔍 Открит IP:  ${resolved_ip:-(няма IP)}"
      echo ""
      read -p "🔁 Искате ли да опитате отново? [Enter за ДА, 'q' за изход]: " retry
      if [[ "$retry" == "q" || "$retry" == "Q" ]]; then
        echo "⛔ Скриптът беше прекратен от потребителя след $MODULE_NAME."
        [[ -f "$0" ]] && rm -- "$0"
        exit 0
      fi
      echo ""
    else
      echo "✅ Потвърдено: домейнът $SERVER_DOMAIN сочи към този сървър ($ACTUAL_IP)."
      break
    fi
  done
echo ""
echo ""





exit 0







# === [2a] ВЪПРОС ЗА DNS РЕЖИМ (само ако има нужда) ============================
if [[ "$DNS_REQUIRED" == "yes" ]]; then
  while true; do
    echo "➤ Изберете режим за DNS сървъра:"
    echo "    1: master"
    echo "    2: slave"
    echo "    q: изход"
    read -rp "Вашият избор: " DNS_MODE
    case "$DNS_MODE" in
      1)
        DNS_MODE="master"
        DNS_ZONE=$(echo "$SERVER_DOMAIN" | cut -d. -f2-)
        echo "ℹ️ Използва се основна зона: $DNS_ZONE"
        SLAVE_MASTER_IP=""

        # Проверка и автоматична инсталация на 'dnsutils'
        if ! command -v dig >/dev/null 2>&1; then
          echo "ℹ️ Инструментът 'dig' не е наличен. Инсталираме 'dnsutils' за DNS проверка..."
          apt-get update -qq && apt-get install -y dnsutils >/dev/null
          RESULT_DNSUTILS="✅"
        else
          RESULT_DNSUTILS="✅"
        fi

        EXPECTED_IP=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        echo "🔍 Проверка дали ns1 и ns2 за $DNS_ZONE сочат към този сървър ($EXPECTED_IP)..."
        NS1_IP=$(dig +short A ns1.$DNS_ZONE)
        NS2_IP=$(dig +short A ns2.$DNS_ZONE)

        if [[ "$NS1_IP" == "$EXPECTED_IP" && "$NS2_IP" == "$EXPECTED_IP" ]]; then
          echo "✅ Потвърдено: ns1 и ns2 сочат към този сървър."
        else
          echo "❌ ns1 и/или ns2 не сочат към този сървър:"
          echo "👉 ns1.$DNS_ZONE → ${NS1_IP:-(няма запис)}"
          echo "👉 ns2.$DNS_ZONE → ${NS2_IP:-(няма запис)}"
          echo ""
          echo "⚠️  Моля, актуализирайте A-записите за ns1 и ns2 да сочат към $EXPECTED_IP."
          echo "🔁 След това стартирайте скрипта отново."
          exit 1
        fi
        break
        ;;
      2)
        DNS_MODE="slave"
        while true; do
          read -rp "➤ Въведете IP адреса на master DNS сървъра (или 'q' за изход): " SLAVE_MASTER_IP
          [[ "$SLAVE_MASTER_IP" == "q" ]] && exit 0
          if [[ $SLAVE_MASTER_IP == "$SERVER_IP" ]]; then
            echo "❌ IP адресът на master сървъра не може да съвпада с текущия сървър."
            continue
          fi
          if [[ $SLAVE_MASTER_IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            echo "ℹ️ Ще се опитаме да проверим достъпа до master сървъра..."
            if timeout 3 bash -c "> /dev/tcp/$SLAVE_MASTER_IP/53" 2>/dev/null; then
              echo "✅ Успешна връзка към порт 53 на master DNS сървъра."
              break
            else
              echo "❌ Няма достъп до порт 53 на $SLAVE_MASTER_IP. Проверете firewall или IP."
            fi
          else
            echo "❌ Невалиден IP адрес. Опитайте отново."
          fi
        done
        break
        ;;
      q|Q)
        exit 0
        ;;
      *)
        echo "❌ Невалиден избор. Моля, въведете 1, 2 или q."
        ;;
    esac
  done
fi

# [3] Финално потвърждение
INSTALLED_SERVICES="Apache2, MariaDB, PHP, Postfix, Dovecot"
echo ""
echo "🔎 Преглед на въведената информация:"
echo "   • Домейн (FQDN):  $SERVER_DOMAIN"
echo "   • IP адрес:       $SERVER_IP"
if [[ "$DNS_REQUIRED" == "yes" ]]; then
  echo "   • DNS сървър:     включен ($DNS_MODE)"
  echo "   • DNS зона:       $DNS_ZONE"
  [[ "$DNS_MODE" == "slave" ]] && echo "   • Master IP:       $SLAVE_MASTER_IP"
else
  echo "   • DNS сървър:     няма да бъде инсталиран"
fi
printf "📌 DNS инструменти (dig):            %s\n" "${RESULT_DNSUTILS:-❔}"
echo ""
echo "   • Услуги за инсталиране: $INSTALLED_SERVICES"

while true; do
  read -rp "❓ Потвърждавате ли тази информация? (y/N/q): " CONFIRM
  case "$CONFIRM" in
    y|Y)
      break
      ;;
    n|N|"")
      echo "❌ Прекратено от оператора."
      exit 1
      ;;
    q|Q)
      exit 0
      ;;
    *)
      echo "❌ Невалиден отговор. Моля въведете y, n или q."
      ;;
  esac
done

echo "[4] КОНФИГУРИРАНЕ НА UFW (Отваряне на портове)..."
echo "-------------------------------------------------------------------------"

# Основни портове
UFW_PORTS=(
  53    # DNS
  80    # HTTP
  443   # HTTPS
  25    # SMTP (Postfix)
  587   # SMTP TLS (Postfix)
  993   # IMAPS (Dovecot)
  995   # POP3S (Dovecot)
)

# Автоматично добавяне на текущия SSH порт
SSH_PORT=$(grep -i "^Port" /etc/ssh/sshd_config | awk '{print $2}' | head -n1)
if [[ -z "$SSH_PORT" ]]; then
  SSH_PORT=22
fi
UFW_PORTS+=("$SSH_PORT")

# Проверка за наличност на ufw
if ! command -v ufw >/dev/null 2>&1; then
  echo "ℹ️ Инсталираме UFW..."
  if ! apt-get install -y ufw >/dev/null 2>&1; then
    RESULT_UFW_SERVICES="❌"
    echo "❌ Неуспешна инсталация на UFW."
    echo ""
    return
  fi
fi

echo "🔐 Активиране на UFW и отваряне на нужните портове..."

# Задаване на политики
ufw --force reset >/dev/null 2>&1
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null

# Отваряне на портовете
PORT_ERRORS=0
for port in "${UFW_PORTS[@]}"; do
  if ! ufw allow "$port" >/dev/null 2>&1; then
    echo "⚠️ Грешка при отваряне на порт $port"
    PORT_ERRORS=$((PORT_ERRORS + 1))
  fi
done

# Активиране на UFW
if ufw --force enable >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  if [[ "$PORT_ERRORS" -eq 0 ]]; then
    RESULT_UFW_SERVICES="✅"
    echo "✅ Файъруолът е конфигуриран и активен."
  else
    RESULT_UFW_SERVICES="⚠️"
    echo "⚠️ UFW е активен, но някои портове не се отвориха."
  fi
else
  RESULT_UFW_SERVICES="❌"
  echo "❌ Неуспешно активиране на UFW."
fi
echo ""
echo ""

echo "[5] КОНФИГУРИРАНЕ НА DNS СЪРВЪРА (bind9)"
echo "-------------------------------------------------------------------------"

DNS_CONFIG_STATUS="❌"

if [[ "$DNS_REQUIRED" == "yes" ]]; then
  echo "⏳ Подготовка на DNS конфигурацията..."

  # Проверка и инсталация на bind9, ако липсва
  if ! dpkg -s bind9 >/dev/null 2>&1; then
    echo "ℹ️ bind9 не е инсталиран. Инсталираме bind9..."
    apt-get install -y bind9 bind9utils >/dev/null 2>&1
  fi

  mkdir -p /etc/bind/zones
  BIND_LOCAL_CONF="/etc/bind/named.conf.local"

  if [[ "$DNS_MODE" == "master" ]]; then
    ZONE_FILE="/etc/bind/zones/db.${DNS_ZONE}"

    if grep -q "zone \"$DNS_ZONE\"" "$BIND_LOCAL_CONF"; then
      echo "ℹ️ Зоната $DNS_ZONE вече е дефинирана. Пропускане на повторна конфигурация."
      DNS_CONFIG_STATUS="✅ (вече съществува)"
    else
      echo "🔧 Създаване на master зона за $DNS_ZONE..."
      cat <<EOF >> "$BIND_LOCAL_CONF"

zone "$DNS_ZONE" {
    type master;
    file "$ZONE_FILE";
    allow-transfer { any; };
};
EOF

      cat <<EOF > "$ZONE_FILE"
\$TTL    604800
@       IN      SOA     ns1.$DNS_ZONE. admin.$DNS_ZONE. (
                             3         ; Serial
                        604800         ; Refresh
                         86400         ; Retry
                       2419200         ; Expire
                        604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.$DNS_ZONE.
@       IN      A       $SERVER_IP
ns1     IN      A       $SERVER_IP
EOF
    fi

  elif [[ "$DNS_MODE" == "slave" ]]; then
    if grep -q "zone \"$DNS_ZONE\"" "$BIND_LOCAL_CONF"; then
      echo "ℹ️ Зоната $DNS_ZONE вече е дефинирана. Пропускане на повторна конфигурация."
      DNS_CONFIG_STATUS="✅ (вече съществува)"
    else
      echo "🔧 Създаване на slave зона за $DNS_ZONE..."
      cat <<EOF >> "$BIND_LOCAL_CONF"

zone "$DNS_ZONE" {
    type slave;
    file "/var/cache/bind/db.${DNS_ZONE}";
    masters { $SLAVE_MASTER_IP; };
};
EOF
    fi
  fi

  echo "🔍 Проверка на конфигурацията..."
  if named-checkconf >/dev/null 2>&1 && named-checkzone "$DNS_ZONE" "$ZONE_FILE" >/dev/null 2>&1; then
    systemctl restart bind9
    echo "✅ DNS конфигурацията е успешна и bind9 е рестартиран."
    DNS_CONFIG_STATUS="✅"
  else
    echo "❌ Открити са грешки в DNS конфигурацията. Проверете файловете ръчно."
    DNS_CONFIG_STATUS="❌"
  fi
else
  echo "ℹ️ DNS сървър няма да бъде конфигуриран – пропускане."
  DNS_CONFIG_STATUS="🔒"
fi
echo ""
echo ""

echo "[6] ИНСТАЛАЦИЯ НА APACHE И МОДУЛИ..."
echo "-------------------------------------------------------------------------"

# Проверка дали Apache вече е инсталиран
if dpkg -s apache2 >/dev/null 2>&1; then
  echo "ℹ️ Apache вече е инсталиран. Пропускане на тази стъпка."
  RESULT_APACHE="✅ (вече инсталиран)"
else
  echo "⏳ Инсталиране на Apache и PHP модули..."

  APACHE_PACKAGES=(
    apache2
    apache2-utils
    libapache2-mod-php
    php
    php-cli
    php-curl
    php-mbstring
    php-mysql
    php-xml
    php-zip
  )

  if apt-get install -y "${APACHE_PACKAGES[@]}"; then
    RESULT_APACHE="✅"
    echo "✅ Apache и PHP модулите са инсталирани успешно."
  else
    RESULT_APACHE="❌"
    echo "❌ Грешка при инсталиране на Apache или PHP."
  fi
fi
echo ""
echo ""

echo "[7] ИНСТАЛАЦИЯ НА CERTBOT..."
echo "-------------------------------------------------------------------------"

# Проверка дали certbot вече е инсталиран
if command -v certbot >/dev/null 2>&1; then
  echo "ℹ️ Certbot вече е инсталиран. Пропускане на тази стъпка."
  RESULT_CERTBOT="✅ (вече инсталиран)"
else
  echo "⏳ Инсталиране на Certbot и Apache plugin..."

  CERTBOT_PACKAGES=(
    certbot
    python3-certbot-apache
  )

  if apt-get install -y "${CERTBOT_PACKAGES[@]}"; then
    RESULT_CERTBOT="✅"
    echo "✅ Certbot е инсталиран успешно."
  else
    RESULT_CERTBOT="❌"
    echo "❌ Грешка при инсталиране на Certbot."
  fi
fi
echo ""
echo ""

echo "[8] ИНСТАЛАЦИЯ НА MARIADB (MySQL)..."
echo "-------------------------------------------------------------------------"

# Проверка дали MariaDB вече е инсталирана
if dpkg -s mariadb-server >/dev/null 2>&1; then
  echo "ℹ️ MariaDB вече е инсталирана. Пропускане на тази стъпка."
  RESULT_MARIADB="✅ (вече инсталирана)"
else
  echo "⏳ Инсталиране на MariaDB..."

  DB_PACKAGES=(
    mariadb-server
    mariadb-client
  )

  export DEBIAN_FRONTEND=noninteractive

  if apt-get install -y "${DB_PACKAGES[@]}"; then
    RESULT_MARIADB="✅"
    echo "✅ MariaDB е инсталирана успешно."
  else
    RESULT_MARIADB="❌"
    echo "❌ Грешка при инсталиране на MariaDB."
  fi

  unset DEBIAN_FRONTEND
fi
echo ""
echo ""

echo "[9] СИГУРНОСТ НА MARIADB..."
echo "-------------------------------------------------------------------------"

SECURE_SQL=$(cat <<EOF
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
)

if echo "$SECURE_SQL" | mysql -u root >/dev/null 2>&1; then
  RESULT_MARIADB_SECURE="✅"
  echo "✅ MariaDB е защитена успешно."
else
  RESULT_MARIADB_SECURE="❌"
  echo "❌ Грешка при изпълнение на защитните SQL команди."
fi
echo ""
echo ""

echo "[10] ИНСТАЛАЦИЯ НА ПОЩЕНСКИ СЪРВЪР (Postfix + Dovecot)..."
echo "-------------------------------------------------------------------------"

# Проверка дали Postfix и Dovecot вече са инсталирани
if dpkg -s postfix >/dev/null 2>&1 && dpkg -s dovecot-core >/dev/null 2>&1; then
  echo "ℹ️ Пощенският сървър вече е инсталиран. Пропускане на тази стъпка."
  RESULT_POSTFIX="✅ (вече инсталиран)"
  RESULT_DOVECOT="✅ (вече инсталиран)"
else
  echo "⏳ Инсталиране на Postfix и Dovecot..."

  MAIL_PACKAGES=(
    postfix
    dovecot-core
    dovecot-imapd
    dovecot-pop3d
    mailutils
  )

  # Предотвратява появата на интерактивни диалози от postfix
  export DEBIAN_FRONTEND=noninteractive

  if apt-get install -y "${MAIL_PACKAGES[@]}"; then
    RESULT_POSTFIX="✅"
    RESULT_DOVECOT="✅"
    echo "✅ Пощенският сървър е инсталиран успешно."
  else
    RESULT_POSTFIX="❌"
    RESULT_DOVECOT="❌"
    echo "❌ Грешка при инсталиране на Postfix или Dovecot."
  fi

  unset DEBIAN_FRONTEND
fi
echo ""
echo ""

echo "[11] ИНСТАЛАЦИЯ НА FAIL2BAN..."
echo "-------------------------------------------------------------------------"

# Проверка дали Fail2ban вече е инсталиран
if dpkg -s fail2ban >/dev/null 2>&1; then
  echo "ℹ️ Fail2ban вече е инсталиран. Пропускане на тази стъпка."
  RESULT_FAIL2BAN="✅ (вече инсталиран)"
else
  echo "⏳ Инсталиране и стартиране на Fail2ban..."

  if apt-get install -y fail2ban; then
    systemctl enable fail2ban >/dev/null 2>&1
    systemctl start fail2ban >/dev/null 2>&1
    RESULT_FAIL2BAN="✅"
    echo "✅ Fail2ban е инсталиран и стартиран."
  else
    RESULT_FAIL2BAN="❌"
    echo "❌ Грешка при инсталиране на Fail2ban."
  fi
fi
echo ""
echo ""

# === [12] АКТИВИРАНЕ НА КВОТИ ЗА ДИСКОВО ПРОСТРАНСТВО =========================
echo ""
echo "[12] АКТИВИРАНЕ НА КВОТИ ЗА ДИСКОВО ПРОСТРАНСТВО..."
echo "-------------------------------------------------------------------------"

# Инсталиране на необходимия пакет за квоти
echo "⏳ Инсталиране на инструменти за квоти (quota)..."
sudo apt-get update -qq
sudo apt-get install -y quota

# Проверка дали командата repquota е налична
if ! command -v repquota >/dev/null 2>&1; then
  echo "❌ repquota липсва – инсталацията на пакета quota се е провалила."
  RESULT_QUOTAS="❌"
else
  echo "✅ Инсталацията на quota е успешна – repquota е налична."

  # Проверка дали файловата система вече има активирани квоти
  if ! grep -qE '\susrquota|\sgrpquota' /etc/fstab; then
    echo ""
    echo "⏳ Добавяне на опции usrquota,grpquota в /etc/fstab за root (/) и /boot (ако има)..."
    sudo cp /etc/fstab /etc/fstab.bak

    sudo sed -i '/ \/ /s/\(ext4[[:space:]]\+\)\([^\s]*\)/\1\2,usrquota,grpquota/' /etc/fstab
    sudo sed -i '/ \/boot /s/\(ext4[[:space:]]\+\)\([^\s]*\)/\1\2,usrquota,grpquota/' /etc/fstab
  else
    echo "ℹ️  usrquota и grpquota вече са конфигурирани в /etc/fstab."
  fi

  # Проверка дали root файловата система вече е монтирана с активирани квоти
  if mount | grep -E 'on / type' | grep -q 'usrquota' && mount | grep -E 'on / type' | grep -q 'grpquota'; then
    echo ""
    echo "✅ Root файловата система вече е монтирана с активирани квоти."
    RESULT_QUOTAS="✅"
  else
    echo ""
    echo "⚠️  Root файловата система все още не е монтирана с активни квоти."
    echo "🔁 Ще бъде необходим рестарт, за да се активират квотите."
    RESULT_QUOTAS="⚠️  Изисква рестарт"
  fi
fi
echo ""
echo ""

# === [13] ИНСТАЛИРАНЕ НА ВСИЧКИ ПОДДЪРЖАНИ PHP ВЕРСИИ ======================
echo ""
echo "[13] Изтегляне на всички поддържани версии на PHP (5.6–7.3)..."
echo "-------------------------------------------------------------------------"
echo ""

# Директория за съхранение на пакетите
TARGET_DIR="/opt/php-packages"
sudo mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR" || exit 1

# Версии и модули
PHP_OLD_VERSIONS=(5.6 7.0 7.1 7.2 7.3)
MODULES=(cli common fpm mysql mbstring xml curl zip)

# Сваляне на всички .deb пакети
for VERSION in "${PHP_OLD_VERSIONS[@]}"; do
  echo "⏳ PHP $VERSION..."
  for MODULE in "${MODULES[@]}"; do
    echo "  → php${VERSION}-${MODULE}"
    apt-get download php${VERSION}-${MODULE} 2>/dev/null
  done
  echo "  → php${VERSION}"
  apt-get download php${VERSION} 2>/dev/null
  echo ""
done

RESULT_PHP_ALL_VERSIONS="✅"
echo "✅ Свалянето на наличните PHP пакети завърши."
echo "📦 Файловете се намират в: $TARGET_DIR"
echo ""
echo ""

# === [14] ИНСТАЛИРАНЕ НА PHPMYADMIN =========================================
echo ""
echo "[14] Инсталиране на phpMyAdmin..."
echo "-------------------------------------------------------------------------"
echo ""

# Инсталиране без интерактивен debconf
export DEBIAN_FRONTEND=noninteractive
sudo apt-get install -y phpmyadmin 2>/dev/null

if [[ $? -eq 0 ]]; then
  echo "✅ phpMyAdmin беше инсталиран успешно."
  RESULT_PHPMYADMIN_INSTALL="✅"
else
  echo "⚠️ Възникна проблем при инсталацията на phpMyAdmin."
  RESULT_PHPMYADMIN_INSTALL="⚠️"
fi

# Възстановяване на стандартен режим на debconf
unset DEBIAN_FRONTEND

# === ОБОБЩЕНИЕ НА ИНСТАЛАЦИЯТА =======================================
echo ""
echo "========================================================================="
echo "           ✅ ИНСТАЛАЦИЯТА НА ВИРТУАЛНИЯ ХОСТ Е ПРИКЛЮЧЕНА"
echo "========================================================================="
echo ""
printf "🌐 Домейн:                        %s\n" "$SUMMARY_DOMAIN"
printf "📁 Уеб директория:                %s\n" "$SUMMARY_WEBROOT"
printf "👤 Номинален потребител:          %s\n" "$SUMMARY_NOMINAL_USER"
printf "👥 Група:                         %s\n" "$SUMMARY_NOMINAL_GROUP"
printf "📦 Квота:                         %s GB\n" "$SUMMARY_DISK_LIMIT_GB"
printf "🐘 PHP версия:                    %s\n" "$SUMMARY_PHP_VERSION"
printf "🔐 SSL тип:                       %s\n" "$([
  case "$SUMMARY_SSL_TYPE" in
    letsencrypt) echo "Let's Encrypt" ;;
    custom) echo "Потребителски" ;;
    *) echo "Няма" ;;
  esac
])"

[[ "$RESULT_DB_CREATE" == "✅" ]] && {
  printf "🛢️  База данни:                   %s\n" "$SUMMARY_DB_NAME"
  printf "👤 Потребител на БД:             %s\n" "$SUMMARY_DB_USER"
}

[[ "$RESULT_FTP_CREATE" == "✅" ]] && {
  printf "📡 FTP потребител:               %s\n" "$SUMMARY_FTP_USER"
  printf "📁 FTP достъп до:                %s\n" "$SUMMARY_FTP_HOME"
}

echo ""
echo "🟢 Статус на изпълнение по секции:"
echo "-------------------------------------------------------------------------"
printf "📁 Уеб директория:                %s\n" "${RESULT_CREATE_WEBROOT:-❔}"
printf "📦 Квота за потребителя:          %s\n" "${RESULT_USER_QUOTA:-❔}"
printf "🐘 PHP инсталация:                %s\n" "${RESULT_PHP_INSTALL:-❔}"
printf "🌐 Apache конфигурация:           %s\n" "${RESULT_APACHE_VHOST:-❔}"
printf "📄 Начална страница:              %s\n" "${RESULT_CREATE_INDEX:-❔}"
printf "🛢️  База данни:                    %s\n" "${RESULT_DB_CREATE:-❔}"
printf "📡 FTP акаунт:                    %s\n" "${RESULT_FTP_CREATE:-❔}"
printf "🔐 SSL конфигурация:              %s\n" "${RESULT_SSL_CONFIG:-❔}"
printf "🐘 Всички PHP версии:             %s\n" "${RESULT_PHP_ALL_VERSIONS:-❔}"
printf "📦 phpMyAdmin:                    %s\n" "${RESULT_PHPMYADMIN_INSTALL:-❔}"

echo ""
echo "✅ Скриптът приключи успешно и беше изтрит."
echo "========================================================================="

rm -- "$0"

