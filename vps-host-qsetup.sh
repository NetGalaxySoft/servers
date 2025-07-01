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

# === ГЛОБАЛНИ ПРОМЕНЛИВИ ===================================================
SERVER_IP=""
ACTUAL_IP=$(curl -s ifconfig.me)
SERVER_DOMAIN=""
ACTUAL_DOMAIN=$(hostname -f)
DNS_REQUIRED=""
DNS_MODE="master"
DNS_ZONE=""
SLAVE_MASTER_IP=""
CONFIRM=""

# === [1] СЪБИРАНЕ НА ИНФОРМАЦИЯ И ПРОВЕРКА НА СЪРВЪРА ======================

while true; do
  read -rp "➤ Въведете публичния IP адрес на сървъра (или 'q' за изход): " SERVER_IP
  [[ "$SERVER_IP" == "q" ]] && exit 0
  if [[ $SERVER_IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    if [[ "$SERVER_IP" != "$ACTUAL_IP" ]]; then
      echo "❌ Въведеният IP адрес ($SERVER_IP) не съвпада с реалния IP адрес на сървъра ($ACTUAL_IP)"
      echo "🛑 Опит за изпълнение на скрипта върху погрешен сървър. Прекратяване."
      exit 1
    fi
    break
  else
    echo "❌ Невалиден IP адрес. Опитайте отново."
  fi
done

while true; do
  read -rp "➤ Въведете пълното домейн име (FQDN) на сървъра (или 'q' за изход): " SERVER_DOMAIN
  [[ "$SERVER_DOMAIN" == "q" ]] && exit 0
  if [[ $SERVER_DOMAIN =~ ^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)+([A-Za-z]{2,})$ ]]; then
    if [[ "$SERVER_DOMAIN" != "$ACTUAL_DOMAIN" ]]; then
      echo "❌ Въведеният FQDN ($SERVER_DOMAIN) не съвпада с текущото име на сървъра ($ACTUAL_DOMAIN)"
      echo "🛑 Опит за изпълнение на скрипта върху погрешен сървър. Прекратяване."
      exit 1
    fi
    break
  else
    echo "❌ Невалиден FQDN. Опитайте отново."
  fi
done

echo "✅ Потвърдено: Скриптът се изпълнява върху правилния сървър."

# === [2] ИСКА ЛИ ОПЕРАТОРЪТ DNS СЪРВЪР =====================================
while true; do
  read -rp "➤ Желаете ли да инсталирате DNS сървър (bind9)? (y/N/q): " DNS_REQUIRED
  case "$DNS_REQUIRED" in
    y|Y)
      DNS_REQUIRED="yes"
      break
      ;;
    n|N|"")
      DNS_REQUIRED="no"
      echo "ℹ️ Пропускане на конфигурация на DNS сървър."
      break
      ;;
    q|Q)
      exit 0
      ;;
    *)
      echo "❌ Невалиден отговор. Моля въведете y, n или q."
      ;;
  esac
done

# === [2a] ВЪПРОС ЗА DNS РЕЖИМ ===================================================
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

# [3] Финално потвърждение
INSTALLED_SERVICES="Apache2, MariaDB, PHP, Postfix, Dovecot, Roundcube"
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

echo "[4] ИНСТАЛАЦИЯ НА APACHE И МОДУЛИ..."
echo "-------------------------------------------------------------------------"

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

if apt-get install -y "${APACHE_PACKAGES[@]}" >/dev/null 2>&1; then
  RESULT_APACHE="✅"
  echo "✅ Apache и PHP модулите са инсталирани успешно."
else
  RESULT_APACHE="❌"
  echo "❌ Грешка при инсталиране на Apache или PHP."
fi
echo ""
echo ""

echo "[5] ИНСТАЛАЦИЯ НА CERTBOT..."
echo "-------------------------------------------------------------------------"

CERTBOT_PACKAGES=(
  certbot
  python3-certbot-apache
)

if apt-get install -y "${CERTBOT_PACKAGES[@]}" >/dev/null 2>&1; then
  RESULT_CERTBOT="✅"
  echo "✅ Certbot е инсталиран успешно."
else
  RESULT_CERTBOT="❌"
  echo "❌ Грешка при инсталиране на certbot."
fi
echo ""
echo ""

echo "[6] ИНСТАЛАЦИЯ НА ПОЩЕНСКИ СЪРВЪР (Postfix + Dovecot)..."
echo "-------------------------------------------------------------------------"

MAIL_PACKAGES=(
  postfix
  dovecot-core
  dovecot-imapd
  dovecot-pop3d
  mailutils
)

# Предотвратява появата на интерактивни диалози от postfix
export DEBIAN_FRONTEND=noninteractive

if apt-get install -y "${MAIL_PACKAGES[@]}" >/dev/null 2>&1; then
  RESULT_MAIL="✅"
  echo "✅ Пощенският сървър е инсталиран успешно."
else
  RESULT_MAIL="❌"
  echo "❌ Грешка при инсталиране на Postfix или Dovecot."
fi

# Връщаме обратно стойността
unset DEBIAN_FRONTEND
echo ""
echo ""

echo "[7] ИНСТАЛАЦИЯ НА ROUNDcube WEBMAIL..."
echo "-------------------------------------------------------------------------"

ROUNDCUBE_PACKAGES=(
  roundcube
  roundcube-core
  roundcube-mysql
  roundcube-plugins
  roundcube-plugins-extra
)

if apt-get install -y "${ROUNDCUBE_PACKAGES[@]}" >/dev/null 2>&1; then
  RESULT_ROUNDCUBE="✅"
  echo "✅ Roundcube е инсталиран успешно."
else
  RESULT_ROUNDCUBE="❌"
  echo "❌ Грешка при инсталиране на Roundcube."
fi
echo ""
echo ""

echo "[8] ИНСТАЛАЦИЯ НА MARIADB (MySQL)..."
echo "-------------------------------------------------------------------------"

DB_PACKAGES=(
  mariadb-server
  mariadb-client
)

export DEBIAN_FRONTEND=noninteractive

if apt-get install -y "${DB_PACKAGES[@]}" >/dev/null 2>&1; then
  RESULT_MARIADB="✅"
  echo "✅ MariaDB е инсталирана успешно."
else
  RESULT_MARIADB="❌"
  echo "❌ Грешка при инсталиране на MariaDB."
fi

unset DEBIAN_FRONTEND
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

echo "[10] ИНСТАЛАЦИЯ НА FAIL2BAN..."
echo "-------------------------------------------------------------------------"

if apt-get install -y fail2ban >/dev/null 2>&1; then
  systemctl enable fail2ban >/dev/null 2>&1
  systemctl start fail2ban >/dev/null 2>&1
  RESULT_FAIL2BAN="✅"
  echo "✅ Fail2ban е инсталиран и стартиран."
else
  RESULT_FAIL2BAN="❌"
  echo "❌ Грешка при инсталиране на Fail2ban."
fi
echo ""
echo ""

# ==========================================================================
# [12] КОНФИГУРИРАНЕ НА DNS СЪРВЪР
# ==========================================================================
echo ""
echo "[12] КОНФИГУРИРАНЕ НА DNS СЪРВЪРА (bind9)"
echo "-------------------------------------------------------------------------"

DNS_CONFIG_STATUS="❌"

if [[ "$DNS_REQUIRED" == "yes" ]]; then
  mkdir -p /etc/bind/zones
  BIND_LOCAL_CONF="/etc/bind/named.conf.local"

  if [[ "$DNS_MODE" == "master" ]]; then
    ZONE_FILE="/etc/bind/zones/db.${DNS_ZONE}"

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

  elif [[ "$DNS_MODE" == "slave" ]]; then
    echo "🔧 Създаване на slave зона за $DNS_ZONE..."
    cat <<EOF >> "$BIND_LOCAL_CONF"

zone "$DNS_ZONE" {
    type slave;
    file "/var/cache/bind/db.${DNS_ZONE}";
    masters { $SLAVE_MASTER_IP; };
};
EOF
  fi

  echo "🔍 Проверка на конфигурацията..."
  if named-checkconf && named-checkzone "$DNS_ZONE" "$ZONE_FILE" > /dev/null 2>&1; then
    systemctl restart bind9
    echo "✅ DNS конфигурацията е успешна и bind9 е рестартиран."
    DNS_CONFIG_STATUS="✅"
  else
    echo "❌ Открити са грешки в DNS конфигурацията. Проверете файловете ръчно."
  fi
else
  echo "ℹ️ DNS сървър няма да бъде конфигуриран – пропускане."
  DNS_CONFIG_STATUS="🔒"
fi
echo ""
echo ""

echo "-------------------------------------------------------------------------"
echo "            ОБОБЩЕНИЕ НА РЕЗУЛТАТИТЕ ОТ КОНФИГУРАЦИЯТА"
echo "-------------------------------------------------------------------------"

printf "📌 Домейн (FQDN):                    %s\n" "$SERVER_DOMAIN"
printf "📌 IP адрес на сървъра:             %s\n" "$SERVER_IP"

if [[ "$DNS_REQUIRED" == "yes" ]]; then
  printf "📌 DNS сървър:                       ✅ активен (%s режим)\n" "$DNS_MODE"
  printf "📌 DNS зона:                         %s\n" "$DNS_ZONE"
  [[ "$DNS_MODE" == "slave" ]] && printf "📌 Master DNS IP:                    %s\n" "$SLAVE_MASTER_IP"
  printf "📌 Конфигурация на bind9:           %s\n" "${DNS_CONFIG_STATUS:-❔}"
else
  printf "📌 DNS сървър:                       ❌ няма да се инсталира\n"
fi

printf "📌 Apache уеб сървър:              %s\n" "${RESULT_APACHE:-❔}"
printf "📌 Certbot (Let's Encrypt):        %s\n" "${RESULT_CERTBOT:-❔}"
printf "📌 Postfix (SMTP сървър):          %s\n" "${RESULT_POSTFIX:-❔}"
printf "📌 Dovecot (IMAP сървър):          %s\n" "${RESULT_DOVECOT:-❔}"
printf "📌 Roundcube Webmail:              %s\n" "${RESULT_ROUNDCUBE:-❔}"
printf "📌 MariaDB сървър:                 %s\n" "${RESULT_MARIADB:-❔}"
printf "📌 Защита на MariaDB:              %s\n" "${RESULT_MARIADB_SECURE:-❔}"
printf "📌 Fail2ban защита:                %s\n" "${RESULT_FAIL2BAN:-❔}"
printf "📌 UFW правила за услуги:          %s\n" "${RESULT_UFW_SERVICES:-❔}"

[[ "$WHOIS_INSTALLED" == "yes" ]] && echo "ℹ️  whois беше инсталиран временно за проверка и може да бъде премахнат."

echo ""
echo "✅ Скриптът приключи успешно и беше изтрит от системата."
rm -- "$0"
