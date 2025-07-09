#!/bin/bash

# ==========================================================================
#  vps-virhost-create.sh – Създаване на виртуален хост (Apache)
# --------------------------------------------------------------------------
#  Версия: 1.0
#  Дата:   2025-07-07
#  Автор:  Ilko Yordanov / NetGalaxy
# ==========================================================================
#
#  Този скрипт подготвя и конфигурира виртуален хост върху съществуващ VPS.
#  Поддържа основни и субдомейни, с възможност за собствен или Let's Encrypt
#  сертификат, избор на PHP версия и автоматична структура на уеб директории.
#
#  🔒 Скриптът НЕ извършва никакви промени, докато операторът не прегледа
#     и потвърди всички избрани параметри.
# ==========================================================================

# === ПОМОЩНА ИНФОРМАЦИЯ ===================================================
show_help() {
  echo "Използване: vps-virhost-create.sh [опция]"
  echo ""
  echo "Създава виртуален хост за Apache сървър с пълна структура и SSL."
  echo "Позволява избор на PHP версия и тип сертификат (Let's Encrypt или собствен)."
  echo ""
  echo "Опции:"
  echo "  --version       Показва версията на скрипта"
  echo "  --help          Показва тази помощ"
}

# === ОБРАБОТКА НА ОПЦИИ ===================================================
if [[ $# -gt 0 ]]; then
  case "$1" in
    --version)
      echo "vps-virhost-create.sh версия 1.0 (7 юли 2025 г.)"
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

# Подготовка на променливи за събиране на данни
SUMMARY_DOMAIN=""
SUMMARY_ROOT_DOMAIN=""
SUMMARY_IS_SUBDOMAIN=""
SUMMARY_WEBROOT=""
SUMMARY_PHP_VERSION=""
SUMMARY_SSL_TYPE=""
SUMMARY_CUSTOM_MESSAGE=""

# Променливи за собственост и достъп
SUMMARY_NOMINAL_USER=""          # напр. nomhost__humanizma_eu
SUMMARY_NOMINAL_GROUP=""         # напр. host0_humanizma_eu

# Променливи за лимит
SUMMARY_DISK_LIMIT_MB=""
SUMMARY_ENABLE_NOMINAL_USER=""

# Променливи за главен администратор
SUMMARY_ADMIN_USER=""
SUMMARY_ADMIN_PASSWORD=""

# Променливи за база данни
SUMMARY_DB_NAME=""
SUMMARY_DB_USER=""
SUMMARY_DB_PASSWORD=""

# FTP достъп
SUMMARY_ENABLE_FTP=""

echo "=================================================================="
echo " 🌐 NetGalaxy - Създаване на виртуален хост за Apache сървър"
echo "=================================================================="

# Проверка за root права
if [[ "$EUID" -ne 0 ]]; then
  echo "❌ Скриптът трябва да бъде изпълнен с root права (sudo)."
  exit 1
fi

# Проверка за наличен Apache
if ! command -v apache2 >/dev/null 2>&1; then
  echo "❌ Apache уеб сървърът не е инсталиран. Инсталирайте го преди да продължите."
  exit 1
fi

# === [1] ПРОВЕРКА НА СЪРВЪРА ======================
echo ""
echo "[1] ПРОВЕРКА НА СЪРВЪРА..."
echo "-------------------------------------------------------------------------"
echo ""

# Откриване на реалния публичен IP адрес на сървъра
ACTUAL_IP=$(curl -s https://api.ipify.org)

if [[ -z "$ACTUAL_IP" ]]; then
  echo "❌ Неуспешно откриване на публичния IP адрес. Проверете интернет връзката."
  exit 1
fi

while true; do
  read -rp "➤ Въведете публичния IP адрес, на който трябва да работи този виртуален хост (или 'q' за изход): " SERVER_IP

  [[ "$SERVER_IP" == "q" ]] && {
    echo "🚪 Прекратяване по заявка на оператора."
    exit 0
  }

  if [[ "$SERVER_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    if [[ "$SERVER_IP" != "$ACTUAL_IP" ]]; then
      echo "❌ Въведеният IP адрес ($SERVER_IP) не съвпада с реалния IP адрес на сървъра."
      echo "🛑 Скриптът ще бъде прекратен, за да се избегне грешна инсталация."
      exit 1
    fi
    break
  else
    echo "⚠️ Невалиден IP адрес. Моля, опитайте отново."
  fi
done

SUMMARY_SERVER_IP="$SERVER_IP"

# === [2] ПРОВЕРКА НА ДОМЕЙНА ======================================
echo ""
echo "[2] ПРОВЕРКА НА ДОМЕЙНА..."
echo "-------------------------------------------------------------------------"
echo ""

while true; do
  read -rp "➤ Въведете основен или субдомейн (напр. example.com или blog.example.com), или 'q' за изход: " input_domain

  [[ "$input_domain" == "q" ]] && {
    echo "🚪 Прекратяване по заявка на оператора."
    exit 0
  }

  # Празно поле
  if [[ -z "$input_domain" ]]; then
    echo "⚠️ Домейнът не може да бъде празен. Опитайте отново."
    continue
  fi

  # Проверка за валиден формат
  if ! [[ "$input_domain" =~ ^[a-z0-9.-]+\.[a-z]{2,}$ ]]; then
    echo "⚠️ Невалиден домейн. Уверете се, че е в правилен формат."
    continue
  fi

  # Проверка чрез публичен DNS сървър (Google DNS)
  resolved_ip=$(dig +short "$input_domain" @8.8.8.8 | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1)

  if [[ -z "$resolved_ip" ]]; then
    echo "❌ Домейнът \"$input_domain\" не се резолвира към IP адрес (според публичния DNS)."
    echo "🔧 Проверете DNS записите и се уверете, че сочат към този сървър."
    continue
  fi

  # Проверка дали съвпада с публичния IP адрес на сървъра
  if [[ "$resolved_ip" != "$SUMMARY_SERVER_IP" ]]; then
    echo "❌ Домейнът се резолвира към $resolved_ip, но публичният IP адрес на сървъра е $SUMMARY_SERVER_IP."
    echo "🛑 Уверете се, че DNS записите сочат към този сървър."
    continue
  fi

  echo "✅ Домейнът се резолвира правилно към IP: $resolved_ip"
  break
done

# Записване в променлива
SUMMARY_DOMAIN="$input_domain"

# Извличане на root домейн
IFS='.' read -ra domain_parts <<< "$SUMMARY_DOMAIN"
domain_parts_count=${#domain_parts[@]}
SUMMARY_ROOT_DOMAIN="${domain_parts[-2]}.${domain_parts[-1]}"

# Определяне дали е субдомейн
if [[ "$SUMMARY_DOMAIN" != "$SUMMARY_ROOT_DOMAIN" ]]; then
  SUMMARY_IS_SUBDOMAIN="yes"
  sub_name="${SUMMARY_DOMAIN%%.$SUMMARY_ROOT_DOMAIN}"
  SUMMARY_WEBROOT="/var/www/$SUMMARY_ROOT_DOMAIN/$sub_name/public_html"
else
  SUMMARY_IS_SUBDOMAIN="no"
  SUMMARY_WEBROOT="/var/www/$SUMMARY_ROOT_DOMAIN/public_html"
fi

# Извеждане на резултата
echo "📌 Разпознат домейн:          $SUMMARY_DOMAIN"
echo "📌 Root домейн:               $SUMMARY_ROOT_DOMAIN"
echo "📌 Тип:                       $( [[ "$SUMMARY_IS_SUBDOMAIN" == "yes" ]] && echo 'субдомейн' || echo 'основен домейн' )"
echo "📁 Директория:                $SUMMARY_WEBROOT"

# === [3] НАЧАЛНА СТРАНИЦА НА ХОСТА ==========================================
echo ""
echo "[3] НАЧАЛНА СТРАНИЦА НА ХОСТА..."
echo "-------------------------------------------------------------------------"
echo ""

echo "Началната страница на вашия хост ще показва следното съобщение:"
echo ""
echo "www.${SUMMARY_DOMAIN}"
echo "This site is under construction."
echo "Вие може да добавите допълнителен текст към този."
echo ""

read -rp "💬 Въведете съобщение (до 160 символа). Натиснете Enter за пропускане или 'q' за прекратяване: " custom_msg

if [[ "$custom_msg" == "q" ]]; then
  echo "🚪 Прекратяване по заявка на оператора."
  exit 0
fi

# Обрязване до 160 символа
custom_msg="${custom_msg:0:160}"

SUMMARY_CUSTOM_MESSAGE="$custom_msg"

if [[ -n "$custom_msg" ]]; then
  echo "✅ Съобщението ще бъде добавено към началната страница."
else
  echo "ℹ️ Няма въведено съобщение – index.html ще съдържа само стандартен текст."
fi

# === [4] ИЗБОР НА PHP ВЕРСИЯ ===============================================
echo ""
echo "[4] ИЗБОР НА PHP ВЕРСИЯ..."
echo "-------------------------------------------------------------------------"
echo ""

echo "🧮 Откриване на наличните PHP версии..."

# Списък с всички поддържани версии от ondrej/php
ALL_PHP_VERSIONS=(8.3 8.2 8.1 8.0 7.4 7.3 7.2 7.1 7.0 5.6)
php_versions_array=()
menu_index=1

# Проверка коя е инсталирана и коя не
for ver in "${ALL_PHP_VERSIONS[@]}"; do
  if [[ -d "/etc/php/$ver" ]]; then
    php_versions_array+=("$ver|installed")
  else
    php_versions_array+=("$ver|missing")
  fi
done

# Меню
echo ""
echo "➤ Изберете PHP версия за този виртуален хост:"
for entry in "${php_versions_array[@]}"; do
  version="${entry%%|*}"
  status="${entry##*|}"

  if [[ $menu_index -eq 1 ]]; then
    label="(по подразбиране – последна стабилна)"
  else
    label=""
  fi

  if [[ "$status" == "installed" ]]; then
    echo "[$menu_index] PHP $version $label"
  else
    echo "[$menu_index] PHP $version ⚠️ (ще бъде инсталирана) $label"
  fi
  ((menu_index++))
done
echo "[q] Прекратяване"

# Избор
while true; do
  read -rp "Вашият избор [1]: " php_choice

  if [[ "$php_choice" == "q" ]]; then
    echo "🚪 Прекратяване по заявка на оператора."
    exit 0
  fi

  if [[ -z "$php_choice" ]]; then
    php_choice=1
  fi

  if ! [[ "$php_choice" =~ ^[0-9]+$ ]] || (( php_choice < 1 || php_choice > ${#php_versions_array[@]} )); then
    echo "⚠️ Невалиден избор. Опитайте отново."
    continue
  fi

  selected_entry="${php_versions_array[$((php_choice - 1))]}"
  selected_version="${selected_entry%%|*}"
  selected_status="${selected_entry##*|}"

  SUMMARY_PHP_VERSION="$selected_version"
  echo "✅ Избрана PHP версия: PHP $selected_version"

  if [[ "$selected_status" == "missing" ]]; then
    SUMMARY_PHP_INSTALL_REQUIRED="yes"
  else
    SUMMARY_PHP_INSTALL_REQUIRED="no"
  fi
  break
done

# === [5] ИЗБОР НА СЕРТИФИКАТ ==============================================
echo ""
echo "[5] ИЗБОР НА СЕРТИФИКАТ..."
echo "-------------------------------------------------------------------------"
echo ""

echo "🔐 Избор на SSL сертификат:"
echo "  [1] Let's Encrypt (препоръчително, автоматично издаване)"
echo "  [2] Собствен сертификат (въвеждате .crt и .key файлове)"
echo "  [q] Прекратяване"

while true; do
  read -rp "Вашият избор [1]: " ssl_choice

  [[ "$ssl_choice" == "q" ]] && { echo "🚪 Прекратяване по заявка на оператора."; exit 0; }
  [[ -z "$ssl_choice" ]] && ssl_choice=1

  case "$ssl_choice" in
    1)
      SUMMARY_SSL_TYPE="letsencrypt"
      echo "✅ Избрано: Let's Encrypt (ще се използва certbot)"
      break
      ;;
    2)
      while true; do
        read -rp "📄 Въведете пълния път до .crt файла: " crt_path
        [[ "$crt_path" == "q" ]] && exit 0
        if [[ ! -f "$crt_path" ]]; then
          echo "❌ Файлът $crt_path не съществува."
          echo "🛠️ Изберете:"
          echo "  [1] Опитайте отново"
          echo "  [2] Смяна към Let's Encrypt"
          echo "  [q] Изход"
          read -rp "Вашият избор: " retry_choice
          case "$retry_choice" in
            1) continue ;;
            2)
              SUMMARY_SSL_TYPE="letsencrypt"
              echo "🔁 Превключване към Let's Encrypt."
              break 2
              ;;
            q|Q) echo "🚪 Прекратяване."; exit 0 ;;
            *) echo "⚠️ Невалиден избор."; continue ;;
          esac
        else
          break
        fi
      done

      while true; do
        read -rp "📄 Въведете пълния път до .key файла: " key_path
        [[ "$key_path" == "q" ]] && exit 0
        if [[ ! -f "$key_path" ]]; then
          echo "❌ Файлът $key_path не съществува."
          echo "🛠️ Изберете:"
          echo "  [1] Опитайте отново"
          echo "  [2] Смяна към Let's Encrypt"
          echo "  [q] Изход"
          read -rp "Вашият избор: " retry_choice
          case "$retry_choice" in
            1) continue ;;
            2)
              SUMMARY_SSL_TYPE="letsencrypt"
              echo "🔁 Превключване към Let's Encrypt."
              break 2
              ;;
            q|Q) echo "🚪 Прекратяване."; exit 0 ;;
            *) echo "⚠️ Невалиден избор."; continue ;;
          esac
        else
          break
        fi
      done

      SUMMARY_SSL_TYPE="custom"
      SUMMARY_SSL_CRT_PATH="$crt_path"
      SUMMARY_SSL_KEY_PATH="$key_path"
      echo "✅ Сертификатът ще бъде използван от зададените файлове."
      break
      ;;
    *)
      echo "⚠️ Невалиден избор. Изберете 1, 2 или q."
      ;;
  esac
done

# === [6] ЛИМИТ НА ДИСКОВОТО ПРОСТРАНСТВО ======================
echo ""
echo "[6] ЛИМИТ НА ДИСКОВОТО ПРОСТРАНСТВО..."
echo "-------------------------------------------------------------------------"
echo ""

domain_clean="${SUMMARY_ROOT_DOMAIN//./_}"
NOMINAL_USER="nomhost__${domain_clean}"
NOMINAL_GROUP="host0_${domain_clean}"
SUMMARY_NOMINAL_USER="$NOMINAL_USER"
SUMMARY_NOMINAL_GROUP="$NOMINAL_GROUP"

echo ""
echo "💽 Подготовка на номинален собственик и лимит на дисково пространство:"
echo "     Потребител: $NOMINAL_USER"
echo "     Група:      $NOMINAL_GROUP"
echo ""

# Проверка за наличност на repquota
if ! command -v repquota >/dev/null 2>&1; then
  echo "❌ Липсва команда 'repquota'. Инсталирайте пакета 'quota'."
  exit 1
fi

# Извличане на сумата на всички зададени квоти в MB
TOTAL_ALLOCATED_MB=$(sudo repquota -a | awk '$4 ~ /^[0-9]+$/ { sum += $4 } END { print int(sum / 1024) }')
TOTAL_ALLOCATED_MB=${TOTAL_ALLOCATED_MB:-0}

# Изчисляване на свободното пространство (с резерв)
available_kb=$(df --output=avail / | tail -n1)
available_mb=$((available_kb / 1024))
reserve_mb=5120  # 5 GB резерв за системата
usable_mb=$((available_mb - reserve_mb - TOTAL_ALLOCATED_MB))

# Проверка дали има поне 1 GB за нов сайт
if (( usable_mb < 1024 )); then
  echo "❌ Недостатъчно дисково пространство за задаване на лимит."
  echo "    Реално свободни:     ${available_mb} MB"
  echo "    Заделени чрез квоти: ${TOTAL_ALLOCATED_MB} MB"
  echo "    Резерв за системата: ${reserve_mb} MB"
  exit 1
fi

usable_gb=$((usable_mb / 1024))

# Дефиниране на допустими лимити
all_limits=(1 3 7 15 30)
valid_limits=()
for lim in "${all_limits[@]}"; do
  if (( lim * 1024 <= usable_mb )); then
    valid_limits+=("$lim")
  fi
done

# Меню за избор
echo "📦 Изберете лимит на дисково пространство за сайта:"
i=1
for lim in "${valid_limits[@]}"; do
  echo "[$i] ${lim} GB"
  ((i++))
done
echo "[q] Прекратяване"

while true; do
  read -rp "Вашият избор [2]: " choice

  [[ "$choice" == "q" ]] && {
    echo "🚪 Прекратяване по заявка на оператора."
    exit 0
  }

  [[ -z "$choice" ]] && choice=2

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#valid_limits[@]} )); then
    echo "⚠️ Невалиден избор. Моля, изберете между 1 и ${#valid_limits[@]}, или 'q'."
    continue
  fi

  selected_gb="${valid_limits[$((choice - 1))]}"
  break
done

# Записване в обобщението
SUMMARY_DISK_LIMIT_GB="$selected_gb"
SUMMARY_DISK_LIMIT_MB=$((selected_gb * 1024))
SUMMARY_ENABLE_NOMINAL_USER="yes"

echo ""
echo "✅ Номинален собственик:     $SUMMARY_NOMINAL_USER"
echo "✅ Група за достъп:          $SUMMARY_NOMINAL_GROUP"
echo "📦 Дисков лимит:             $SUMMARY_DISK_LIMIT_GB GB"

# === [7] СЪЗДАВАНЕ НА ПРОФИЛ ЗА ХОСТИНГ МЕНИДЖЪР (само събиране на данни) ===
echo ""
echo "[7] СЪЗДАВАНЕ НА ПРОФИЛ ЗА ХОСТИНГ МЕНИДЖЪР..."
echo "-------------------------------------------------------------------------"
echo ""

echo "👤 Ще бъде избран или създаден профил за мениджъра на този хост."

DEFAULT_ADMIN_USER="admin_${domain_clean}"

while true; do
  read -rp "🔑 Въведете потребителско име [${DEFAULT_ADMIN_USER}]: " input_user
  [[ "$input_user" == "q" ]] && echo "🚪 Прекратяване по заявка на оператора." && exit 0
  [[ -z "$input_user" ]] && input_user="$DEFAULT_ADMIN_USER"

  if ! [[ "$input_user" =~ ^[a-z_][a-z0-9_-]{2,30}$ ]]; then
    echo "❗ Невалидно потребителско име. Допустими са само малки букви, цифри, '-', '_' и минимум 3 символа."
    continue
  fi

  if id "$input_user" &>/dev/null; then
    echo "⚠️ Потребителят '$input_user' вече съществува."

    while true; do
      read -rp "❓ Искате ли да използвате този съществуващ потребител? [y/n/q]: " reuse
      case "$reuse" in
        y|Y)
          SUMMARY_ADMIN_USER="$input_user"
          SUMMARY_ADMIN_EXISTING="yes"
          SUMMARY_ADMIN_PASS="(съществуваща парола – няма да се променя)"
          echo "✅ Ще бъде използван съществуващият потребител: $SUMMARY_ADMIN_USER"
          break 2
          ;;
        n|N) break ;;  # Повтаря избора на име
        q|Q) echo "🚪 Прекратяване по заявка на оператора." && exit 0 ;;
        *) echo "❗ Моля, отговорете с y (да), n (не) или q (изход)." ;;
      esac
    done
  else
    echo "🆕 Ще бъде създаден нов потребител: $input_user"

    ONE_TIME_PASS="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 14)"
    echo "🔐 Генерирана еднократна парола: $ONE_TIME_PASS"

    while true; do
      read -rp "✅ Потвърждавате ли създаване на потребител с тази парола? [y/q]: " confirm_pass
      case "$confirm_pass" in
        y|Y)
          SUMMARY_ADMIN_USER="$input_user"
          SUMMARY_ADMIN_PASS="$ONE_TIME_PASS"
          SUMMARY_ADMIN_EXISTING="no"
          echo "✅ Данните за нов потребител са запазени. Ще бъде създаден по-късно."
          break 2
          ;;
        q|Q)
          echo "🚪 Прекратяване по заявка на оператора." && exit 0
          ;;
        *)
          echo "❗ Отказано. Моля, въведете потребител отново."
          break
          ;;
      esac
    done
  fi
done

# === [8] СЪЗДАВАНЕ НА БАЗА ДАННИ (MariaDB) – само събиране на данни ==========
echo ""
echo "[8] СЪЗДАВАНЕ НА БАЗА ДАННИ (MariaDB)..."
echo "-------------------------------------------------------------------------"
echo ""
echo "🗄️  Подготовка на данни за база (MariaDB), свързана с този виртуален хост."
echo ""

# Извличане на елементи от домейна
domain_clean="${SUMMARY_DOMAIN//./_}"  # напр. blog_humanizma_eu
subdomain_part=$(echo "$domain_clean" | cut -d'_' -f1)
main_part=$(echo "$domain_clean" | cut -d'_' -f2)
tld_part=$(echo "$domain_clean" | cut -d'_' -f3)

# Определяне на префикса
if [[ "$tld_part" == "" ]]; then
  # Няма субдомейн
  db_prefix="db"
  db_short="${main_part:0:3}$(shuf -i 10-99 -n 1)_${domain_clean##*.}"
else
  # Има субдомейн
  db_prefix="${subdomain_part:0:3}"
  db_short="${main_part:0:3}$(shuf -i 10-99 -n 1)_${tld_part}"
fi

DB_NAME="${db_prefix}_${db_short}"
DB_USER="$DB_NAME"
DB_PASS="${SUMMARY_ADMIN_PASS:-$(tr -dc A-Za-z0-9 </dev/urandom | head -c 14)}"

# Извеждане на предложение
echo "➡️  Име на базата:           $DB_NAME"
echo "➡️  Потребител на базата:    $DB_USER"
echo "➡️  Парола:                  (ще се използва паролата на администратора)"

echo ""
echo "🗄️  Искате ли да създадете база данни с тези параметри?"
echo "  [1] Да"
echo "  [2] Без база данни (по подразбиране)"
echo "  [q] Прекратяване"
read -rp "Вашият избор [2]: " db_choice
db_choice=${db_choice:-2}

case "$db_choice" in
  1)
    SUMMARY_DB_CREATE="yes"
    SUMMARY_DB_NAME="$DB_NAME"
    SUMMARY_DB_USER="$DB_USER"
    SUMMARY_DB_PASS="$DB_PASS"
    echo "✅ Данните за базата са запазени. Реалното създаване ще се извърши по-късно."
    ;;
  q|Q)
    echo "🚪 Прекратяване по заявка на оператора."
    exit 0
    ;;
  *)
    SUMMARY_DB_CREATE="no"
    echo "ℹ️ Пропускане създаването на база данни."
    ;;
esac

# === [9] СЪЗДАВАНЕ НА FTP ДОСТЪП ===========================================
echo ""
echo "[9] СЪЗДАВАНЕ НА FTP ДОСТЪП..."
echo "-------------------------------------------------------------------------"
echo ""

echo "📡 Създаване на FTP достъп за главния администратор на хоста..."

FTP_USER="$SUMMARY_ADMIN_USER"
FTP_HOME_DIR="$SUMMARY_WEBROOT"

# Проверка за наличност на vsftpd
if ! dpkg -s vsftpd >/dev/null 2>&1; then
  echo "⏳ Ще бъде инсталиран vsftpd сървър."
  SUMMARY_NEEDS_VSFTPD="yes"
else
  echo "✅ Наличен vsftpd сървър."
  SUMMARY_NEEDS_VSFTPD="no"
fi

SUMMARY_CREATE_FTP="yes"
SUMMARY_FTP_USER="$FTP_USER"
SUMMARY_FTP_HOME="$FTP_HOME_DIR"

echo "✅ Ще бъде създаден FTP профил за: $FTP_USER"
echo "📁 с достъп само до: $FTP_HOME_DIR"

# === [10] ПРЕДВАРИТЕЛЕН ПРЕГЛЕД И ПОТВЪРЖДЕНИЕ ==============================
echo ""
echo "[10] ПРЕДВАРИТЕЛЕН ПРЕГЛЕД И ПОТВЪРЖДЕНИЕ..."
echo "-------------------------------------------------------------------------"
echo ""

echo "🧾 Преглед на конфигурацията преди инсталация:"
echo "------------------------------------------------------------"
printf "🌐 Домейн:                   %s\n" "$SUMMARY_DOMAIN"
printf "🔢 Root домейн:              %s\n" "$SUMMARY_ROOT_DOMAIN"
printf "📁 Директория:               %s\n" "$SUMMARY_WEBROOT"
printf "🌐 Тип:                      %s\n" "$( [[ "$SUMMARY_IS_SUBDOMAIN" == "yes" ]] && echo 'субдомейн' || echo 'основен домейн' )"
printf "💬 Съобщение за сайта:       %s\n" "${SUMMARY_CUSTOM_MESSAGE:-(стандартно)}"
printf "🐘 PHP версия:               PHP %s\n" "$SUMMARY_PHP_VERSION"
printf "🔐 SSL сертификат:           %s\n" "$( [[ "$SUMMARY_SSL_TYPE" == "letsencrypt" ]] && echo "Let's Encrypt" || echo "Собствен сертификат" )"
[[ "$SUMMARY_SSL_TYPE" == "custom" ]] && {
  printf "📄 .crt файл:                %s\n" "$SUMMARY_CUSTOM_CRT"
  printf "🔑 .key файл:                %s\n" "$SUMMARY_CUSTOM_KEY"
}
printf "👤 Номинален собственик:     %s\n" "$SUMMARY_NOMINAL_USER"
printf "👥 Група за достъп:          %s\n" "$SUMMARY_NOMINAL_GROUP"
printf "📦 Дисков лимит:             %s GB\n" "$SUMMARY_DISK_LIMIT_GB"
printf "👨‍💼 Админ. потребител:      %s\n" "$SUMMARY_ADMIN_USER"
printf "👤 Админ принадлежи към:     %s\n" "$SUMMARY_NOMINAL_GROUP"
[[ -n "$SUMMARY_DB_NAME" ]] && {
  printf "🛢️  База данни:               %s\n" "$SUMMARY_DB_NAME"
  printf "👤 Потребител на БД:         %s\n" "$SUMMARY_DB_USER"
}
[[ "$SUMMARY_CREATE_FTP" == "yes" ]] && {
  printf "📡 FTP акаунт:               %s\n" "$SUMMARY_FTP_USER"
  printf "📁 FTP достъп до:           %s\n" "$SUMMARY_FTP_HOME"
}
echo "------------------------------------------------------------"

echo ""
echo "🟢 Моля, внимателно прегледайте въведената информация преди да продължите."
echo "➤  Въведете [y] за стартиране на инсталацията"
echo "➤  Въведете [r] за промяна на данните чрез рестарт на скрипта (въведените данни ще бъдат загубени)"
echo "➤  [q] Прекратяване на инсталацията"

while true; do
  read -rp "Вашият избор [y/r/q]: " confirm_choice

  case "$confirm_choice" in
    y|Y)
      echo "✅ Продължаване на инсталацията..."
      break
      ;;
    r|R)
      echo "🔄 Рестарт на скрипта..."
      exec "$0"
      ;;
    q|Q)
      echo "🚪 Прекратяване по заявка на оператора."
      exit 0
      ;;
    *)
      echo "⚠️ Невалиден избор. Изберете [y], [r] или [q]."
      ;;
  esac
done

# === [11] СЪЗДАВАНЕ НА ПОТРЕБИТЕЛ, УЕБ ДИРЕКТОРИЯ И ПРАВА ===============================
echo ""
echo "[11] СЪЗДАВАНЕ НА ПОТРЕБИТЕЛ, УЕБ ДИРЕКТОРИЯ И ПРАВА..."
echo "-------------------------------------------------------------------------"
echo ""

# Защита: Проверка дали е зададена директорията
if [[ -z "$SUMMARY_WEBROOT" ]]; then
  echo "❌ Грешка: променливата SUMMARY_WEBROOT не е зададена."
  echo "⛔️ Скриптът не може да създаде директория без валиден път."
  exit 1
fi

# Създаване на групата
if ! getent group "$SUMMARY_NOMINAL_GROUP" >/dev/null; then
  sudo groupadd "$SUMMARY_NOMINAL_GROUP"
  echo "✅ Групата $SUMMARY_NOMINAL_GROUP беше създадена."
else
  echo "ℹ️ Групата $SUMMARY_NOMINAL_GROUP вече съществува."
fi

# Създаване на номиналния потребител (без възможност за вход)
if ! id -u "$SUMMARY_NOMINAL_USER" >/dev/null 2>&1; then
  sudo useradd -r -d "$SUMMARY_WEBROOT" -s /usr/sbin/nologin -g "$SUMMARY_NOMINAL_GROUP" "$SUMMARY_NOMINAL_USER"
  echo "✅ Потребителят $SUMMARY_NOMINAL_USER беше създаден."
else
  echo "ℹ️ Потребителят $SUMMARY_NOMINAL_USER вече съществува."
fi

# Създаване на уеб директорията
if [ ! -d "$SUMMARY_WEBROOT" ]; then
  sudo mkdir -p "$SUMMARY_WEBROOT"
  echo "✅ Създадена директория: $SUMMARY_WEBROOT"
else
  echo "ℹ️ Директорията $SUMMARY_WEBROOT вече съществува."
fi

# Задаване на собственост и права
sudo chown "$SUMMARY_NOMINAL_USER:$SUMMARY_NOMINAL_GROUP" "$SUMMARY_WEBROOT"
sudo chmod 750 "$SUMMARY_WEBROOT"

RESULT_CREATE_WEBROOT="✅"

# === [12] ЗАДАВАНЕ НА КВОТА НА ПОТРЕБИТЕЛЯ =================================
echo ""
echo "[12] Задаване на квота за потребителя $SUMMARY_NOMINAL_USER..."
echo "-------------------------------------------------------------------------"
echo ""

# Проверка за наличност на setquota
if ! command -v setquota >/dev/null 2>&1; then
  echo "❌ Липсва команда 'setquota'. Уверете се, че пакетът 'quota' е инсталиран."
  RESULT_USER_QUOTA="❌ (липсва setquota)"
  exit 1
fi

# Проверка за валидност на квотата
if ! [[ "$SUMMARY_DISK_LIMIT_GB" =~ ^[0-9]+$ ]]; then
  echo "❌ Грешка: дисковият лимит (SUMMARY_DISK_LIMIT_GB) не е валиден."
  RESULT_USER_QUOTA="❌ (невалиден лимит)"
  exit 1
fi

# Проверка дали квотите са активни
if mount | grep 'on / type' | grep -q 'usrquota' && [ -f /aquota.user ]; then

  # Преобразуване от GB към KB за setquota
  block_limit_kb=$((SUMMARY_DISK_LIMIT_GB * 1024 * 1024))

  sudo setquota -u "$SUMMARY_NOMINAL_USER" "$block_limit_kb" "$block_limit_kb" 0 0 /

  if [[ $? -eq 0 ]]; then
    # Потвърждение чрез команда quota
    quota_output=$(quota -u "$SUMMARY_NOMINAL_USER" | awk 'NR>2 {print $2}')
    if [[ "$quota_output" -gt 0 ]]; then
      echo "✅ Квота от ${SUMMARY_DISK_LIMIT_GB} GB беше зададена успешно на $SUMMARY_NOMINAL_USER."
      RESULT_USER_QUOTA="✅"
    else
      echo "⚠️ setquota бе изпълнена, но quota -u не потвърди лимит."
      RESULT_USER_QUOTA="⚠️ (непотвърдено)"
    fi
  else
    echo "❌ Възникна грешка при задаване на квотата за $SUMMARY_NOMINAL_USER."
    RESULT_USER_QUOTA="❌"
  fi

else
  echo "⚠️ Квотите не са активни или root файловата система не ги поддържа."
  echo "ℹ️ Уверете се, че сървърът е рестартиран след първоначалната конфигурация."
  RESULT_USER_QUOTA="⚠️ (неактивни)"
fi

# === [13] ИНСТАЛИРАНЕ НА ИЗБРАНАТА PHP ВЕРСИЯ =============================
echo ""
echo "[13] Инсталиране на PHP ${SUMMARY_PHP_VERSION} (ако е необходимо)..."
echo "-------------------------------------------------------------------------"
echo ""

if [[ "$SUMMARY_PHP_INSTALL_REQUIRED" == "yes" ]]; then
  echo "⏳ Избраната PHP версия не е инсталирана. Проверка за необходимите хранилища..."

  # Проверка дали PPA-то е добавено
  if ! grep -r "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/ >/dev/null 2>&1; then
    echo "➕ Добавяне на хранилище ppa:ondrej/php..."
    sudo apt install -y software-properties-common lsb-release ca-certificates apt-transport-https
    if [[ $? -ne 0 ]]; then
      echo "❌ Неуспешна инсталация на зависимости за PPA."
      RESULT_PHP_INSTALL="❌"
      exit 1
    fi

    sudo add-apt-repository -y ppa:ondrej/php
    sudo apt update -qq
  fi

  echo "⏳ Инсталиране на PHP ${SUMMARY_PHP_VERSION} и нужните модули..."
  sudo apt install -y php${SUMMARY_PHP_VERSION} php${SUMMARY_PHP_VERSION}-{cli,common,fpm,mysql,mbstring,xml,curl,zip}

  if [[ $? -eq 0 ]]; then
    echo "✅ PHP ${SUMMARY_PHP_VERSION} беше инсталиран успешно."

    # Опит за стартиране и активиране на php-fpm
    sudo systemctl enable php${SUMMARY_PHP_VERSION}-fpm >/dev/null 2>&1
    sudo systemctl start php${SUMMARY_PHP_VERSION}-fpm >/dev/null 2>&1

    RESULT_PHP_INSTALL="✅"
  else
    echo "❌ Възникна грешка при инсталирането на PHP ${SUMMARY_PHP_VERSION}."
    RESULT_PHP_INSTALL="❌"
  fi

else
  echo "ℹ️ PHP ${SUMMARY_PHP_VERSION} вече е инсталиран. Пропускане на тази стъпка."
  RESULT_PHP_INSTALL="✅ (вече инсталиран)"
fi

# === [14] СЪЗДАВАНЕ НА КОНФИГУРАЦИЯ ЗА APACHE =============================
echo ""
echo "[14] Създаване на конфигурационен файл за Apache..."
echo "-------------------------------------------------------------------------"
echo ""

VHOST_FILE="/etc/apache2/sites-available/${SUMMARY_DOMAIN}.conf"
DOC_ROOT="$SUMMARY_WEBROOT"

# Проверка дали конфигурационният файл вече съществува
if [[ -f "$VHOST_FILE" ]]; then
  echo "⚠️ Конфигурационният файл вече съществува: $VHOST_FILE"
  echo "ℹ️ Пропускане на създаването му."
else
  # Създаване на конфигурацията
  cat <<EOF | sudo tee "$VHOST_FILE" >/dev/null
<VirtualHost *:80>
    ServerName ${SUMMARY_DOMAIN}
    ServerAlias www.${SUMMARY_DOMAIN}
    DocumentRoot ${DOC_ROOT}
    DirectoryIndex index.php index.html
    <Directory ${DOC_ROOT}>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/${SUMMARY_DOMAIN}_error.log
    CustomLog \${APACHE_LOG_DIR}/${SUMMARY_DOMAIN}_access.log combined
</VirtualHost>
EOF
  echo "✅ Създаден е конфигурационен файл: $VHOST_FILE"
fi

# Проверка дали сайтът вече е активиран
if [[ -L "/etc/apache2/sites-enabled/${SUMMARY_DOMAIN}.conf" ]]; then
  echo "ℹ️ Виртуалният хост ${SUMMARY_DOMAIN} вече е активиран."
else
  echo "⏳ Активиране на сайта..."
  sudo a2ensite "${SUMMARY_DOMAIN}.conf" >/dev/null 2>&1
fi

# Уверяване, че mod_rewrite е активиран
sudo a2enmod rewrite >/dev/null 2>&1

# Рестартиране на Apache
echo "🔁 Рестартиране на Apache..."
sudo systemctl reload apache2

if [[ $? -eq 0 ]]; then
  echo "✅ Сайтът ${SUMMARY_DOMAIN} е достъпен чрез Apache."
  RESULT_APACHE_VHOST="✅"
else
  echo "❌ Възникна грешка при зареждане на конфигурацията."
  RESULT_APACHE_VHOST="❌"
fi

# === [15] СЪЗДАВАНЕ НА НАЧАЛНА СТРАНИЦА (index.html) =======================
echo ""
echo "[15] Създаване на начална страница index.html..."
echo "-------------------------------------------------------------------------"
echo ""

INDEX_FILE="${SUMMARY_WEBROOT}/index.html"

sudo tee "$INDEX_FILE" >/dev/null <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>${SUMMARY_DOMAIN}</title>
  <style>
    body {
      font-family: sans-serif;
      text-align: center;
      padding: 100px;
      background: #f2f2f2;
      color: #333;
    }
    h1 { font-size: 2.5em; }
    p { font-size: 1.2em; color: #666; }
  </style>
</head>
<body>
  <h1>www.${SUMMARY_DOMAIN}</h1>
  <p>This site is under construction.</p>
EOF

# Добавяне на потребителско съобщение, ако има
if [[ -n "$SUMMARY_CUSTOM_MESSAGE" ]]; then
  sudo tee -a "$INDEX_FILE" >/dev/null <<EOF
  <p>${SUMMARY_CUSTOM_MESSAGE}</p>
EOF
fi

# Затваряне на HTML
sudo tee -a "$INDEX_FILE" >/dev/null <<EOF
</body>
</html>
EOF

# Права
sudo chown "$SUMMARY_NOMINAL_USER:$SUMMARY_NOMINAL_GROUP" "$INDEX_FILE"
sudo chmod 640 "$INDEX_FILE"

echo "✅ Началната страница беше създадена успешно."
RESULT_CREATE_INDEX="✅"

# Създаване на .well-known/acme-challenge
sudo mkdir -p "${SUMMARY_WEBROOT}/.well-known/acme-challenge"
sudo chown -R "$SUMMARY_NOMINAL_USER:$SUMMARY_NOMINAL_GROUP" "${SUMMARY_WEBROOT}/.well-known"
sudo chmod -R 755 "${SUMMARY_WEBROOT}/.well-known"

# === [16] СЪЗДАВАНЕ НА БАЗА ДАННИ (MariaDB) ================================
echo ""
echo "[16] Създаване на база данни за хоста..."
echo "-------------------------------------------------------------------------"
echo ""

if [[ "$SUMMARY_DB_CREATE" == "yes" ]]; then

  echo "⏳ Създаване на база: $SUMMARY_DB_NAME и потребител: $SUMMARY_DB_USER"

  SQL_COMMANDS="
    CREATE DATABASE IF NOT EXISTS \`${SUMMARY_DB_NAME}\`;
    CREATE USER IF NOT EXISTS '${SUMMARY_DB_USER}'@'localhost' IDENTIFIED BY '${SUMMARY_DB_PASSWORD}';
    GRANT ALL PRIVILEGES ON \`${SUMMARY_DB_NAME}\`.* TO '${SUMMARY_DB_USER}'@'localhost';
    FLUSH PRIVILEGES;
  "

  echo "$SQL_COMMANDS" | sudo mariadb

  if [[ $? -eq 0 ]]; then
    echo "✅ Базата и потребителят бяха създадени успешно."
    RESULT_DB_CREATE="✅"
  else
    echo "❌ Възникна грешка при създаването на базата данни."
    RESULT_DB_CREATE="❌"
  fi

else
  echo "ℹ️ Създаването на база данни е пропуснато."
  RESULT_DB_CREATE="⚠️ (пропуснато)"
fi

# === [17] СЪЗДАВАНЕ НА FTP АКАУНТ ==========================================
echo ""
echo "[17] Създаване на FTP акаунт за администратора..."
echo "-------------------------------------------------------------------------"
echo ""

if [[ "$SUMMARY_CREATE_FTP" == "yes" ]]; then

  FTP_USER="$SUMMARY_FTP_USER"
  FTP_HOME="$SUMMARY_FTP_HOME"
  FTP_GROUP="$SUMMARY_NOMINAL_GROUP"

  echo "⏳ Създаване/настройване на FTP акаунт: $FTP_USER"

  # Проверка дали е зададена паролата на администратора
  if [[ -z "$SUMMARY_ADMIN_PASS" ]]; then
    echo "❌ Липсва парола за администратора. Не може да бъде създаден FTP акаунт."
    RESULT_FTP_CREATE="❌ (липсва парола)"
  else
    # Създаване на FTP домашната директория, ако липсва
    if [[ ! -d "$FTP_HOME" ]]; then
      sudo mkdir -p "$FTP_HOME"
      echo "✅ Създадена е FTP директория: $FTP_HOME"
    fi

    # Проверка дали потребителят съществува
    if ! id "$FTP_USER" >/dev/null 2>&1; then
      sudo useradd -m -d "$FTP_HOME" -s /bin/bash -g "$FTP_GROUP" "$FTP_USER"
      echo "✅ Потребителят $FTP_USER беше създаден."
    else
      echo "ℹ️ Потребителят $FTP_USER вече съществува. Ще бъде използван."
      sudo usermod -d "$FTP_HOME" "$FTP_USER"
    fi

    # Задаване на парола (използва се тази от администратора)
    echo "${FTP_USER}:${SUMMARY_ADMIN_PASS}" | sudo chpasswd

    # Задаване на права
    sudo chown -R "$SUMMARY_NOMINAL_USER:$FTP_GROUP" "$FTP_HOME"

    echo "✅ FTP достъп за $FTP_USER е конфигуриран до $FTP_HOME"
    RESULT_FTP_CREATE="✅"
  fi

else
  echo "ℹ️ Създаването на FTP акаунт е пропуснато."
  RESULT_FTP_CREATE="⚠️ (пропуснато)"
fi

# === [18] НАСТРОЙВАНЕ НА SSL (HTTPS) =======================================
echo ""
echo "[18] Настройване на SSL сертификат за домейна..."
echo "-------------------------------------------------------------------------"

if [[ "$SUMMARY_SSL_TYPE" == "letsencrypt" ]]; then
  echo "⏳ Издаване на Let's Encrypt сертификат чрез certbot..."

  # Проверка дали домейнът връща някакъв HTTP отговор
  echo "⏳ Проверка дали сайтът ${SUMMARY_DOMAIN} е достъпен през HTTP..."
  if curl -s --head --request GET "http://${SUMMARY_DOMAIN}" | grep -qE "HTTP/[0-9.]+\s+(200|301|302|403|404)"; then
    echo "✅ Сайтът връща HTTP отговор. Продължаваме със заявката за сертификат."

    # Издаване на сертификат
    sudo certbot --apache -n --agree-tos --redirect --no-eff-email -m admin@${SUMMARY_ROOT_DOMAIN} -d "$SUMMARY_DOMAIN" -d "www.${SUMMARY_DOMAIN}"

    if [[ $? -eq 0 ]]; then
      echo "✅ Сертификатът е издаден и инсталиран успешно."
      RESULT_SSL_CONFIG="✅ (Let's Encrypt)"
    else
      echo "❌ Възникна грешка при издаването на Let's Encrypt сертификат."
      RESULT_SSL_CONFIG="❌"
    fi
  else
    echo "⚠️ Сайтът не връща стандартен HTTP отговор. Пропускане на издаването на сертификат."
    RESULT_SSL_CONFIG="⚠️ (недостъпен сайт)"
  fi

elif [[ "$SUMMARY_SSL_TYPE" == "custom" ]]; then
  echo "⏳ Конфигуриране с потребителски SSL сертификат..."

  SSL_CONF_PATH="/etc/apache2/sites-available/${SUMMARY_DOMAIN}-ssl.conf"

  cat <<EOF | sudo tee "$SSL_CONF_PATH" >/dev/null
<VirtualHost *:443>
    ServerName ${SUMMARY_DOMAIN}
    ServerAlias www.${SUMMARY_DOMAIN}
    DocumentRoot ${SUMMARY_WEBROOT}

    SSLEngine on
    SSLCertificateFile ${SUMMARY_SSL_CRT_PATH}
    SSLCertificateKeyFile ${SUMMARY_SSL_KEY_PATH}

    <Directory ${SUMMARY_WEBROOT}>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/${SUMMARY_DOMAIN}_ssl_error.log
    CustomLog \${APACHE_LOG_DIR}/${SUMMARY_DOMAIN}_ssl_access.log combined
</VirtualHost>
EOF

  sudo a2enmod ssl >/dev/null 2>&1
  sudo a2ensite "${SUMMARY_DOMAIN}-ssl.conf" >/dev/null 2>&1
  sudo systemctl reload apache2

  if [[ $? -eq 0 ]]; then
    echo "✅ Потребителският сертификат е конфигуриран успешно."
    RESULT_SSL_CONFIG="✅ (custom)"
  else
    echo "❌ Възникна грешка при конфигурацията със собствен сертификат."
    RESULT_SSL_CONFIG="❌"
  fi
else
  echo "⚠️ Няма избран валиден метод за SSL. Пропускане."
  RESULT_SSL_CONFIG="❌ (няма избор)"
fi

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
printf "🔐 SSL тип:                       %s\n" "$(
  case "$SUMMARY_SSL_TYPE" in
    letsencrypt) echo "Let's Encrypt" ;;
    custom) echo "Потребителски" ;;
    *) echo "Няма" ;;
  esac
)"

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

echo ""
echo "✅ Скриптът приключи успешно и беше изтрит."
echo "========================================================================="

rm -- "$0"
